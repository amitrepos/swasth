# Context: Handles health data processing and profile-specific metrics.
# Related: backend/main.py, lib/services/health_reading_service.dart

"""Health Readings API Routes"""
from fastapi import APIRouter, Depends, File, HTTPException, Query, Request, UploadFile, status
from sqlalchemy import func
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime, date, timedelta
from slowapi import Limiter
from slowapi.util import get_remote_address
import os
import json
import models
import schemas
from database import get_db
from dependencies import get_current_user, get_profile_access_or_403, get_profile_editor_or_403
from config import settings

_enabled = os.environ.get("TESTING", "").lower() != "true"
limiter = Limiter(key_func=get_remote_address, enabled=_enabled)
from encryption_service import encrypt, encrypt_float
from health_utils import age_context_bp, age_context_glucose

router = APIRouter()

_VALID_READING_TYPES = {'glucose', 'blood_pressure'}

# Cache: one Gemini call per (profile_id, date) — clears on server restart
_insight_cache: dict[tuple[int, str], str] = {}


@router.post("/readings", response_model=schemas.HealthReadingResponse, status_code=status.HTTP_201_CREATED)
def save_reading(
    reading: schemas.HealthReadingCreate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """Save a new health reading (glucose or blood pressure) for a specific profile."""
    # Verify editor/owner access (viewers cannot create readings)
    get_profile_editor_or_403(reading.profile_id, user, db)

    if reading.reading_type not in _VALID_READING_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid reading type. Must be 'glucose' or 'blood_pressure'",
        )

    db_reading = models.HealthReading(
        profile_id=reading.profile_id,
        logged_by=user.id,
        reading_type=reading.reading_type,
        glucose_value=reading.glucose_value,
        glucose_unit=reading.glucose_unit,
        sample_type=reading.sample_type,
        systolic=reading.systolic,
        diastolic=reading.diastolic,
        mean_arterial_pressure=reading.mean_arterial_pressure,
        pulse_rate=reading.pulse_rate,
        bp_unit=reading.bp_unit,
        bp_status=reading.bp_status,
        value_numeric=reading.value_numeric,
        unit_display=reading.unit_display,
        status_flag=reading.status_flag,
        notes=reading.notes,
        reading_timestamp=reading.reading_timestamp,
    )
    # Populate AES-256-GCM encrypted copies for SPDI compliance
    if reading.glucose_value is not None:
        db_reading.glucose_value_enc = encrypt_float(reading.glucose_value)
    if reading.systolic is not None:
        db_reading.systolic_enc = encrypt_float(reading.systolic)
    if reading.diastolic is not None:
        db_reading.diastolic_enc = encrypt_float(reading.diastolic)
    if reading.pulse_rate is not None:
        db_reading.pulse_rate_enc = encrypt_float(reading.pulse_rate)
    if reading.notes is not None:
        db_reading.notes_enc = encrypt(reading.notes)

    db.add(db_reading)
    db.commit()
    db.refresh(db_reading)

    # Invalidate AI insight cache so the next home screen load gets a fresh Gemini recommendation
    stale = [k for k in _insight_cache if k[0] == reading.profile_id]
    for k in stale:
        del _insight_cache[k]

    return db_reading


@router.get("/readings", response_model=List[schemas.HealthReadingResponse])
def get_readings(
    profile_id: int,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
    reading_type: Optional[str] = None,
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
):
    """Get health readings for a specific profile."""
    get_profile_access_or_403(profile_id, user, db)

    query = db.query(models.HealthReading).filter(models.HealthReading.profile_id == profile_id)

    if reading_type:
        if reading_type not in _VALID_READING_TYPES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid reading type. Must be 'glucose' or 'blood_pressure'",
            )
        query = query.filter(models.HealthReading.reading_type == reading_type)

    return query.order_by(models.HealthReading.reading_timestamp.desc()).offset(offset).limit(limit).all()


