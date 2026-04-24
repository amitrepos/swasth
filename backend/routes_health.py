# Context: Handles health data processing and profile-specific metrics.
# Related: backend/main.py, lib/services/health_reading_service.dart

"""Health Readings API Routes"""
from fastapi import APIRouter, BackgroundTasks, Depends, File, HTTPException, Query, Request, UploadFile, status
from fastapi.responses import Response
from sqlalchemy import func
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime, date, timedelta
from slowapi import Limiter
from slowapi.util import get_remote_address
import logging
import os
import json

logger = logging.getLogger(__name__)
import models
import schemas
from database import get_db
from dependencies import get_current_user, get_profile_access_or_403, get_profile_editor_or_403
from config import settings
from health_utils import generate_meal_insights
from report_service import trigger_single_profile_report, send_weekly_reports
from models import ReportTriggerType

_enabled = os.environ.get("TESTING", "").lower() != "true"
limiter = Limiter(key_func=get_remote_address, enabled=_enabled)
from encryption_service import encrypt, encrypt_float
from health_utils import age_context_bp, age_context_glucose, classify_spo2

router = APIRouter()

_VALID_READING_TYPES = {'glucose', 'blood_pressure', 'spo2', 'steps', 'weight'}

# Cache: one Gemini call per (profile_id, date) — clears on server restart
_insight_cache: dict[tuple[int, str], str] = {}


