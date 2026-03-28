# Context: Handles health data processing and profile-specific metrics.
# Related: backend/main.py, lib/services/health_reading_service.dart

"""Health Readings API Routes"""
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime, date, timedelta
import models
import schemas
from database import get_db
from dependencies import get_current_user, get_profile_access_or_403
from config import settings

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
    # Verify profile access
    get_profile_access_or_403(reading.profile_id, user, db)

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

    streak = 0
    check_day = today
    while check_day in days_with_readings:
        streak += 1
        check_day -= timedelta(days=1)

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
        if streak > 0:
            insight = f"Log a reading today to keep your {streak}-day streak alive!"
        else:
            insight = "Log your first reading to start tracking your health."
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
        insight = "Log daily readings for the best health insights."

    last_logged = recent[0].reading_timestamp if recent else None

    return schemas.HealthScoreResponse(
        score=score,
        color=color,
        streak_days=streak,
        insight=insight,
        today_glucose_status=today_glucose.status_flag if today_glucose else None,
        today_bp_status=today_bp.status_flag if today_bp else None,
        today_glucose_value=today_glucose.glucose_value if today_glucose else None,
        today_bp_systolic=today_bp.systolic if today_bp else None,
        today_bp_diastolic=today_bp.diastolic if today_bp else None,
        last_logged=last_logged,
        profile_age=profile_age,
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

    today_str = date.today().isoformat()
    cache_key = (profile_id, today_str)
    if cache_key in _insight_cache:
        return {"insight": _insight_cache[cache_key]}

    # Fetch profile for age-aware context
    profile = db.query(models.Profile).filter(models.Profile.id == profile_id).first()

    # Fetch last 7 days of readings
    seven_days_ago = datetime.combine(date.today() - timedelta(days=6), datetime.min.time())
    recent = (
        db.query(models.HealthReading)
        .filter(
            models.HealthReading.profile_id == profile_id,
            models.HealthReading.reading_timestamp >= seven_days_ago,
        )
        .order_by(models.HealthReading.reading_timestamp.asc())
        .all()
    )

    # Build reading lines for prompt
    glucose_lines = []
    bp_lines = []
    for r in recent:
        day = r.reading_timestamp.strftime("%b %d")
        if r.reading_type == "glucose" and r.glucose_value:
            glucose_lines.append(f"  - {day}: {r.glucose_value:.0f} mg/dL ({r.status_flag or 'unknown'})")
        elif r.reading_type == "blood_pressure" and r.systolic and r.diastolic:
            bp_lines.append(f"  - {day}: {r.systolic:.0f}/{r.diastolic:.0f} mmHg ({r.status_flag or 'unknown'})")

    fallback = _rule_based_insight(recent)

    if not glucose_lines and not bp_lines:
        return {"insight": fallback}

    age = profile.age if profile else None
    gender = profile.gender if profile else "Unknown"
    conditions = ", ".join(profile.medical_conditions) if (profile and profile.medical_conditions) else "None reported"
    medications = profile.current_medications if (profile and profile.current_medications) else "None reported"

    readings_section = ""
    if glucose_lines:
        readings_section += "Glucose readings:\n" + "\n".join(glucose_lines) + "\n"
    if bp_lines:
        readings_section += "Blood pressure readings:\n" + "\n".join(bp_lines) + "\n"

    age_desc = f"{age} years" if age else "unknown age"
    age_context = ""
    if age:
        if age >= 60:
            age_context = f"For patients over 60, BP up to 140/90 mmHg may be acceptable. Glucose targets may be slightly more relaxed."
        elif age < 30:
            age_context = f"For patients under 30, even 125/80 mmHg BP warrants attention. Glucose should stay close to 80-100 mg/dL fasting."
        else:
            age_context = f"For a {age}-year-old, standard BP target is below 130/80 mmHg and fasting glucose below 100 mg/dL."

    prompt = f"""You are a concise health assistant reviewing a patient's recent biometric data.

Patient:
- Age: {age_desc} | Gender: {gender}
- Medical conditions: {conditions}
- Current medications: {medications}

Last 7 days of readings:
{readings_section}
Age context: {age_context}

Critical thresholds that REQUIRE urgent language (do not soften these):
- BP systolic ≥ 180 or diastolic ≥ 120: hypertensive crisis — ask if they took their medication and tell them to see a doctor today.
- BP ≥ 140/90 (Stage 2): ask if they took their medication and recommend a doctor visit soon.
- Glucose > 250 mg/dL: dangerously high — recommend immediate medical attention.
- Glucose < 60 mg/dL: dangerously low — recommend immediate action (eat something + seek help).

Task: Write exactly 1-2 sentences of personalised health advice based on the data above.
For normal or mildly elevated readings: be encouraging and practical.
For Stage 2 or critical readings: be direct and urgent — ask about medication, recommend seeing a doctor.
Speak directly to the patient ("Your BP...", "Have you taken..."). Do not be vague for serious readings."""

    try:
        import google.generativeai as genai
        if not settings.GEMINI_API_KEY:
            raise ValueError("GEMINI_API_KEY not set")
        genai.configure(api_key=settings.GEMINI_API_KEY)
        model = genai.GenerativeModel("gemini-1.5-flash")
        response = model.generate_content(
            prompt,
            generation_config=genai.GenerationConfig(
                max_output_tokens=120,
                temperature=0.4,
            ),
        )
        insight = response.text.strip()
        _insight_cache[cache_key] = insight
        return {"insight": insight}
    except Exception:
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
    
    # Verify access to the profile this reading belongs to
    get_profile_access_or_403(db_reading.profile_id, user, db)
    
    db.delete(db_reading)
    db.commit()
    return {"message": "Reading deleted successfully"}


def _rule_based_insight(recent: list) -> str:
    """Simple rule-based fallback used when Gemini is unavailable."""
    if not recent:
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
    return "Keep logging daily readings for the best health insights."


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------