@router.get("/readings/stats/summary")
def get_readings_summary(
    profile_id: int,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """Get summary statistics for readings of a specific profile."""
    get_profile_access_or_403(profile_id, user, db)

    total_readings = db.query(models.HealthReading).filter(
        models.HealthReading.profile_id == profile_id
    ).count()

    glucose_count = db.query(models.HealthReading).filter(
        models.HealthReading.profile_id == profile_id,
        models.HealthReading.reading_type == 'glucose',
    ).count()

    bp_count = db.query(models.HealthReading).filter(
        models.HealthReading.profile_id == profile_id,
        models.HealthReading.reading_type == 'blood_pressure',
    ).count()

    latest_reading = db.query(models.HealthReading).filter(
        models.HealthReading.profile_id == profile_id
    ).order_by(models.HealthReading.reading_timestamp.desc()).first()

    return {
        "total_readings": total_readings,
        "glucose_readings": glucose_count,
        "bp_readings": bp_count,
        "latest_reading": schemas.HealthReadingResponse.from_orm(latest_reading) if latest_reading else None,
    }


@router.get("/readings/health-score", response_model=schemas.HealthScoreResponse)
def get_health_score(
    profile_id: int,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """Compute a 0–100 health score, streak, and insight for the home screen dashboard."""
    get_profile_access_or_403(profile_id, user, db)

    profile = db.query(models.Profile).filter(models.Profile.id == profile_id).first()
    profile_age = profile.age if profile else None

    today = date.today()
    seven_days_ago = datetime.combine(today - timedelta(days=6), datetime.min.time())

    # Fetch last 7 days of readings
    recent = (
        db.query(models.HealthReading)
        .filter(
            models.HealthReading.profile_id == profile_id,
            models.HealthReading.reading_timestamp >= seven_days_ago,
        )
        .order_by(models.HealthReading.reading_timestamp.desc())
        .all()
    )

    # Today's readings
    today_start = datetime.combine(today, datetime.min.time())
    today_readings = [r for r in recent if r.reading_timestamp >= today_start]

    today_glucose = next((r for r in today_readings if r.reading_type == 'glucose'), None)
    today_bp = next((r for r in today_readings if r.reading_type == 'blood_pressure'), None)

    # --- Streak calculation ---
    days_with_readings = set()
    for r in db.query(models.HealthReading).filter(
        models.HealthReading.profile_id == profile_id,
        models.HealthReading.reading_timestamp >= datetime.combine(today - timedelta(days=60), datetime.min.time()),
    ).all():
        days_with_readings.add(r.reading_timestamp.date())

    # Count consecutive days backward. If today has no reading, start from
    # yesterday so that users who logged yesterday still get streak credit.
    streak = 0
    if today in days_with_readings:
        check_day = today
    elif (today - timedelta(days=1)) in days_with_readings:
        check_day = today - timedelta(days=1)
    else:
        check_day = None

    while check_day and check_day in days_with_readings:
        streak += 1
        check_day -= timedelta(days=1)

    # Total lifetime reading count — used to distinguish first-time vs returning users
    total_reading_count = db.query(func.count(models.HealthReading.id)).filter(
        models.HealthReading.profile_id == profile_id,
    ).scalar() or 0

    # --- Score calculation ---
    score = 50

    if today_readings:
        score += 15  # logged today

        today_statuses = [r.status_flag for r in today_readings if r.status_flag]
        if today_statuses and all(s == 'NORMAL' for s in today_statuses):
            score += 15  # all normal today

        critical_count = sum(1 for s in today_statuses if s == 'CRITICAL')
        high_count = sum(1 for s in today_statuses if 'HIGH' in (s or ''))
        score -= min(critical_count * 25, 25)
        score -= min(high_count * 10, 20)

    # 7-day average check
    week_statuses = [r.status_flag for r in recent if r.status_flag]
    if week_statuses and all(s == 'NORMAL' for s in week_statuses):
        score += 10

    if streak >= 3:
        score += 5
    if streak >= 7:
        score += 5

    score = max(0, min(100, score))

    # --- Color ---
    if score >= 70:
        color = "green"
    elif score >= 40:
        color = "orange"
    else:
        color = "red"

    # --- Insight ---
    today_statuses_set = {r.status_flag for r in today_readings if r.status_flag}
    if 'CRITICAL' in today_statuses_set:
        critical_type = next(
            (r.reading_type.replace('_', ' ') for r in today_readings if r.status_flag == 'CRITICAL'), 'reading'
        )
        insight = f"⚠️ Your {critical_type} is critical. Please consult a doctor."
    elif not today_readings:
        if total_reading_count == 0:
            insight = "Log your first reading to start tracking your health."
        elif streak > 0:
            insight = f"Log a reading today to keep your {streak}-day streak alive!"
        else:
            insight = f"Welcome back! You have {total_reading_count} readings on file. Log today's reading to restart your streak."
    elif streak >= 7:
        insight = f"🔥 {streak}-day streak — you're building a great habit!"
    elif 'HIGH - STAGE 2' in today_statuses_set:
        stage2 = next((r for r in today_readings if r.status_flag == 'HIGH - STAGE 2'), None)
        if stage2 and stage2.reading_type == 'blood_pressure' and stage2.systolic:
            insight = f"⚠️ BP {stage2.systolic:.0f}/{stage2.diastolic:.0f} is dangerously high. Have you taken your medication? Please see a doctor today."
        else:
            insight = "⚠️ A reading is in Stage 2 range. Please check your medication and consult your doctor."
    elif any('HIGH' in (s or '') for s in today_statuses_set):
        high_type = next(
            (r.reading_type.replace('_', ' ') for r in today_readings if 'HIGH' in (r.status_flag or '')), 'reading'
        )
        insight = f"Your {high_type} is a bit elevated. A 10-min walk and staying hydrated often helps."
    elif streak >= 3:
        insight = f"Great work! {streak} days of consistent monitoring. Keep it up!"
    elif today_statuses_set and all(s == 'NORMAL' for s in today_statuses_set):
        insight = "All readings look healthy today. You're doing great!"
    else:
        if total_reading_count > 1:
            insight = "Readings logged. Keep tracking daily for better insights!"
        else:
            insight = "First reading logged! Keep going — daily tracking unlocks better insights."

    last_logged = recent[0].reading_timestamp if recent else None

    # --- 90-day averages for Vital Summary ---
    ninety_days_ago = datetime.combine(today - timedelta(days=89), datetime.min.time())
    prev_90_start = datetime.combine(today - timedelta(days=179), datetime.min.time())

    avg_glucose_90d = db.query(func.avg(models.HealthReading.glucose_value)).filter(
        models.HealthReading.profile_id == profile_id,
        models.HealthReading.reading_type == 'glucose',
        models.HealthReading.reading_timestamp >= ninety_days_ago,
        models.HealthReading.glucose_value.isnot(None),
    ).scalar()

    prev_avg_glucose_90d = db.query(func.avg(models.HealthReading.glucose_value)).filter(
        models.HealthReading.profile_id == profile_id,
        models.HealthReading.reading_type == 'glucose',
        models.HealthReading.reading_timestamp >= prev_90_start,
        models.HealthReading.reading_timestamp < ninety_days_ago,
        models.HealthReading.glucose_value.isnot(None),
    ).scalar()

    avg_systolic_90d = db.query(func.avg(models.HealthReading.systolic)).filter(
        models.HealthReading.profile_id == profile_id,
        models.HealthReading.reading_type == 'blood_pressure',
        models.HealthReading.reading_timestamp >= ninety_days_ago,
        models.HealthReading.systolic.isnot(None),
    ).scalar()

    avg_diastolic_90d = db.query(func.avg(models.HealthReading.diastolic)).filter(
        models.HealthReading.profile_id == profile_id,
        models.HealthReading.reading_type == 'blood_pressure',
        models.HealthReading.reading_timestamp >= ninety_days_ago,
        models.HealthReading.diastolic.isnot(None),
    ).scalar()

    prev_avg_systolic_90d = db.query(func.avg(models.HealthReading.systolic)).filter(
        models.HealthReading.profile_id == profile_id,
        models.HealthReading.reading_type == 'blood_pressure',
        models.HealthReading.reading_timestamp >= prev_90_start,
        models.HealthReading.reading_timestamp < ninety_days_ago,
        models.HealthReading.systolic.isnot(None),
    ).scalar()

    # --- Distinct calendar days with readings (for dynamic "N-day avg" label) ---
    glucose_data_days = db.query(
        func.count(func.distinct(func.date(models.HealthReading.reading_timestamp)))
    ).filter(
        models.HealthReading.profile_id == profile_id,
        models.HealthReading.reading_type == 'glucose',
        models.HealthReading.reading_timestamp >= ninety_days_ago,
        models.HealthReading.glucose_value.isnot(None),
    ).scalar() or 0

    bp_data_days = db.query(
        func.count(func.distinct(func.date(models.HealthReading.reading_timestamp)))
    ).filter(
        models.HealthReading.profile_id == profile_id,
        models.HealthReading.reading_type == 'blood_pressure',
        models.HealthReading.reading_timestamp >= ninety_days_ago,
        models.HealthReading.systolic.isnot(None),
    ).scalar() or 0

    # --- Most recent readings (any date) for Individual Metrics grid ---
    last_glucose = (
        db.query(models.HealthReading)
        .filter(
            models.HealthReading.profile_id == profile_id,
            models.HealthReading.reading_type == 'glucose',
        )
        .order_by(models.HealthReading.reading_timestamp.desc())
        .first()
    )
    last_bp = (
        db.query(models.HealthReading)
        .filter(
            models.HealthReading.profile_id == profile_id,
            models.HealthReading.reading_type == 'blood_pressure',
        )
        .order_by(models.HealthReading.reading_timestamp.desc())
        .first()
    )

    # --- Age-contextual notes ---
    _bp_for_context = today_bp or last_bp
    _glucose_for_context = today_glucose or last_glucose
    bp_age_note = None
    glucose_age_note = None
    if _bp_for_context and profile_age:
        bp_age_note = age_context_bp(
            _bp_for_context.systolic, _bp_for_context.diastolic,
            _bp_for_context.status_flag or "", profile_age,
        )
    if _glucose_for_context and profile_age:
        glucose_age_note = age_context_glucose(
            _glucose_for_context.glucose_value, _glucose_for_context.status_flag or "",
            profile_age, getattr(_glucose_for_context, "sample_type", None),
        )

    return schemas.HealthScoreResponse(
        score=score,
        color=color,
        streak_days=streak,
        insight=insight,
        profile_name=profile.name if profile else None,
        today_glucose_status=today_glucose.status_flag if today_glucose else None,
        today_bp_status=today_bp.status_flag if today_bp else None,
        today_glucose_value=today_glucose.glucose_value if today_glucose else None,
        today_bp_systolic=today_bp.systolic if today_bp else None,
        today_bp_diastolic=today_bp.diastolic if today_bp else None,
        last_logged=last_logged,
        profile_age=profile_age,
        age_context_bp=bp_age_note,
        age_context_glucose=glucose_age_note,
        avg_glucose_90d=float(avg_glucose_90d) if avg_glucose_90d is not None else None,
        prev_avg_glucose_90d=float(prev_avg_glucose_90d) if prev_avg_glucose_90d is not None else None,
        avg_systolic_90d=float(avg_systolic_90d) if avg_systolic_90d is not None else None,
        avg_diastolic_90d=float(avg_diastolic_90d) if avg_diastolic_90d is not None else None,
        prev_avg_systolic_90d=float(prev_avg_systolic_90d) if prev_avg_systolic_90d is not None else None,
        last_glucose_value=last_glucose.glucose_value if last_glucose else None,
        last_glucose_status=last_glucose.status_flag if last_glucose else None,
        last_bp_systolic=last_bp.systolic if last_bp else None,
        last_bp_diastolic=last_bp.diastolic if last_bp else None,
        last_bp_status=last_bp.status_flag if last_bp else None,
        glucose_data_days=int(glucose_data_days),
        bp_data_days=int(bp_data_days),
    )


@router.get("/readings/ai-insight")
def get_ai_insight(
    profile_id: int,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """Return a personalised 1-2 sentence AI health recommendation via Gemini 1.5 Flash.
    Falls back to rule-based insight on any error — never returns 500."""
    get_profile_access_or_403(profile_id, user, db)

    # ── AI consent gate — return rule-based fallback if user hasn't consented ──
    if not user.ai_consent:
        thirty_days_ago = datetime.combine(date.today() - timedelta(days=29), datetime.min.time())
        recent = (
            db.query(models.HealthReading)
            .filter(
                models.HealthReading.profile_id == profile_id,
                models.HealthReading.reading_timestamp >= thirty_days_ago,
            )
            .order_by(models.HealthReading.reading_timestamp.asc())
            .all()
        )
        total_count = db.query(func.count(models.HealthReading.id)).filter(
            models.HealthReading.profile_id == profile_id,
        ).scalar() or 0
        return {"insight": _rule_based_insight(recent, total_count=total_count), "ai_consent_required": True}

    # ── Smart cache: only call LLM when new readings exist ────────────
    latest_insight = (
        db.query(models.AiInsightLog)
        .filter(
            models.AiInsightLog.profile_id == profile_id,
            models.AiInsightLog.model_used != "failed",
        )
        .order_by(models.AiInsightLog.created_at.desc())
        .first()
    )
    latest_reading = (
        db.query(models.HealthReading)
        .filter(models.HealthReading.profile_id == profile_id)
        .order_by(models.HealthReading.reading_timestamp.desc())
        .first()
    )

    if latest_insight and latest_reading:
        # Compare: if no new readings since last insight, return cached
        insight_time = latest_insight.created_at
        reading_time = latest_reading.reading_timestamp
        # Make both offset-naive for comparison
        if insight_time and hasattr(insight_time, 'replace'):
            insight_time = insight_time.replace(tzinfo=None)
        if reading_time and hasattr(reading_time, 'replace'):
            reading_time = reading_time.replace(tzinfo=None)
        if insight_time and reading_time and reading_time <= insight_time:
            return {"insight": latest_insight.response_text}

    # ── Need fresh insight — fetch data ───────────────────────────────
    profile = db.query(models.Profile).filter(models.Profile.id == profile_id).first()

    thirty_days_ago = datetime.combine(date.today() - timedelta(days=29), datetime.min.time())
    recent = (
        db.query(models.HealthReading)
        .filter(
            models.HealthReading.profile_id == profile_id,
            models.HealthReading.reading_timestamp >= thirty_days_ago,
        )
        .order_by(models.HealthReading.reading_timestamp.asc())
        .all()
    )

    # Build compact summary (averages + ranges) instead of raw readings
    glucose_vals = [r.glucose_value for r in recent if r.reading_type == "glucose" and r.glucose_value]
    bp_readings = [(r.systolic, r.diastolic) for r in recent if r.reading_type == "blood_pressure" and r.systolic and r.diastolic]

    total_count = db.query(func.count(models.HealthReading.id)).filter(
        models.HealthReading.profile_id == profile_id,
    ).scalar() or 0
    fallback = _rule_based_insight(recent, total_count=total_count)

    if not glucose_vals and not bp_readings:
        return {"insight": fallback}

    age = profile.age if profile else None
    gender = profile.gender if profile else "Unknown"
    conditions = ", ".join(profile.medical_conditions) if (profile and profile.medical_conditions) else "None reported"
    medications = profile.current_medications if (profile and profile.current_medications) else "None reported"

    # Glucose summary
    glucose_summary = ""
    if glucose_vals:
        avg_g = sum(glucose_vals) / len(glucose_vals)
        min_g, max_g = min(glucose_vals), max(glucose_vals)
        normal_g = sum(1 for v in glucose_vals if 70 <= v <= 130)
        high_g = sum(1 for v in glucose_vals if v > 180)
        glucose_summary = (
            f"Glucose (30-day, {len(glucose_vals)} readings): "
            f"avg {avg_g:.0f}, range {min_g:.0f}–{max_g:.0f} mg/dL, "
            f"{normal_g} normal, {high_g} critical (>180). "
            f"Latest: {glucose_vals[-1]:.0f} mg/dL."
        )

    # BP summary
    bp_summary = ""
    if bp_readings:
        sys_vals = [s for s, _ in bp_readings]
        dia_vals = [d for _, d in bp_readings]
        avg_sys = sum(sys_vals) / len(sys_vals)
        avg_dia = sum(dia_vals) / len(dia_vals)
        stage2_count = sum(1 for s, d in bp_readings if s > 140 or d > 90)
        bp_summary = (
            f"BP (30-day, {len(bp_readings)} readings): "
            f"avg {avg_sys:.0f}/{avg_dia:.0f} mmHg, "
            f"range {min(sys_vals):.0f}–{max(sys_vals):.0f}/{min(dia_vals):.0f}–{max(dia_vals):.0f}, "
            f"{stage2_count} Stage 2 readings. "
            f"Latest: {sys_vals[-1]:.0f}/{dia_vals[-1]:.0f} mmHg."
        )

    # Trend direction
    trend_note = ""
    if len(glucose_vals) >= 6:
        mid = len(glucose_vals) // 2
        first_avg = sum(glucose_vals[:mid]) / mid
        second_avg = sum(glucose_vals[mid:]) / (len(glucose_vals) - mid)
        if second_avg < first_avg - 5:
            trend_note += "Glucose trending DOWN (improving). "
        elif second_avg > first_avg + 5:
            trend_note += "Glucose trending UP (worsening). "

    age_desc = f"{age} years" if age else "unknown age"

    prompt = f"""You are a concise health assistant. Give 1-2 sentences of personalised advice.

Patient: {age_desc}, {gender}. Conditions: {conditions}. Medications: {medications}.

{glucose_summary}
{bp_summary}
{trend_note}

Rules:
- Give actionable advice (what to do), not data summaries.
- If avg glucose > 180 or any critical: be urgent, ask about medication, recommend doctor.
- If BP avg > 140/90 or Stage 2 readings: be urgent about medication and doctor.
- If normal: be encouraging, mention a specific habit or food.
- Speak directly to the patient. Max 2 sentences."""

    import ai_service
    prompt_summary = f"{glucose_summary} {bp_summary} {trend_note}".strip() or None
    insight = ai_service.generate_health_insight(prompt, profile_id, db, prompt_summary)

    if insight:
        return {"insight": insight}

    # All AI models failed — use rule-based fallback and log it
    ai_service._log(db, profile_id, "rule-based", prompt_summary, fallback, None, None, None)
    return {"insight": fallback}


@router.get("/readings/{reading_id}", response_model=schemas.HealthReadingResponse)
def get_reading(
    reading_id: int,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """Get a specific reading by ID."""
    db_reading = db.query(models.HealthReading).filter(models.HealthReading.id == reading_id).first()
    if not db_reading:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reading not found")
    
    # Verify access to the profile this reading belongs to
    get_profile_access_or_403(db_reading.profile_id, user, db)
    
    return db_reading


@router.delete("/readings/{reading_id}")
def delete_reading(
    reading_id: int,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """Delete a reading."""
    db_reading = db.query(models.HealthReading).filter(models.HealthReading.id == reading_id).first()
    if not db_reading:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reading not found")

    # Verify editor/owner access (viewers cannot delete readings)
    get_profile_editor_or_403(db_reading.profile_id, user, db)
    
    db.delete(db_reading)
    db.commit()
    return {"message": "Reading deleted successfully"}


@router.post("/readings/parse-image")
@limiter.limit("20/minute")
async def parse_image_with_gemini(
    request: Request,
    device_type: str,
    file: UploadFile = File(...),
    user: models.User = Depends(get_current_user),
):
    """Use Gemini Vision to extract glucose or BP values from a device photo.

    Returns extracted values as JSON. Never raises 500 — returns
    {"error": "..."} so the Flutter app can fall back to local OCR.
    """
    if device_type not in _VALID_READING_TYPES:
        raise HTTPException(status_code=400, detail="device_type must be 'glucose' or 'blood_pressure'")

    if not settings.GEMINI_API_KEY:
        return {"error": "GEMINI_API_KEY not configured"}

    try:
        image_bytes = await file.read()
        # iOS camera files often arrive as application/octet-stream — derive from extension
        mime_type = file.content_type or "image/jpeg"
        if mime_type == "application/octet-stream":
            fname = (file.filename or "").lower()
            if fname.endswith(".png"):
                mime_type = "image/png"
            else:
                mime_type = "image/jpeg"  # default for camera captures

        if device_type == "blood_pressure":
            prompt = (
                "You are reading a blood pressure monitor display in this photo.\n"
                "Extract the systolic pressure, diastolic pressure, and pulse rate shown.\n\n"
                "Rules:\n"
                "- Systolic is the LARGER number (top or left), normal range 70–250 mmHg\n"
                "- Diastolic is the SMALLER number (bottom or right), normal range 40–150 mmHg\n"
                "- Pulse/heart rate is typically shown separately, range 30–200 bpm\n"
                "- If a value is not visible or unreadable, use null\n"
                "- Ignore any text labels (SYS, DIA, mmHg, PULSE, etc.) — extract numbers only\n\n"
                "Respond with ONLY a JSON object, no explanation, no markdown:\n"
                '{"systolic": <number or null>, "diastolic": <number or null>, "pulse": <number or null>}'
            )
        else:
            prompt = (
                "You are reading a blood glucose meter display in this photo.\n"
                "Extract the glucose reading shown on the screen.\n\n"
                "Rules:\n"
                "- Glucose value is typically a 2–3 digit number, range 20–600 mg/dL\n"
                "- If the display shows 'HI' or 'HIGH', return 600\n"
                "- If the display shows 'LO' or 'LOW', return 20\n"
                "- If the value is not visible or unreadable, use null\n"
                "- Ignore units (mg/dL, mmol/L) — return the raw number only\n\n"
                "Respond with ONLY a JSON object, no explanation, no markdown:\n"
                '{"glucose": <number or null>}'
            )

        from google import genai
        from google.genai import types as genai_types

        client = genai.Client(api_key=settings.GEMINI_API_KEY)
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=[
                genai_types.Part.from_bytes(data=image_bytes, mime_type=mime_type),
                prompt,
            ],
            config=genai_types.GenerateContentConfig(
                max_output_tokens=1024,
                temperature=0.0,
            ),
        )

        # gemini-2.5-flash may include thinking tokens; collect all text parts then
        # use regex to find the JSON object regardless of surrounding markdown.
        import re
        all_text = "".join(
            part.text
            for candidate in response.candidates
            for part in candidate.content.parts
            if hasattr(part, "text") and part.text
        )
        if not all_text:
            return {"error": "Gemini returned an empty response"}

        json_match = re.search(r"\{[^{}]+\}", all_text, re.DOTALL)
        if not json_match:
            return {"error": "No JSON found in Gemini response"}

        parsed = json.loads(json_match.group())

        # Validate ranges
        if device_type == "blood_pressure":
            sys = parsed.get("systolic")
            dia = parsed.get("diastolic")
            pulse = parsed.get("pulse")
            if sys is not None and not (70 <= sys <= 250):
                sys = None
            if dia is not None and not (40 <= dia <= 150):
                dia = None
            if pulse is not None and not (30 <= pulse <= 200):
                pulse = None
            if sys is None or dia is None:
                return {"error": "Could not extract valid BP values from image"}
            return {"systolic": sys, "diastolic": dia, "pulse": pulse}
        else:
            glucose = parsed.get("glucose")
            if glucose is not None and not (20 <= glucose <= 600):
                glucose = None
            if glucose is None:
                return {"error": "Could not extract valid glucose value from image"}
            return {"glucose": glucose}

    except (json.JSONDecodeError, KeyError):
        return {"error": "Gemini returned an unexpected format"}
    except Exception as e:
        return {"error": f"Gemini Vision failed: {str(e)}"}


def _rule_based_insight(recent: list, total_count: int = 0) -> str:
    """Simple rule-based fallback used when Gemini is unavailable."""
    if not recent:
        if total_count > 0:
            return f"Welcome back! You have {total_count} readings on file. Log today's reading to get fresh insights."
        return "Log your first reading to start tracking your health."
    statuses = {r.status_flag for r in recent if r.status_flag}
    if "CRITICAL" in statuses:
        return "⚠️ A recent reading was critical. Please seek medical attention immediately."
    if "HIGH - STAGE 2" in statuses:
        stage2 = next((r for r in reversed(recent) if r.status_flag == "HIGH - STAGE 2"), None)
        if stage2 and stage2.reading_type == "blood_pressure" and stage2.systolic:
            return f"⚠️ Your BP ({stage2.systolic:.0f}/{stage2.diastolic:.0f}) is dangerously high. Have you taken your medication? Please see a doctor today."
        return "⚠️ A reading is in Stage 2 range. Have you taken your medication? Please consult your doctor."
    if any("HIGH" in (s or "") for s in statuses):
        return "Some readings were elevated this week. Stay hydrated and keep active."
    if statuses and all(s == "NORMAL" for s in statuses):
        return "All recent readings look healthy. Keep up the great work!"
    return "Readings logged. Keep tracking daily for better health insights."


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------