@router.post("/readings", status_code=status.HTTP_201_CREATED)
def save_reading(
    reading: schemas.HealthReadingCreate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """Save a new health reading (glucose, blood pressure, SpO2, or steps) for a specific profile."""
    # Verify editor/owner access (viewers cannot create readings)
    get_profile_editor_or_403(reading.profile_id, user, db)

    if reading.reading_type not in _VALID_READING_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid reading type. Must be one of: {', '.join(sorted(_VALID_READING_TYPES))}",
        )

    # ── BLE deduplication: check if seq already exists ─────────────────────
    if reading.seq is not None:
        existing_seq = db.query(models.HealthReading).filter(
            models.HealthReading.seq == reading.seq,
            models.HealthReading.reading_type == reading.reading_type,
        ).first()
        
        if existing_seq:
            # Reading with this sequence number already exists - skip storing
            return {
                "skipped": True,
                "reason": "duplicate_seq",
                "seq": reading.seq,
                "existing_id": existing_seq.id,
            }

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
        spo2_value=reading.spo2_value,
        spo2_unit=reading.spo2_unit,
        steps_count=reading.steps_count,
        steps_goal=reading.steps_goal,
        weight_value=reading.weight_value,
        weight_unit=reading.weight_unit,
        value_numeric=reading.value_numeric,
        unit_display=reading.unit_display,
        status_flag=reading.status_flag,
        notes=reading.notes,
        reading_timestamp=reading.reading_timestamp,
        seq=reading.seq,
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
    if reading.spo2_value is not None:
        db_reading.spo2_enc = encrypt_float(reading.spo2_value)
    if reading.weight_value is not None:
        db_reading.weight_value_enc = encrypt_float(reading.weight_value)
    if reading.notes is not None:
        db_reading.notes_enc = encrypt(reading.notes)

    db.add(db_reading)
    db.commit()
    db.refresh(db_reading)

    # Invalidate AI insight cache so the next home screen load gets a fresh Gemini recommendation
    stale = [k for k in _insight_cache if k[0] == reading.profile_id]
    for k in stale:
        del _insight_cache[k]

    # ── Critical alert: send email to family members ─────────────────
    alert = None
    if reading.status_flag in ("CRITICAL", "HIGH - STAGE 2"):
        profile = db.query(models.Profile).filter(models.Profile.id == reading.profile_id).first()
        profile_name = profile.name if profile else "Someone"

        if reading.reading_type == "glucose" and reading.glucose_value:
            alert_msg = f"🚨 {profile_name}'s glucose is {reading.glucose_value:.0f} mg/dL ({reading.status_flag}). Please check on them immediately."
        elif reading.reading_type == "blood_pressure" and reading.systolic:
            alert_msg = f"🚨 {profile_name}'s BP is {reading.systolic:.0f}/{reading.diastolic:.0f} mmHg ({reading.status_flag}). Please check on them immediately."
        elif reading.reading_type == "spo2" and reading.spo2_value:
            alert_msg = f"🚨 {profile_name}'s SpO2 is {reading.spo2_value:.0f}% ({reading.status_flag}). Please check on them immediately."
        else:
            alert_msg = f"🚨 {profile_name} has a {reading.status_flag} health reading. Please check on them."

        alert = {
            "level": reading.status_flag,
            "message": alert_msg,
            "profile_name": profile_name,
        }

        # Dispatch via alert_service — handles email + WhatsApp + SMS fanout,
        # per-channel failure logging, and dedupe window. Failures do NOT
        # block the reading save — the reading is already committed above.
        try:
            from alert_service import dispatch_critical_alert
            if profile is not None:
                dispatch_critical_alert(
                    reading=db_reading,
                    profile=profile,
                    logger_user_id=user.id,
                    db=db,
                )
                db.commit()  # Persist CriticalAlertLog rows
        except Exception:
            db.rollback()  # Never let alert dispatch break the reading save

    response = schemas.HealthReadingResponse.from_orm(db_reading)
    result = response.dict()
    if alert:
        result["alert"] = alert
    return result


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
                detail=f"Invalid reading type. Must be one of: {', '.join(sorted(_VALID_READING_TYPES))}",
            )
        query = query.filter(models.HealthReading.reading_type == reading_type)

    return query.order_by(models.HealthReading.reading_timestamp.desc()).offset(offset).limit(limit).all()



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
    today_readings = [r for r in recent if r.reading_timestamp.replace(tzinfo=None) >= today_start]

    today_glucose = next((r for r in today_readings if r.reading_type == 'glucose'), None)
    today_bp = next((r for r in today_readings if r.reading_type == 'blood_pressure'), None)
    today_spo2 = next((r for r in today_readings if r.reading_type == 'spo2'), None)

    # Steps: sum all step entries today (may have multiple syncs)
    today_steps_readings = [r for r in today_readings if r.reading_type == 'steps']
    today_steps_count = sum(r.steps_count or 0 for r in today_steps_readings) if today_steps_readings else 0
    today_steps_goal = next((r.steps_goal for r in today_steps_readings if r.steps_goal), None)

    today_weight = next((r for r in today_readings if r.reading_type == 'weight'), None)

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
    last_weight = (
        db.query(models.HealthReading)
        .filter(
            models.HealthReading.profile_id == profile_id,
            models.HealthReading.reading_type == 'weight',
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

    steps_data_days = db.query(
        func.count(func.distinct(func.date(models.HealthReading.reading_timestamp)))
    ).filter(
        models.HealthReading.profile_id == profile_id,
        models.HealthReading.reading_type == 'steps',
        models.HealthReading.reading_timestamp >= ninety_days_ago,
        models.HealthReading.steps_count.isnot(None),
    ).scalar() or 0

    # --- Weight data ---
    avg_weight_90d = db.query(func.avg(models.HealthReading.weight_value)).filter(
        models.HealthReading.profile_id == profile_id,
        models.HealthReading.reading_type == 'weight',
        models.HealthReading.reading_timestamp >= ninety_days_ago,
        models.HealthReading.weight_value.isnot(None),
    ).scalar()
    weight_data_days = db.query(
        func.count(func.distinct(func.date(models.HealthReading.reading_timestamp)))
    ).filter(
        models.HealthReading.profile_id == profile_id,
        models.HealthReading.reading_type == 'weight',
        models.HealthReading.reading_timestamp >= ninety_days_ago,
        models.HealthReading.weight_value.isnot(None),
    ).scalar() or 0

    # --- BMI ---
    p_height = profile.height if profile else None
    p_weight = last_weight.weight_value if last_weight else (profile.weight if profile else None)
    bmi = None
    bmi_category = None
    if p_height and p_weight and p_height > 0:
        height_m = p_height / 100.0
        bmi = round(p_weight / (height_m * height_m), 1)
        if bmi < 18.5:
            bmi_category = "Underweight"
        elif bmi < 25:
            bmi_category = "Normal"
        elif bmi < 30:
            bmi_category = "Overweight"
        else:
            bmi_category = "Obese"

    # --- SpO2 data ---
    last_spo2 = (
        db.query(models.HealthReading)
        .filter(
            models.HealthReading.profile_id == profile_id,
            models.HealthReading.reading_type == 'spo2',
        )
        .order_by(models.HealthReading.reading_timestamp.desc())
        .first()
    )
    avg_spo2_90d = db.query(func.avg(models.HealthReading.spo2_value)).filter(
        models.HealthReading.profile_id == profile_id,
        models.HealthReading.reading_type == 'spo2',
        models.HealthReading.reading_timestamp >= ninety_days_ago,
        models.HealthReading.spo2_value.isnot(None),
    ).scalar()
    spo2_data_days = db.query(
        func.count(func.distinct(func.date(models.HealthReading.reading_timestamp)))
    ).filter(
        models.HealthReading.profile_id == profile_id,
        models.HealthReading.reading_type == 'spo2',
        models.HealthReading.reading_timestamp >= ninety_days_ago,
        models.HealthReading.spo2_value.isnot(None),
    ).scalar() or 0

    # --- Steps data ---
    last_steps = (
        db.query(models.HealthReading)
        .filter(
            models.HealthReading.profile_id == profile_id,
            models.HealthReading.reading_type == 'steps',
        )
        .order_by(models.HealthReading.reading_timestamp.desc())
        .first()
    )
    avg_steps_90d = db.query(func.avg(models.HealthReading.steps_count)).filter(
        models.HealthReading.profile_id == profile_id,
        models.HealthReading.reading_type == 'steps',
        models.HealthReading.reading_timestamp >= ninety_days_ago,
        models.HealthReading.steps_count.isnot(None),
    ).scalar()
    steps_data_days = db.query(
        func.count(func.distinct(func.date(models.HealthReading.reading_timestamp)))
    ).filter(
        models.HealthReading.profile_id == profile_id,
        models.HealthReading.reading_type == 'steps',
        models.HealthReading.reading_timestamp >= ninety_days_ago,
        models.HealthReading.steps_count.isnot(None),
    ).scalar() or 0

    # SpO2 classification for today's reading
    today_spo2_status = None
    if today_spo2 and today_spo2.spo2_value is not None:
        today_spo2_status = classify_spo2(today_spo2.spo2_value)

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
        bmi=bmi,
        bmi_category=bmi_category,
        profile_height=p_height,
        profile_weight=p_weight,
        # SpO2
        today_spo2_value=today_spo2.spo2_value if today_spo2 else None,
        today_spo2_status=today_spo2_status,
        last_spo2_value=last_spo2.spo2_value if last_spo2 else None,
        last_spo2_status=classify_spo2(last_spo2.spo2_value) if last_spo2 and last_spo2.spo2_value else None,
        avg_spo2_90d=float(avg_spo2_90d) if avg_spo2_90d is not None else None,
        spo2_data_days=int(spo2_data_days),
        # Steps
        today_steps_count=today_steps_count,
        today_steps_goal=today_steps_goal,
        last_steps_count=last_steps.steps_count if last_steps else None,
        avg_steps_90d=float(avg_steps_90d) if avg_steps_90d is not None else None,
        steps_data_days=int(steps_data_days),
        # Weight
        today_weight_value=today_weight.weight_value if today_weight else None,
        last_weight_value=last_weight.weight_value if last_weight else None,
        avg_weight_90d=float(avg_weight_90d) if avg_weight_90d is not None else None,
        weight_data_days=int(weight_data_days),
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
        return {"insight": _rule_based_insight(recent, db, total_count=total_count), "ai_consent_required": True}

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
    weight_vals = [r.weight_value for r in recent if r.reading_type == "weight" and r.weight_value]

    total_count = db.query(func.count(models.HealthReading.id)).filter(
        models.HealthReading.profile_id == profile_id,
    ).scalar() or 0
    fallback = _rule_based_insight(recent, db, total_count=total_count)

    if not glucose_vals and not bp_readings and not weight_vals:
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

    # ── Meal summary for LLM context ────────────────────────────────
    recent_meals = (
        db.query(models.MealLog)
        .filter(
            models.MealLog.profile_id == profile_id,
            models.MealLog.timestamp >= thirty_days_ago,
        )
        .order_by(models.MealLog.timestamp.asc())
        .all()
    )

    food_summary = ""
    if recent_meals:
        from collections import Counter
        cat_counts = Counter(m.category for m in recent_meals)
        food_summary = (
            f"Meals (30-day, {len(recent_meals)} logged): "
            + ", ".join(f"{k} {v}" for k, v in cat_counts.most_common())
            + ". "
        )

    # ── Weight summary for LLM context ────────────────────────────────
    weight_vals = [r.weight_value for r in recent if r.reading_type == "weight" and r.weight_value]
    weight_summary = ""
    if weight_vals:
        avg_w = sum(weight_vals) / len(weight_vals)
        latest_w = weight_vals[-1]
        weight_summary = f"Weight (30-day, {len(weight_vals)} readings): avg {avg_w:.1f}, latest {latest_w:.1f} kg. "
        if profile and profile.height:
            bmi = latest_w / ((profile.height / 100) ** 2)
            weight_summary += f"BMI is {bmi:.1f}."

    # Rule-based meal insights (appended to response, not sent to LLM)
    meal_tips = generate_meal_insights(recent_meals, recent)

    age_desc = f"{age} years" if age else "unknown age"

    prompt = f"""Patient: {age_desc}, {gender}. {conditions}. {medications}. {glucose_summary} {bp_summary} {weight_summary} {food_summary}{trend_note}

Write exactly 2-3 short sentences: one about their status, one actionable tip. Under 50 words total. No greetings, no raw data numbers, no bullet points.
IMPORTANT: Even if glucose and BP are normal, if BMI is high (>= 25) or weight is trending up, prioritize weight management advice.
Use suggestive language only ("may help", "consider")."""

    import ai_service
    prompt_summary = f"{glucose_summary} {bp_summary} {weight_summary} {food_summary}{trend_note}".strip() or None
    insight = ai_service.generate_health_insight(prompt, profile_id, db, prompt_summary)

    if insight:
        # Append top meal insight if available (max 1 to keep it concise)
        if meal_tips:
            insight = f"{insight}\n\n{meal_tips[0]}"
        return {"insight": insight}

    # All AI models failed — use rule-based fallback and log it
    ai_service._log(db, profile_id, "rule-based", prompt_summary, fallback, None, None, None)
    if meal_tips:
        fallback = f"{fallback}\n\n{meal_tips[0]}"
    return {"insight": fallback}


def _build_shareable_summary(profile_id: int, period: int, db: Session):
    """Build a shareable text summary for the given profile and period."""
    today = date.today()
    period_start = datetime.combine(today - timedelta(days=period - 1), datetime.min.time())

    profile = db.query(models.Profile).filter(models.Profile.id == profile_id).first()
    profile_name = profile.name if profile else "Patient"

    readings = (
        db.query(models.HealthReading)
        .filter(
            models.HealthReading.profile_id == profile_id,
            models.HealthReading.reading_timestamp >= period_start,
        )
        .order_by(models.HealthReading.reading_timestamp.asc())
        .all()
    )

    glucose_vals = [r.glucose_value for r in readings if r.reading_type == "glucose" and r.glucose_value]
    bp_readings = [(r.systolic, r.diastolic) for r in readings if r.reading_type == "blood_pressure" and r.systolic and r.diastolic]

    lines = [f"\U0001f4ca Weekly Health Summary \u2014 {profile_name}"]
    start_date = (today - timedelta(days=period - 1)).strftime('%b %d')
    end_date = today.strftime('%b %d, %Y')
    lines.append(f"Period: {start_date} \u2013 {end_date}")
    lines.append("")

    if glucose_vals:
        avg_g = sum(glucose_vals) / len(glucose_vals)
        normal_pct = sum(1 for v in glucose_vals if 70 <= v <= 130) * 100 // len(glucose_vals)
        lines.append(f"\U0001fa78 Glucose: {len(glucose_vals)} readings")
        lines.append(f"   Avg: {avg_g:.0f} mg/dL | Range: {min(glucose_vals):.0f}\u2013{max(glucose_vals):.0f}")
        lines.append(f"   Normal: {normal_pct}%")
    else:
        lines.append("\U0001fa78 Glucose: No readings this week")

    lines.append("")

    if bp_readings:
        sys_vals = [s for s, _ in bp_readings]
        dia_vals = [d for _, d in bp_readings]
        avg_sys = sum(sys_vals) / len(sys_vals)
        avg_dia = sum(dia_vals) / len(dia_vals)
        elevated = sum(1 for s, d in bp_readings if s > 140 or d > 90)
        lines.append(f"\u2764\ufe0f Blood Pressure: {len(bp_readings)} readings")
        lines.append(f"   Avg: {avg_sys:.0f}/{avg_dia:.0f} mmHg")
        lines.append(f"   Elevated: {elevated}")
    else:
        lines.append("\u2764\ufe0f Blood Pressure: No readings this week")

    # Weight stats
    weight_vals = [r.weight_value for r in readings if r.reading_type == "weight" and r.weight_value]
    if weight_vals:
        avg_w = sum(weight_vals) / len(weight_vals)
        lines.append(f"\u2696\ufe0f Weight: {len(weight_vals)} readings")
        lines.append(f"   Avg: {avg_w:.1f} kg")
        lines.append(f"   Range: {min(weight_vals):.1f}\u2013{max(weight_vals):.1f} kg")
    else:
        lines.append("\u2696\ufe0f Weight: No readings this week")

    days_with = set()
    for r in readings:
        days_with.add(r.reading_timestamp.date())
    days_logged = len(days_with)
    lines.append("")
    lines.append(f"\U0001f4c5 Days logged: {days_logged}/{period}")
    lines.append("")
    lines.append("\u2014 Sent from Swasth Health App")

    summary_text = "\n".join(lines)

    return {
        "summary_text": summary_text,
        "profile_name": profile_name,
        "glucose_count": len(glucose_vals),
        "glucose_avg": round(sum(glucose_vals) / len(glucose_vals), 1) if glucose_vals else None,
        "bp_count": len(bp_readings),
        "bp_avg_sys": round(sum(s for s, _ in bp_readings) / len(bp_readings), 1) if bp_readings else None,
        "bp_avg_dia": round(sum(d for _, d in bp_readings) / len(bp_readings), 1) if bp_readings else None,
        "days_logged": days_logged,
        "total_readings": len(readings),
    }


@router.get("/readings/trend-summary")
def get_trend_summary(
    profile_id: int,
    period: int = Query(default=7, ge=7, le=90),
    format: str = Query(default="json", pattern="^(json|text)$"),
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """Layered trend summary: reuses dashboard AI insight + appends period-specific data.

    No extra Gemini calls — consistent messaging across all views, instant response.
    When format=text, returns a shareable weekly summary with emoji formatting.
    """
    get_profile_access_or_403(profile_id, user, db)

    # If text format requested, return shareable summary
    if format == "text":
        return _build_shareable_summary(profile_id, period, db)

    today = date.today()

    # ── Cache check ──────────────────────────────────────────────────
    cached = db.query(models.TrendSummaryCache).filter(
        models.TrendSummaryCache.profile_id == profile_id,
        models.TrendSummaryCache.period_days == period,
        models.TrendSummaryCache.cache_date == today,
    ).first()
    if cached:
        return {"summary": cached.summary_text, "period": period, "cached": True}

    # ── 1. Fetch dashboard AI insight (single source of truth) ───────
    latest_insight = (
        db.query(models.AiInsightLog)
        .filter(
            models.AiInsightLog.profile_id == profile_id,
            models.AiInsightLog.model_used != "failed",
        )
        .order_by(models.AiInsightLog.id.desc())
        .first()
    )
    base_insight = latest_insight.response_text if latest_insight else ""

    # ── 2. Compute period-specific data stats ────────────────────────
    period_start = datetime.combine(today - timedelta(days=period - 1), datetime.min.time())
    prev_period_start = datetime.combine(today - timedelta(days=period * 2 - 1), datetime.min.time())

    readings = (
        db.query(models.HealthReading)
        .filter(
            models.HealthReading.profile_id == profile_id,
            models.HealthReading.reading_timestamp >= period_start,
        )
        .order_by(models.HealthReading.reading_timestamp.asc())
        .all()
    )

    if not readings and not base_insight:
        return {"summary": f"No readings recorded in the last {period} days. Start logging to see trend insights.", "period": period, "cached": False}

    # Glucose stats
    glucose_vals = [r.glucose_value for r in readings if r.reading_type == "glucose" and r.glucose_value]
    data_parts = []
    if glucose_vals:
        avg_g = sum(glucose_vals) / len(glucose_vals)
        mid = len(glucose_vals) // 2
        first_half = sum(glucose_vals[:mid]) / max(mid, 1)
        second_half = sum(glucose_vals[mid:]) / max(len(glucose_vals) - mid, 1)
        if second_half < first_half * 0.95:
            trend = "improving ↓"
        elif second_half > first_half * 1.05:
            trend = "rising ↑"
        else:
            trend = "stable →"
        normal_pct = sum(1 for v in glucose_vals if 70 <= v <= 130) * 100 // len(glucose_vals)
        data_parts.append(
            f"Glucose: avg {avg_g:.0f} mg/dL ({len(glucose_vals)} readings), "
            f"range {min(glucose_vals):.0f}–{max(glucose_vals):.0f}, "
            f"{normal_pct}% normal, trend {trend}"
        )

    # BP stats
    bp_readings = [(r.systolic, r.diastolic) for r in readings if r.reading_type == "blood_pressure" and r.systolic and r.diastolic]
    if bp_readings:
        avg_sys = sum(s for s, _ in bp_readings) / len(bp_readings)
        avg_dia = sum(d for _, d in bp_readings) / len(bp_readings)
        elevated = sum(1 for s, d in bp_readings if s >= 130 or d >= 80)
        data_parts.append(
            f"BP: avg {avg_sys:.0f}/{avg_dia:.0f} mmHg ({len(bp_readings)} readings), "
            f"{elevated} elevated"
        )

    # Weight stats
    weight_vals = [r.weight_value for r in readings if r.reading_type == "weight" and r.weight_value]
    if weight_vals:
        avg_w = sum(weight_vals) / len(weight_vals)
        mid = len(weight_vals) // 2
        first_half = sum(weight_vals[:mid]) / max(mid, 1)
        second_half = sum(weight_vals[mid:]) / max(len(weight_vals) - mid, 1)
        if second_half < first_half - 0.5:
            trend = "decreasing ↓"
        elif second_half > first_half + 0.5:
            trend = "increasing ↑"
        else:
            trend = "stable →"
        data_parts.append(
            f"Weight: avg {avg_w:.1f} kg ({len(weight_vals)} readings), "
            f"range {min(weight_vals):.1f}\u2013{max(weight_vals):.1f}, "
            f"trend {trend}"
        )

    # Meal stats for the period
    period_meals = (
        db.query(models.MealLog)
        .filter(
            models.MealLog.profile_id == profile_id,
            models.MealLog.timestamp >= period_start,
        )
        .all()
    )
    if period_meals:
        from collections import Counter
        cat_counts = Counter(m.category for m in period_meals)
        heavy = cat_counts.get("HIGH_CARB", 0) + cat_counts.get("SWEETS", 0)
        data_parts.append(
            f"Diet: {len(period_meals)} meals logged, "
            f"{heavy} heavy/sweet"
        )

    # Previous period comparison
    prev_readings = (
        db.query(models.HealthReading)
        .filter(
            models.HealthReading.profile_id == profile_id,
            models.HealthReading.reading_timestamp >= prev_period_start,
            models.HealthReading.reading_timestamp < period_start,
        )
        .all()
    )
    prev_glucose = [r.glucose_value for r in prev_readings if r.reading_type == "glucose" and r.glucose_value]
    comparison = ""
    if prev_glucose and glucose_vals:
        prev_avg = sum(prev_glucose) / len(prev_glucose)
        curr_avg = sum(glucose_vals) / len(glucose_vals)
        diff = curr_avg - prev_avg
        if abs(diff) > 5:
            direction = "up" if diff > 0 else "down"
            comparison = f"vs previous {period}d: glucose {direction} {abs(diff):.0f} mg/dL"

    # ── 3. Assemble layered summary ──────────────────────────────────
    period_label = f"{period}-day"
    data_line = ". ".join(data_parts)
    if comparison:
        data_line += f". {comparison}"

    if base_insight:
        summary = f"{base_insight}\n\n{period_label} details: {data_line}." if data_line else base_insight
    elif data_line:
        summary = f"{period_label} summary: {data_line}."
    else:
        summary = f"You have {len(readings)} readings in the last {period} days. Keep tracking for better insights!"

    # ── Cache ────────────────────────────────────────────────────────
    try:
        cache_entry = models.TrendSummaryCache(
            profile_id=profile_id,
            period_days=period,
            cache_date=today,
            summary_text=summary,
            model_used="layered",
        )
        db.add(cache_entry)
        db.commit()
    except Exception:
        db.rollback()

    return {"summary": summary, "period": period, "cached": False}


@router.get("/readings/family-streaks")
def get_family_streaks(
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """Get streak and points for all profiles the user has access to."""
    accesses = (
        db.query(models.ProfileAccess)
        .filter(models.ProfileAccess.user_id == user.id)
        .all()
    )

    today = date.today()
    board = []

    for access in accesses:
        profile = db.query(models.Profile).filter(models.Profile.id == access.profile_id).first()
        if not profile:
            continue

        days_with_readings = set()
        for r in db.query(models.HealthReading).filter(
            models.HealthReading.profile_id == access.profile_id,
            models.HealthReading.reading_timestamp >= datetime.combine(today - timedelta(days=60), datetime.min.time()),
        ).all():
            days_with_readings.add(r.reading_timestamp.date())

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

        total = db.query(func.count(models.HealthReading.id)).filter(
            models.HealthReading.profile_id == access.profile_id,
        ).scalar() or 0

        pts = total * 10
        if streak >= 30: pts += 1500
        elif streak >= 14: pts += 700
        elif streak >= 7: pts += 300
        elif streak >= 3: pts += 100

        week_activity = []
        for d in range(6, -1, -1):
            day = today - timedelta(days=d)
            week_activity.append({
                "date": day.isoformat(),
                "weekday": day.strftime("%a"),
                "has_reading": day in days_with_readings,
            })

        board.append({
            "profile_id": access.profile_id,
            "profile_name": profile.name,
            "access_level": access.access_level,
            "streak_days": streak,
            "total_readings": total,
            "points": pts,
            "week_activity": week_activity,
        })

    board.sort(key=lambda x: (x["streak_days"], x["points"]), reverse=True)
    return {"leaderboard": board}


@router.get("/readings/weekly-summary", deprecated=True)
def get_weekly_summary(
    profile_id: int,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """Deprecated: use GET /readings/trend-summary?period=7&format=text instead."""
    get_profile_access_or_403(profile_id, user, db)
    return _build_shareable_summary(profile_id, 7, db)


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


@router.delete("/readings/{reading_id}", status_code=status.HTTP_204_NO_CONTENT)
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
    return Response(status_code=204)


@router.post("/readings/parse-image")
@limiter.limit("20/minute")
async def parse_image_with_gemini(
    request: Request,
    device_type: str,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """Use Gemini Vision to extract glucose or BP values from a device photo.

    Returns extracted values as JSON. Never raises 500 — returns
    {"error": "..."} so the Flutter app can fall back to local OCR.
    """
    if device_type not in _VALID_READING_TYPES:
        raise HTTPException(status_code=400, detail="device_type must be 'glucose' or 'blood_pressure'")

    if not settings.GEMINI_API_KEY and not settings.DEEPSEEK_API_KEY:
        return {"error": "No AI API key configured"}

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
        elif device_type == "weight":
            prompt = (
                "You are reading a digital weight scale display in this photo.\n"
                "Extract the weight value shown.\n\n"
                "Rules:\n"
                "- Weight is typically a 2–3 digit number with one decimal (e.g., 72.5)\n"
                "- If the display shows 'ERR' or is unreadable, use null\n"
                "- Ignore units (kg, lb) — respond with the raw number\n"
                "- Assume the value is in kg unless explicitly marked otherwise\n\n"
                "Respond with ONLY a JSON object, no explanation, no markdown:\n"
                '{"weight": <number or null>}'
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

        # Use ai_service fallback chain: Gemini Vision → DeepSeek text → None
        import ai_service
        all_text = ai_service.generate_vision_insight(
            prompt, image_bytes, 0, db,
            prompt_summary=f"parse-image-{device_type}",
            mime_type=mime_type,
        )

        if not all_text:
            return {"error": "AI could not process the image. Please enter values manually."}

        import re
        json_match = re.search(r"\{[^{}]+\}", all_text, re.DOTALL)
        if not json_match:
            return {"error": "AI could not extract values from the image"}

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
        elif device_type == "weight":
            weight = parsed.get("weight")
            if weight is not None and not (5 <= weight <= 500):
                weight = None
            if weight is None:
                return {"error": "Could not extract valid weight value from image"}
            return {"weight": weight}
        else:
            glucose = parsed.get("glucose")
            if glucose is not None and not (20 <= glucose <= 600):
                glucose = None
            if glucose is None:
                return {"error": "Could not extract valid glucose value from image"}
            return {"glucose": glucose}

    except (json.JSONDecodeError, KeyError):
        # Upstream returned a response we couldn't parse — treat as a
        # temporary upstream failure. Log the payload internally for ops;
        # client gets a generic message that doesn't leak model output.
        logger.warning(
            "vision analysis: unparseable response device_type=%s",
            device_type,
            exc_info=True,
        )
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Could not read the image. Please try again or enter values manually.",
        )
    except Exception:
        # Any other failure from the vision pipeline — API key revoked,
        # rate limit, network timeout, model safety filter, etc. None of
        # these are safe to echo to the user (would leak API endpoint
        # URLs, auth headers, or model-internal strings). Log the full
        # trace for operators; return sanitized 503.
        logger.error(
            "vision analysis failed device_type=%s",
            device_type,
            exc_info=True,
        )
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Image analysis is temporarily unavailable. Please enter values manually.",
        )


def _rule_based_insight(recent: list, db: Session, total_count: int = 0) -> str:
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

    # Weight specific tips (check this BEFORE general NORMAL status)
    weight_readings = [r for r in recent if r.reading_type == "weight" and r.weight_value]
    if weight_readings:
        latest_w = weight_readings[-1].weight_value
        profile = db.query(models.Profile).filter(models.Profile.id == weight_readings[-1].profile_id).first()
        if profile and profile.height:
            bmi = latest_w / ((profile.height / 100) ** 2)
            if bmi >= 25:
                # Still check if other things are high, but if everything else is normal, tell them about BMI
                msg = f"Your BMI is {bmi:.1f} (Overweight). Try reducing carbs and aim for daily activity."
                if any("HIGH" in (s or "") for s in statuses):
                    return f"Some readings are elevated, and your BMI is {bmi:.1f}. Focus on diet and movement."
                return msg
            if bmi < 18.5:
                return f"Your BMI is {bmi:.1f} (Underweight). Ensure you are getting enough nutrition."

    if any("HIGH" in (s or "") for s in statuses):
        return "Some readings were elevated this week. Stay hydrated and keep active."

    if statuses and all(s == "NORMAL" for s in statuses):
        return "All recent readings look healthy. Keep up the great work!"
    return "Readings logged. Keep tracking daily for better health insights."


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

@router.post("/report/manual-trigger", status_code=202)
@limiter.limit("1/hour", key_func=get_remote_address)
def manually_trigger_whatsapp_report(
    request: Request,
    background_tasks: BackgroundTasks,
    user: models.User = Depends(get_current_user),
):
    """
    Manually trigger WhatsApp health reports for all profiles owned by the current user.
    Limited to 1 request per hour to prevent spam.
    """
    background_tasks.add_task(
        send_weekly_reports,
        trigger_type=ReportTriggerType.MANUAL,
        user_id=user.id,
    )
    return {"message": "Report generation started. You will receive a WhatsApp message shortly."}
