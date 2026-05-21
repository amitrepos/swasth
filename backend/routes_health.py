# Context: Handles health data processing and profile-specific metrics.
# Related: backend/main.py, lib/services/health_reading_service.dart

"""Health Readings API Routes"""
from fastapi import APIRouter, BackgroundTasks, Depends, File, HTTPException, Query, Request, UploadFile, status
from fastapi.responses import Response
from sqlalchemy import func
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime, date, timedelta, timezone
from slowapi import Limiter
from slowapi.util import get_remote_address
import logging
import os
import json

logger = logging.getLogger(__name__)
import models
import schemas
from database import get_db
from dependencies import get_current_user, get_profile_access_or_403, get_profile_editor_or_403, require_india_writer
from config import settings
from health_utils import generate_meal_insights
from report_service import trigger_single_profile_report, send_weekly_reports
from models import ReportTriggerType

_enabled = os.environ.get("TESTING", "").lower() != "true"
limiter = Limiter(key_func=get_remote_address, enabled=_enabled)
from encryption_service import encrypt, encrypt_float
from health_utils import age_context_bp, age_context_glucose, classify_bp, classify_glucose, classify_spo2
from utils.datetime_helpers import ensure_utc

router = APIRouter()

_VALID_READING_TYPES = {'glucose', 'blood_pressure', 'spo2', 'steps', 'weight'}
_SUPPORTED_LANGS = {'en', 'hi', 'kn', 'te', 'ta'}


def _normalize_language(language: str) -> str:
    """Coerce caller-supplied language to a supported code, defaulting to English.

    Prevents typos / future-language requests from silently masking
    translation bugs — invalid input → 'en' rather than passing through.
    """
    return language if language in _SUPPORTED_LANGS else 'en'


def _refresh_doctor_triage_for_profile(db: Session, profile_id: int) -> None:
    """Recompute the DoctorPatientLink triage cache for every active link
    on this profile.

    The doctor's patient-detail screen returns `triage_status`,
    `compliance_7d`, `trend_direction`, and `last_reading_*` directly off
    the link row (cached). Without this refresh, editing or deleting a
    reading leaves stale triage values on the doctor dashboard until the
    doctor next opens the triage list.

    Lazy-imported to avoid a circular import between routes_health and
    routes_doctor. Failures must never break the reading write — caller
    is expected to have already committed the reading change.
    """
    try:
        from routes_doctor import _compute_triage_status  # local import
        from datetime import datetime as _dt, timezone as _tz

        active_links = (
            db.query(models.DoctorPatientLink)
            .filter(
                models.DoctorPatientLink.profile_id == profile_id,
                models.DoctorPatientLink.status == "active",
            )
            .all()
        )
        if not active_links:
            return

        triage = _compute_triage_status(profile_id, db)
        now = _dt.now(_tz.utc)
        for link in active_links:
            link.triage_status = triage["triage_status"]
            link.last_reading_value = triage["last_reading_value"]
            link.last_reading_type = triage["last_reading_type"]
            link.last_reading_at = triage["last_reading_at"]
            link.compliance_7d = triage["compliance_7d"]
            link.trend_direction = triage["trend_direction"]
            link.triage_updated_at = now
        db.commit()
    except Exception:
        logger.warning(
            "Doctor triage refresh failed for profile %s",
            profile_id,
            exc_info=True,
        )
        db.rollback()

# Cache: one Gemini call per (profile_id, date) — clears on server restart
_insight_cache: dict[tuple[int, str], str] = {}


@router.post("/readings", status_code=status.HTTP_201_CREATED)
def save_reading(
    reading: schemas.HealthReadingCreate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
    _region: dict = Depends(require_india_writer),
):
    """Save a new health reading (glucose, blood pressure, SpO2, or steps) for a specific profile."""
    # Region gate (NUO-135): non-India callers are blocked upstream by `require_india_writer`.
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

    # ── Steps deduplication: check if same step count already exists today ─
    if reading.reading_type == 'steps' and reading.steps_count is not None:
        today = date.today()
        today_start = datetime.combine(today, datetime.min.time(), tzinfo=timezone.utc)
        today_end = datetime.combine(today, datetime.max.time(), tzinfo=timezone.utc)
        
        # Find the latest steps reading for today
        latest_today_steps = db.query(models.HealthReading).filter(
            models.HealthReading.profile_id == reading.profile_id,
            models.HealthReading.reading_type == 'steps',
            models.HealthReading.reading_timestamp >= today_start,
            models.HealthReading.reading_timestamp <= today_end,
        ).order_by(models.HealthReading.reading_timestamp.desc()).first()
        
        if latest_today_steps and latest_today_steps.steps_count == reading.steps_count:
            # Same step count already exists for today - skip storing
            return {
                "skipped": True,
                "reason": "duplicate_steps",
                "steps_count": reading.steps_count,
                "existing_id": latest_today_steps.id,
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
        meal_context=reading.meal_context if reading.reading_type == 'glucose' else None,
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

    # Keep Profile.weight in sync with the latest weight reading so doctor screen,
    # profile screen, and BMI calculations reflect the patient's current weight.
    if reading.reading_type == "weight" and reading.weight_value is not None:
        profile = db.query(models.Profile).filter(
            models.Profile.id == reading.profile_id
        ).first()
        if profile is not None:
            profile.weight = reading.weight_value

    db.commit()
    db.refresh(db_reading)

    # Invalidate AI insight cache so the next home screen load gets a fresh Gemini recommendation
    stale = [k for k in _insight_cache if k[0] == reading.profile_id]
    for k in stale:
        del _insight_cache[k]

    # Invalidate TrendSummaryCache so Insights tab reflects new readings
    try:
        db.query(models.TrendSummaryCache).filter(
            models.TrendSummaryCache.profile_id == reading.profile_id
        ).delete()
        db.commit()
    except Exception:
        logger.warning(
            "TrendSummaryCache invalidation failed for profile %s",
            reading.profile_id,
            exc_info=True,
        )
        db.rollback()

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
    language: str = Query(default="en"),
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """Compute a 0–100 health score, streak, and insight for the home screen dashboard."""
    get_profile_access_or_403(profile_id, user, db)
    language = _normalize_language(language)

    profile = db.query(models.Profile).filter(models.Profile.id == profile_id).first()
    profile_age = profile.age if profile else None

    today = datetime.now(timezone.utc).date()  # use UTC date so timestamp comparisons are consistent
    seven_days_ago = datetime.combine(today - timedelta(days=6), datetime.min.time(), tzinfo=timezone.utc)

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

    # Today's readings — compare in UTC; ensure_utc handles naive SQLite timestamps in tests
    today_start = datetime.combine(today, datetime.min.time(), tzinfo=timezone.utc)
    today_readings = [r for r in recent if ensure_utc(r.reading_timestamp) >= today_start]

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
        models.HealthReading.reading_timestamp >= datetime.combine(today - timedelta(days=60), datetime.min.time(), tzinfo=timezone.utc),
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
        if language == "hi":
            insight = f"⚠️ आपकी {critical_type} गंभीर है। कृपया डॉक्टर से मिलें।"
        elif language == "kn":
            insight = f"⚠️ ನಿಮ್ಮ {critical_type} ಗಂಭೀರವಾಗಿದೆ. ದಯವಿಟ್ಟು ವೈದ್ಯರನ್ನು ಸಂಪರ್ಕಿಸಿ."
        elif language == "te":
            insight = f"⚠️ మీ {critical_type} తీవ్రంగా ఉంది. దయచేసి వైద్యుడిని సంప్రదించండి."
        elif language == "ta":
            insight = f"⚠️ உங்கள் {critical_type} கடுமையாக உள்ளது. தயவுசெய்து மருத்துவரை அணுகுங்கள்."
        else:
            insight = f"⚠️ Your {critical_type} is critical. Please consult a doctor."
    elif not today_readings:
        if total_reading_count == 0:
            if language == "hi": insight = "अपनी पहली रीडिंग दर्ज करके अपने स्वास्थ्य पर नज़र रखना शुरू करें।"
            elif language == "kn": insight = "ನಿಮ್ಮ ಆರೋಗ್ಯವನ್ನು ಟ್ರ್ಯಾಕ್ ಮಾಡಲು ನಿಮ್ಮ ಮೊದಲ ರೀಡಿಂಗ್ ದಾಖಲಿಸಿ."
            elif language == "te": insight = "మీ ఆరోగ్యాన్ని ట్రాక్ చేయడానికి మీ మొదటి రీడింగ్ నమోదు చేయండి."
            elif language == "ta": insight = "உங்கள் உடல்நலனை கண்காணிக்க முதல் அளவீட்டை பதிவு செய்யுங்கள்."
            else: insight = "Log your first reading to start tracking your health."
        elif streak > 0:
            if language == "hi": insight = f"अपनी {streak} दिनों की स्ट्रीक को बनाए रखने के लिए आज एक रीडिंग दर्ज करें!"
            elif language == "kn": insight = f"ನಿಮ್ಮ {streak}-ದಿನಗಳ ಸತತ ದಾಖಲೆಯನ್ನು ಉಳಿಸಿಕೊಳ್ಳಲು ಇಂದು ರೀಡಿಂಗ್ ದಾಖಲಿಸಿ!"
            elif language == "te": insight = f"మీ {streak}-రోజుల స్ట్రీక్ కొనసాగించడానికి నేడు రీడింగ్ నమోదు చేయండి!"
            elif language == "ta": insight = f"உங்கள் {streak}-நாள் தொடரை தொடர இன்று அளவீடு பதிவு செய்யுங்கள்!"
            else: insight = f"Log a reading today to keep your {streak}-day streak alive!"
        else:
            if language == "hi": insight = f"वापसी पर स्वागत है! आपके पास {total_reading_count} रीडिंग हैं। अपनी स्ट्रीक फिर से शुरू करने के लिए आज की रीडिंग दर्ज करें।"
            elif language == "kn": insight = f"ಮರಳಿ ಸ್ವಾಗತ! ನಿಮ್ಮ ಬಳಿ {total_reading_count} ರೀಡಿಂಗ್‌ಗಳಿವೆ. ನಿಮ್ಮ ಸತತ ದಾಖಲೆಯನ್ನು ಮತ್ತೆ ಪ್ರಾರಂಭಿಸಲು ಇಂದಿನ ರೀಡಿಂಗ್ ದಾಖಲಿಸಿ."
            elif language == "te": insight = f"తిరిగి స్వాగతం! మీకు {total_reading_count} రీడింగులు ఉన్నాయి. మీ స్ట్రీక్ పునఃప్రారంభించడానికి నేటి రీడింగ్ నమోదు చేయండి."
            elif language == "ta": insight = f"மீண்டும் வரவேற்கிறோம்! உங்களிடம் {total_reading_count} அளவீடுகள் உள்ளன. உங்கள் தொடரை மீண்டும் தொடங்க இன்றைய அளவீடு பதிவு செய்யுங்கள்."
            else: insight = f"Welcome back! You have {total_reading_count} readings on file. Log today's reading to restart your streak."
    elif streak >= 7:
        if language == "hi": insight = f"🔥 {streak} दिनों की स्ट्रीक — आप एक बेहतरीन आदत बना रहे हैं!"
        elif language == "kn": insight = f"🔥 {streak}-ದಿನಗಳ ಸತತ ದಾಖಲೆ — ನೀವು ಉತ್ತಮ ಅಭ್ಯಾಸವನ್ನು ಬೆಳೆಸಿಕೊಳ್ಳುತ್ತಿದ್ದೀರಿ!"
        elif language == "te": insight = f"🔥 {streak}-రోజుల స్ట్రీక్ — మీరు గొప్ప అలవాటు పెంచుకుంటున్నారు!"
        elif language == "ta": insight = f"🔥 {streak}-நாள் தொடர் — நீங்கள் சிறந்த பழக்கத்தை உருவாக்கிக்கொள்கிறீர்கள்!"
        else: insight = f"🔥 {streak}-day streak — you're building a great habit!"
    elif 'HIGH - STAGE 2' in today_statuses_set:
        stage2 = next((r for r in today_readings if r.status_flag == 'HIGH - STAGE 2'), None)
        if stage2 and stage2.reading_type == 'blood_pressure' and stage2.systolic:
            if language == "hi": insight = f"⚠️ आपका बीपी {stage2.systolic:.0f}/{stage2.diastolic:.0f} बहुत अधिक है। क्या आपने दवा ली है? कृपया आज ही डॉक्टर से मिलें।"
            elif language == "kn": insight = f"⚠️ ನಿಮ್ಮ ರಕ್ತದೊತ್ತಡ {stage2.systolic:.0f}/{stage2.diastolic:.0f} ಅಪಾಯಕಾರಿಯಾಗಿ ಹೆಚ್ಚಾಗಿದೆ. ನೀವು ಔಷಧಿ ತೆಗೆದುಕೊಂಡಿದ್ದೀರಾ? ದಯವಿಟ್ಟು ಇಂದೇ ವೈದ್ಯರನ್ನು ಭೇಟಿ ಮಾಡಿ."
            elif language == "te": insight = f"⚠️ మీ BP {stage2.systolic:.0f}/{stage2.diastolic:.0f} ప్రమాదకరంగా ఎక్కువగా ఉంది. మీరు మందు తీసుకున్నారా? దయచేసి నేడే వైద్యుడిని కలవండి."
            elif language == "ta": insight = f"⚠️ உங்கள் BP {stage2.systolic:.0f}/{stage2.diastolic:.0f} ஆபத்தான அளவில் அதிகமாக உள்ளது. மருந்து எடுத்தீர்களா? தயவுசெய்து இன்றே மருத்துவரை சந்தியுங்கள்."
            else: insight = f"⚠️ BP {stage2.systolic:.0f}/{stage2.diastolic:.0f} is dangerously high. Have you taken your medication? Please see a doctor today."
        else:
            if language == "hi": insight = "⚠️ एक रीडिंग स्टेज 2 के स्तर पर है। कृपया अपनी दवा की जाँच करें और डॉक्टर से सलाह लें।"
            elif language == "kn": insight = "⚠️ ಒಂದು ರೀಡಿಂಗ್ ಹಂತ 2 ರಲ್ಲಿದೆ. ದಯವಿಟ್ಟು ನಿಮ್ಮ ಔಷಧಿಗಳನ್ನು ಪರಿಶೀಲಿಸಿ ಮತ್ತು ವೈದ್ಯರನ್ನು ಸಂಪರ್ಕಿಸಿ."
            elif language == "te": insight = "⚠️ ఒక రీడింగ్ స్టేజ్ 2 స్థాయిలో ఉంది. మీ మందులను తనిఖీ చేయండి మరియు వైద్యుడిని సంప్రదించండి."
            elif language == "ta": insight = "⚠️ ஒரு அளவீடு நிலை 2 அளவில் உள்ளது. மருந்துகளை சரிபார்த்து மருத்துவரை அணுகுங்கள்."
            else: insight = "⚠️ A reading is in Stage 2 range. Please check your medication and consult your doctor."
    elif any('HIGH' in (s or '') for s in today_statuses_set):
        high_type = next(
            (r.reading_type.replace('_', ' ') for r in today_readings if 'HIGH' in (r.status_flag or '')), 'reading'
        )
        if language == "hi": insight = f"आपकी {high_type} थोड़ी अधिक है। 10 मिनट की सैर और पानी पीते रहने से अक्सर मदद मिलती है।"
        elif language == "kn": insight = f"ನಿಮ್ಮ {high_type} ಸ್ವಲ್ಪ ಹೆಚ್ಚಾಗಿದೆ. 10 ನಿಮಿಷಗಳ ನಡಿಗೆ ಮತ್ತು ಸಾಕಷ್ಟು ನೀರು ಕುಡಿಯುವುದು ಹೆಚ್ಚಾಗಿ ಸಹಾಯ ಮಾಡುತ್ತದೆ."
        elif language == "te": insight = f"మీ {high_type} కొద్దిగా ఎక్కువగా ఉంది. 10 నిమిషాల నడక మరియు తగినంత నీరు తాగడం తరచుగా సహాయపడుతుంది."
        elif language == "ta": insight = f"உங்கள் {high_type} சற்று அதிகமாக உள்ளது. 10 நிமிட நடை மற்றும் போதுமான தண்ணீர் குடிப்பது பெரும்பாலும் உதவும்."
        else: insight = f"Your {high_type} is a bit elevated. A 10-min walk and staying hydrated often helps."
    elif streak >= 3:
        if language == "hi": insight = f"बहुत बढ़िया! {streak} दिनों से लगातार नज़र रख रहे हैं। इसे जारी रखें!"
        elif language == "kn": insight = f"ಅದ್ಭುತ ಕೆಲಸ! {streak} ದಿನಗಳ ನಿರಂತರ ಮೇಲ್ವಿಚಾರಣೆ. ಹೀಗೆಯೇ ಮುಂದುವರಿಸಿ!"
        elif language == "te": insight = f"చాలా బాగుంది! {streak} రోజుల నిరంతర పర్యవేక్షణ. ఇలాగే కొనసాగించండి!"
        elif language == "ta": insight = f"சிறப்பான வேலை! {streak} நாட்கள் தொடர்ந்து கண்காணிப்பு. தொடர்ந்து வாருங்கள்!"
        else: insight = f"Great work! {streak} days of consistent monitoring. Keep it up!"
    elif today_statuses_set and all(s == 'NORMAL' for s in today_statuses_set):
        if language == "hi": insight = "आज सभी रीडिंग सामान्य लग रही हैं। बहुत बढ़िया!"
        elif language == "kn": insight = "ಇಂದು ಎಲ್ಲಾ ರೀಡಿಂಗ್‌ಗಳು ಆರೋಗ್ಯಕರವಾಗಿವೆ. ನೀವು ಉತ್ತಮವಾಗಿ ಮಾಡುತ್ತಿದ್ದೀರಿ!"
        elif language == "te": insight = "నేడు అన్ని రీడింగులు ఆరోగ్యకరంగా ఉన్నాయి. మీరు చాలా బాగా చేస్తున్నారు!"
        elif language == "ta": insight = "இன்று அனைத்து அளவீடுகளும் ஆரோக்கியமாக உள்ளன. நீங்கள் சிறப்பாக செய்கிறீர்கள்!"
        else: insight = "All readings look healthy today. You're doing great!"
    else:
        if total_reading_count > 1:
            if language == "hi": insight = "रीडिंग दर्ज की गई। बेहतर सुझावों के लिए रोज़ाना ट्रैक करें!"
            elif language == "kn": insight = "ರೀಡಿಂಗ್ ದಾಖಲಿಸಲಾಗಿದೆ. ಉತ್ತಮ ಒಳನೋಟಗಳಿಗಾಗಿ ಪ್ರತಿದಿನ ಟ್ರ್ಯಾಕ್ ಮಾಡುವುದನ್ನು ಮುಂದುವರಿಸಿ!"
            elif language == "te": insight = "రీడింగులు నమోదు అయ్యాయి. మెరుగైన అంతర్దృష్టుల కోసం ప్రతిరోజూ ట్రాక్ చేస్తూ ఉండండి!"
            elif language == "ta": insight = "அளவீடுகள் பதிவு செய்யப்பட்டன. சிறந்த நுண்ணறிவுகளுக்காக தினமும் கண்காணியுங்கள்!"
            else: insight = "Readings logged. Keep tracking daily for better insights!"
        else:
            if language == "hi": insight = "पहली रीडिंग दर्ज की गई! इसे जारी रखें — रोज़ाना ट्रैक करने से बेहतर सुझाव मिलते हैं।"
            elif language == "kn": insight = "ಮೊದಲ ರೀಡಿಂಗ್ ದಾಖಲಿಸಲಾಗಿದೆ! ಮುಂದುವರಿಸಿ — ಪ್ರತಿದಿನದ ಟ್ರ್ಯಾಕಿಂಗ್ ಉತ್ತಮ ಒಳನೋಟಗಳನ್ನು ನೀಡುತ್ತದೆ."
            elif language == "te": insight = "మొదటి రీడింగ్ నమోదు అయింది! కొనసాగించండి — రోజువారీ ట్రాకింగ్ మెరుగైన అంతర్దృష్టులు ఇస్తుంది."
            elif language == "ta": insight = "முதல் அளவீடு பதிவு செய்யப்பட்டது! தொடர்ந்து வாருங்கள் — தினசரி கண்காணிப்பு சிறந்த நுண்ணறிவுகளை வழங்கும்."
            else: insight = "First reading logged! Keep going — daily tracking unlocks better insights."

    last_logged = recent[0].reading_timestamp if recent else None

    # --- 90-day averages for Vital Summary ---
    ninety_days_ago = datetime.combine(today - timedelta(days=89), datetime.min.time(), tzinfo=timezone.utc)
    prev_90_start = datetime.combine(today - timedelta(days=179), datetime.min.time(), tzinfo=timezone.utc)

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
        _BMI = {
            "underweight": {
                "en": "Underweight",
                "hi": "कम वजन (Underweight)",
                "kn": "ಕಡಿಮೆ ತೂಕ (Underweight)",
                "te": "తక్కువ బరువు (Underweight)",
                "ta": "எடை குறைவு (Underweight)",
            },
            "normal": {
                "en": "Normal",
                "hi": "सामान्य (Normal)",
                "kn": "ಸಾಮಾನ್ಯ (Normal)",
                "te": "సాధారణం (Normal)",
                "ta": "சாதாரண (Normal)",
            },
            "overweight": {
                "en": "Overweight",
                "hi": "अधिक वजन (Overweight)",
                "kn": "ಹೆಚ್ಚು ತೂಕ (Overweight)",
                "te": "అధిక బరువు (Overweight)",
                "ta": "அதிக எடை (Overweight)",
            },
            "obese": {
                "en": "Obese",
                "hi": "मोटापा (Obese)",
                "kn": "ಬೊಜ್ಜು (Obese)",
                "te": "ఊబకాయం (Obese)",
                "ta": "உடல் பருமன் (Obese)",
            },
        }
        if bmi < 18.5:
            bucket = "underweight"
        elif bmi < 25:
            bucket = "normal"
        elif bmi < 30:
            bucket = "overweight"
        else:
            bucket = "obese"
        bmi_category = _BMI[bucket].get(language, _BMI[bucket]["en"])

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
        last_glucose_meal_context=(
            last_glucose.meal_context if last_glucose else None
        ),
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
    language: str = Query(default="en"),
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """Return a personalised 1-2 sentence AI health recommendation via Gemini 1.5 Flash.
    Falls back to rule-based insight on any error — never returns 500."""
    get_profile_access_or_403(profile_id, user, db)
    language = _normalize_language(language)

    # ── AI consent gate — return rule-based fallback if user hasn't consented ──
    if not user.ai_consent:
        thirty_days_ago = datetime.combine(date.today() - timedelta(days=29), datetime.min.time(), tzinfo=timezone.utc)
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
        insight = _rule_based_insight(recent, db, total_count=total_count, language=language)
        return {"insight": insight, "ai_consent_required": True}

    # ── Smart cache: per-language — only call LLM when new readings exist ──
    # Non-English entries are tagged __lang:XX__ in prompt_summary so each
    # language has its own cache slot and English never reads a foreign entry.
    _lang_tag = f"__lang:{language}__" if language != "en" else None

    def _base_insight_query():
        q = (
            db.query(models.AiInsightLog)
            .filter(
                models.AiInsightLog.profile_id == profile_id,
                models.AiInsightLog.model_used != "failed",
                models.AiInsightLog.model_used != "invalidated",
                (models.AiInsightLog.prompt_summary.is_(None)) |
                (models.AiInsightLog.prompt_summary.notlike('%nutrition%')),
            )
        )
        if language == "en":
            # English cache: exclude entries tagged for other languages
            q = q.filter(
                (models.AiInsightLog.prompt_summary.is_(None)) |
                (models.AiInsightLog.prompt_summary.notlike('%__lang:%')),
            )
        else:
            # Non-English: only match entries for this exact language
            q = q.filter(models.AiInsightLog.prompt_summary.like(f'{_lang_tag}%'))
        return q

    latest_insight = _base_insight_query().order_by(models.AiInsightLog.created_at.desc()).first()
    latest_reading = (
        db.query(models.HealthReading)
        .filter(models.HealthReading.profile_id == profile_id)
        .order_by(models.HealthReading.reading_timestamp.desc())
        .first()
    )

    if latest_insight and latest_reading:
        # Use cached response if no new readings since it was generated
        insight_time = ensure_utc(latest_insight.created_at)
        reading_time = ensure_utc(latest_reading.reading_timestamp)
        if insight_time and reading_time and reading_time <= insight_time:
            return {"insight": latest_insight.response_text}

    # ── Need fresh insight — fetch data ───────────────────────────────
    profile = db.query(models.Profile).filter(models.Profile.id == profile_id).first()

    thirty_days_ago = datetime.combine(date.today() - timedelta(days=29), datetime.min.time(), tzinfo=timezone.utc)
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
    fallback = _rule_based_insight(recent, db, total_count=total_count, language=language)

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

    lang_instruction = ""
    if language == "hi":
        lang_instruction = "IMPORTANT: Please write the response ONLY in Hindi (हिन्दी)."
    elif language == "kn":
        lang_instruction = "IMPORTANT: Please write the response ONLY in Kannada (ಕನ್ನಡ)."
    elif language == "te":
        lang_instruction = "IMPORTANT: Please write the response ONLY in Telugu (తెలుగు)."
    elif language == "ta":
        lang_instruction = "IMPORTANT: Please write the response ONLY in Tamil (தமிழ்)."

    prompt = f"""Patient: {age_desc}, {gender}. {conditions}. {medications}. {glucose_summary} {bp_summary} {weight_summary} {food_summary}{trend_note}

Write exactly 2-3 short sentences: one about their status, one actionable tip. Under 50 words total. No greetings, no raw data numbers, no bullet points.
IMPORTANT: Even if glucose and BP are normal, if BMI is high (>= 25) or weight is trending up, prioritize weight management advice.
Use suggestive language only ("may help", "consider").
{lang_instruction}"""

    import ai_service
    _raw_summary = f"{glucose_summary} {bp_summary} {weight_summary} {food_summary}{trend_note}".strip() or None
    # Tag non-English summaries so each language has its own cache slot in AiInsightLog
    prompt_summary = f"{_lang_tag} {_raw_summary}" if _lang_tag else _raw_summary
    insight = ai_service.generate_health_insight(prompt, profile_id, db, prompt_summary)

    if insight:
        # Append top meal insight if available (max 1 to keep it concise)
        if meal_tips:
            insight = f"{insight}\n\n{meal_tips[0]}"
        
        logger.info(f"AI Insight response for profile {profile_id}: {insight[:200]}...")
        return {"insight": insight}

    # All AI models failed — use rule-based fallback and log it
    ai_service._log(db, profile_id, "rule-based", prompt_summary, fallback, None, None, None)
    if meal_tips:
        fallback = f"{fallback}\n\n{meal_tips[0]}"
    
    return {"insight": fallback}


def _build_shareable_summary(profile_id: int, period: int, db: Session):
    """Build a shareable text summary for the given profile and period."""
    today = date.today()
    period_start = datetime.combine(today - timedelta(days=period - 1), datetime.min.time(), tzinfo=timezone.utc)

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
    language: str = Query(default="en"),
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """Layered trend summary: reuses dashboard AI insight + appends period-specific data.

    No extra Gemini calls — consistent messaging across all views, instant response.
    When format=text, returns a shareable weekly summary with emoji formatting.
    """
    get_profile_access_or_403(profile_id, user, db)
    language = _normalize_language(language)

    # If text format requested, return shareable summary
    if format == "text":
        return _build_shareable_summary(profile_id, period, db)

    today = date.today()

    # ── Cache check (English only — non-English always rebuilds with translated strings) ──
    if language == "en":
        cached = db.query(models.TrendSummaryCache).filter(
            models.TrendSummaryCache.profile_id == profile_id,
            models.TrendSummaryCache.period_days == period,
            models.TrendSummaryCache.cache_date == today,
        ).first()
        if cached:
            return {"summary": cached.summary_text, "period": period, "cached": True}

    # ── 1. Fetch dashboard AI insight (single source of truth) ───────
    # Use the same language-tag filter as get_ai_insight so the base insight
    # matches the requested language (English never reads a Telugu/Hindi entry).
    _ts_lang_tag = f"__lang:{language}__" if language != "en" else None
    _base_q = (
        db.query(models.AiInsightLog)
        .filter(
            models.AiInsightLog.profile_id == profile_id,
            models.AiInsightLog.model_used != "failed",
            models.AiInsightLog.model_used != "invalidated",
            (models.AiInsightLog.prompt_summary.is_(None)) |
            (models.AiInsightLog.prompt_summary.notlike('%nutrition%')),
        )
    )
    if language == "en":
        _base_q = _base_q.filter(
            (models.AiInsightLog.prompt_summary.is_(None)) |
            (models.AiInsightLog.prompt_summary.notlike('%__lang:%')),
        )
    else:
        _base_q = _base_q.filter(
            models.AiInsightLog.prompt_summary.like(f'{_ts_lang_tag}%')
        )
    latest_insight = (
        _base_q
        .order_by(models.AiInsightLog.id.desc())
        .first()
    )
    base_insight = latest_insight.response_text if latest_insight else ""
    
    # Clean the insight if it contains JSON (defensive check)
    if base_insight and ('{' in base_insight or '```' in base_insight):
        import ai_service
        base_insight = ai_service._clean_ai_response(base_insight)

    # ── 2. Compute period-specific data stats ────────────────────────
    period_start = datetime.combine(today - timedelta(days=period - 1), datetime.min.time(), tzinfo=timezone.utc)
    prev_period_start = datetime.combine(today - timedelta(days=period * 2 - 1), datetime.min.time(), tzinfo=timezone.utc)

    readings = (
        db.query(models.HealthReading)
        .filter(
            models.HealthReading.profile_id == profile_id,
            models.HealthReading.reading_timestamp >= period_start,
        )
        .order_by(models.HealthReading.reading_timestamp.asc())
        .all()
    )

    # ── Multilingual stat strings ──────────────────────────────────────────
    _S = {
        "en": {
            "no_readings": f"No readings recorded in the last {period} days. Start logging to see trend insights.",
            "glucose_avg": "Glucose: avg", "readings": "readings", "normal": "normal", "trend": "trend",
            "improving": "improving ↓", "rising": "rising ↑", "stable": "stable →",
            "bp_avg": "BP: avg", "elevated": "elevated",
            "weight_avg": "Weight: avg", "weight_trend": "trend",
            "decreasing": "decreasing ↓", "increasing": "increasing ↑",
            "diet": "Diet", "meals_logged": "meals logged", "heavy_sweet": "heavy/sweet",
            "vs_prev": f"vs previous {period}d: glucose", "up": "up", "down": "down",
            "period_label": f"{period}-day", "details": "details", "summary_lbl": "summary",
            "keep_tracking": f"You have {{count}} readings in the last {period} days. Keep tracking for better insights!",
        },
        "hi": {
            "no_readings": f"पिछले {period} दिनों में कोई रीडिंग दर्ज नहीं हुई। ट्रेंड देखने के लिए लॉग करना शुरू करें।",
            "glucose_avg": "ग्लूकोज़: औसत", "readings": "रीडिंग", "normal": "सामान्य", "trend": "ट्रेंड",
            "improving": "सुधर रहा ↓", "rising": "बढ़ रहा ↑", "stable": "स्थिर →",
            "bp_avg": "बीपी: औसत", "elevated": "उच्च",
            "weight_avg": "वजन: औसत", "weight_trend": "ट्रेंड",
            "decreasing": "घट रहा ↓", "increasing": "बढ़ रहा ↑",
            "diet": "आहार", "meals_logged": "भोजन लॉग किए", "heavy_sweet": "भारी/मीठे",
            "vs_prev": f"पिछले {period} दिनों से तुलना: ग्लूकोज़", "up": "बढ़ा", "down": "घटा",
            "period_label": f"{period} दिन", "details": "विवरण", "summary_lbl": "सारांश",
            "keep_tracking": f"पिछले {period} दिनों में {{count}} रीडिंग हैं। बेहतर जानकारी के लिए ट्रैकिंग जारी रखें!",
        },
        "kn": {
            "no_readings": f"ಕಳೆದ {period} ದಿನಗಳಲ್ಲಿ ಯಾವುದೇ ರೀಡಿಂಗ್ ದಾಖಲಿಸಲಾಗಿಲ್ಲ. ಟ್ರೆಂಡ್ ನೋಡಲು ಲಾಗ್ ಮಾಡಲು ಪ್ರಾರಂಭಿಸಿ.",
            "glucose_avg": "ಗ್ಲೂಕೋಸ್: ಸರಾಸರಿ", "readings": "ರೀಡಿಂಗ್", "normal": "ಸಾಮಾನ್ಯ", "trend": "ಟ್ರೆಂಡ್",
            "improving": "ಸುಧಾರಿಸುತ್ತಿದೆ ↓", "rising": "ಏರುತ್ತಿದೆ ↑", "stable": "ಸ್ಥಿರ →",
            "bp_avg": "ಬಿಪಿ: ಸರಾಸರಿ", "elevated": "ಎತ್ತರ",
            "weight_avg": "ತೂಕ: ಸರಾಸರಿ", "weight_trend": "ಟ್ರೆಂಡ್",
            "decreasing": "ಕಡಿಮೆ ↓", "increasing": "ಹೆಚ್ಚಾಗುತ್ತಿದೆ ↑",
            "diet": "ಆಹಾರ", "meals_logged": "ಊಟ ಲಾಗ್", "heavy_sweet": "ಭಾರ/ಸಿಹಿ",
            "vs_prev": f"ಹಿಂದಿನ {period} ದಿನಕ್ಕೆ ಹೋಲಿಸಿ: ಗ್ಲೂಕೋಸ್", "up": "ಹೆಚ್ಚು", "down": "ಕಡಿಮೆ",
            "period_label": f"{period} ದಿನ", "details": "ವಿವರ", "summary_lbl": "ಸಾರಾಂಶ",
            "keep_tracking": f"ಕಳೆದ {period} ದಿನಗಳಲ್ಲಿ {{count}} ರೀಡಿಂಗ್ ಇದೆ. ಉತ್ತಮ ಒಳನೋಟಕ್ಕಾಗಿ ಟ್ರ್ಯಾಕಿಂಗ್ ಮುಂದುವರಿಸಿ!",
        },
        "te": {
            "no_readings": f"గత {period} రోజుల్లో ఎలాంటి రీడింగ్‌లు నమోదు కాలేదు. ట్రెండ్ చూడటానికి లాగ్ చేయడం ప్రారంభించండి.",
            "glucose_avg": "గ్లూకోజ్: సగటు", "readings": "రీడింగ్‌లు", "normal": "సాధారణ", "trend": "ట్రెండ్",
            "improving": "మెరుగవుతోంది ↓", "rising": "పెరుగుతోంది ↑", "stable": "స్థిరంగా →",
            "bp_avg": "బీపీ: సగటు", "elevated": "పెరిగింది",
            "weight_avg": "బరువు: సగటు", "weight_trend": "ట్రెండ్",
            "decreasing": "తగ్గుతోంది ↓", "increasing": "పెరుగుతోంది ↑",
            "diet": "ఆహారం", "meals_logged": "భోజనాలు నమోదు", "heavy_sweet": "భారీ/తీపి",
            "vs_prev": f"ముందటి {period} రోజులతో పోల్చితే: గ్లూకోజ్", "up": "పెరిగింది", "down": "తగ్గింది",
            "period_label": f"{period} రోజులు", "details": "వివరాలు", "summary_lbl": "సారాంశం",
            "keep_tracking": f"గత {period} రోజుల్లో {{count}} రీడింగ్‌లు ఉన్నాయి. మెరుగైన అంతర్దృష్టి కోసం ట్రాకింగ్ కొనసాగించండి!",
        },
        "ta": {
            "no_readings": f"கடந்த {period} நாட்களில் எந்த அளவீடும் பதிவு செய்யப்படவில்லை. போக்கை காண பதிவு செய்யத் தொடங்குங்கள்.",
            "glucose_avg": "குளுக்கோஸ்: சராசரி", "readings": "அளவீடுகள்", "normal": "சாதாரண", "trend": "போக்கு",
            "improving": "மேம்படுகிறது ↓", "rising": "உயர்கிறது ↑", "stable": "நிலையானது →",
            "bp_avg": "இரத்த அழுத்தம்: சராசரி", "elevated": "உயர்ந்தது",
            "weight_avg": "எடை: சராசரி", "weight_trend": "போக்கு",
            "decreasing": "குறைகிறது ↓", "increasing": "அதிகரிக்கிறது ↑",
            "diet": "உணவு", "meals_logged": "உணவுகள் பதிவு", "heavy_sweet": "கனமான/இனிப்பான",
            "vs_prev": f"கடந்த {period} நாட்களுடன் ஒப்பிட்டால்: குளுக்கோஸ்", "up": "அதிகம்", "down": "குறைவு",
            "period_label": f"{period} நாட்கள்", "details": "விவரங்கள்", "summary_lbl": "சுருக்கம்",
            "keep_tracking": f"கடந்த {period} நாட்களில் {{count}} அளவீடுகள் உள்ளன. சிறந்த நுண்ணறிவுக்கு கண்காணிப்பை தொடருங்கள்!",
        },
    }
    s = _S.get(language, _S["en"])

    if not readings and not base_insight:
        return {"summary": s["no_readings"], "period": period, "cached": False}

    # Glucose stats
    glucose_vals = [r.glucose_value for r in readings if r.reading_type == "glucose" and r.glucose_value]
    data_parts = []
    if glucose_vals:
        avg_g = sum(glucose_vals) / len(glucose_vals)
        mid = len(glucose_vals) // 2
        first_half = sum(glucose_vals[:mid]) / max(mid, 1)
        second_half = sum(glucose_vals[mid:]) / max(len(glucose_vals) - mid, 1)
        if second_half < first_half * 0.95:
            trend = s["improving"]
        elif second_half > first_half * 1.05:
            trend = s["rising"]
        else:
            trend = s["stable"]
        normal_pct = sum(1 for v in glucose_vals if 70 <= v <= 130) * 100 // len(glucose_vals)
        data_parts.append(
            f"{s['glucose_avg']} {avg_g:.0f} mg/dL ({len(glucose_vals)} {s['readings']}), "
            f"{min(glucose_vals):.0f}–{max(glucose_vals):.0f}, "
            f"{normal_pct}% {s['normal']}, {s['trend']} {trend}"
        )

    # BP stats
    bp_readings = [(r.systolic, r.diastolic) for r in readings if r.reading_type == "blood_pressure" and r.systolic and r.diastolic]
    if bp_readings:
        avg_sys = sum(sys for sys, _ in bp_readings) / len(bp_readings)
        avg_dia = sum(dia for _, dia in bp_readings) / len(bp_readings)
        elevated = sum(1 for sys, dia in bp_readings if sys >= 130 or dia >= 80)
        data_parts.append(
            f"{s['bp_avg']} {avg_sys:.0f}/{avg_dia:.0f} mmHg ({len(bp_readings)} {s['readings']}), "
            f"{elevated} {s['elevated']}"
        )

    # Weight stats
    weight_vals = [r.weight_value for r in readings if r.reading_type == "weight" and r.weight_value]
    if weight_vals:
        avg_w = sum(weight_vals) / len(weight_vals)
        mid = len(weight_vals) // 2
        first_half = sum(weight_vals[:mid]) / max(mid, 1)
        second_half = sum(weight_vals[mid:]) / max(len(weight_vals) - mid, 1)
        if second_half < first_half - 0.5:
            trend = s["decreasing"]
        elif second_half > first_half + 0.5:
            trend = s["increasing"]
        else:
            trend = s["stable"]
        data_parts.append(
            f"{s['weight_avg']} {avg_w:.1f} kg ({len(weight_vals)} {s['readings']}), "
            f"{min(weight_vals):.1f}–{max(weight_vals):.1f}, "
            f"{s['weight_trend']} {trend}"
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
            f"{s['diet']}: {len(period_meals)} {s['meals_logged']}, "
            f"{heavy} {s['heavy_sweet']}"
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
            direction = s["up"] if diff > 0 else s["down"]
            comparison = f"{s['vs_prev']} {direction} {abs(diff):.0f} mg/dL"

    # ── 3. Assemble layered summary ────────────────────────────────────────
    period_label = s["period_label"]
    data_line = ". ".join(data_parts)
    if comparison:
        data_line += f". {comparison}"

    if base_insight:
        summary = f"{base_insight}\n\n{period_label} {s['details']}: {data_line}." if data_line else base_insight
    elif data_line:
        summary = f"{period_label} {s['summary_lbl']}: {data_line}."
    else:
        summary = s["keep_tracking"].format(count=len(readings))

    # ── Cache (English only — non-English always gets fresh data) ────────────────────
    if language == "en":
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

    # Log trend summary for debugging
    logger.info(f"\n{'='*80}\n🟣 BACKEND {period}-DAY TREND SUMMARY:\n{'='*80}\n{summary}\n{'='*80}\n")
    
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
            models.HealthReading.reading_timestamp >= datetime.combine(today - timedelta(days=60), datetime.min.time(), tzinfo=timezone.utc),
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


@router.put("/readings/{reading_id}", response_model=schemas.HealthReadingResponse)
@limiter.limit("30/minute")
def update_reading(
    request: Request,
    reading_id: int,
    payload: schemas.HealthReadingUpdate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """Edit an existing reading.

    - `reading_type` is immutable. Glucose/BP/weight fields are honored
      only when relevant to the stored type.
    - Server recomputes `status_flag`, `value_numeric`, `unit_display`,
      and re-encrypts encrypted columns.
    - Weight edits re-sync `Profile.weight` to the **newest** weight
      reading after the update — editing an older weight must NOT
      overwrite the latest.
    - Invalidates AI insight + trend caches (same as create) so AI
      evaluation reflects the corrected value on next load.
    - Does NOT re-dispatch critical alerts on edit (avoid spam).
    """
    db_reading = db.query(models.HealthReading).filter(
        models.HealthReading.id == reading_id
    ).first()
    if not db_reading:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reading not found")

    get_profile_editor_or_403(db_reading.profile_id, user, db)

    rtype = db_reading.reading_type
    data = payload.dict(exclude_unset=True)

    if rtype == "glucose":
        if "glucose_value" in data and data["glucose_value"] is not None:
            v = float(data["glucose_value"])
            db_reading.glucose_value = v
            db_reading.glucose_value_enc = encrypt_float(v)
            db_reading.value_numeric = v
            db_reading.status_flag = classify_glucose(v)
        if "glucose_unit" in data and data["glucose_unit"]:
            db_reading.glucose_unit = data["glucose_unit"]
            db_reading.unit_display = data["glucose_unit"]
        if "sample_type" in data:
            db_reading.sample_type = data["sample_type"]
        if "meal_context" in data:
            # Schema validation has already restricted to the enum.
            db_reading.meal_context = data["meal_context"]

    elif rtype == "blood_pressure":
        sys_v = data.get("systolic", db_reading.systolic) if "systolic" in data else db_reading.systolic
        dia_v = data.get("diastolic", db_reading.diastolic) if "diastolic" in data else db_reading.diastolic
        if "systolic" in data and data["systolic"] is not None:
            db_reading.systolic = float(data["systolic"])
            db_reading.systolic_enc = encrypt_float(float(data["systolic"]))
            sys_v = float(data["systolic"])
        if "diastolic" in data and data["diastolic"] is not None:
            db_reading.diastolic = float(data["diastolic"])
            db_reading.diastolic_enc = encrypt_float(float(data["diastolic"]))
            dia_v = float(data["diastolic"])
        if "pulse_rate" in data and data["pulse_rate"] is not None:
            db_reading.pulse_rate = float(data["pulse_rate"])
            db_reading.pulse_rate_enc = encrypt_float(float(data["pulse_rate"]))
        if "bp_unit" in data and data["bp_unit"]:
            db_reading.bp_unit = data["bp_unit"]
            db_reading.unit_display = data["bp_unit"]
        if sys_v is not None and dia_v is not None:
            db_reading.status_flag = classify_bp(float(sys_v), float(dia_v))
            db_reading.value_numeric = float(sys_v)

    elif rtype == "weight":
        if "weight_value" in data and data["weight_value"] is not None:
            v = float(data["weight_value"])
            db_reading.weight_value = v
            db_reading.weight_value_enc = encrypt_float(v)
            db_reading.value_numeric = v
            db_reading.status_flag = "NORMAL"
        if "weight_unit" in data and data["weight_unit"]:
            db_reading.weight_unit = data["weight_unit"]
            db_reading.unit_display = data["weight_unit"]

    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Edit not supported for reading_type '{rtype}'",
        )

    if "notes" in data:
        db_reading.notes = data["notes"]
        db_reading.notes_enc = encrypt(data["notes"]) if data["notes"] is not None else None

    if "reading_timestamp" in data and data["reading_timestamp"] is not None:
        db_reading.reading_timestamp = data["reading_timestamp"]

    db.add(db_reading)
    db.flush()

    # Re-sync Profile.weight to the NEWEST weight reading. Editing an
    # older weight reading must not clobber the latest one.
    if rtype == "weight":
        latest_weight = db.query(models.HealthReading).filter(
            models.HealthReading.profile_id == db_reading.profile_id,
            models.HealthReading.reading_type == "weight",
            models.HealthReading.weight_value.isnot(None),
        ).order_by(models.HealthReading.reading_timestamp.desc()).first()
        if latest_weight is not None:
            profile = db.query(models.Profile).filter(
                models.Profile.id == db_reading.profile_id
            ).first()
            if profile is not None:
                profile.weight = latest_weight.weight_value

    db.commit()
    db.refresh(db_reading)

    # Mirror create-flow cache invalidation so AI re-evaluates with the
    # corrected reading. Three caches:
    #   1. _insight_cache (in-memory, per-day Gemini cache)
    #   2. TrendSummaryCache (DB, used by Insights tab)
    #   3. AiInsightLog "smart cache" — the dashboard ai-insight endpoint
    #      compares latest_insight.created_at vs latest_reading.reading_timestamp.
    #      Editing a reading does NOT change its timestamp, so without
    #      explicit invalidation the dashboard would keep returning the
    #      stale cached insight. We mark recent rows as 'invalidated' so
    #      they're skipped by the cache lookup but kept for audit.
    stale = [k for k in _insight_cache if k[0] == db_reading.profile_id]
    for k in stale:
        del _insight_cache[k]
    try:
        db.query(models.TrendSummaryCache).filter(
            models.TrendSummaryCache.profile_id == db_reading.profile_id
        ).delete()
        db.query(models.AiInsightLog).filter(
            models.AiInsightLog.profile_id == db_reading.profile_id,
            models.AiInsightLog.model_used != "invalidated",
        ).update({"model_used": "invalidated"})
        db.commit()
    except Exception:
        logger.warning(
            "Insight cache invalidation failed for profile %s",
            db_reading.profile_id,
            exc_info=True,
        )
        db.rollback()

    _refresh_doctor_triage_for_profile(db, db_reading.profile_id)

    return db_reading


@router.delete("/readings/{reading_id}", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit("30/minute")
def delete_reading(
    request: Request,
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

    profile_id = db_reading.profile_id
    was_weight = db_reading.reading_type == "weight"

    # ── Stage 1: commit the delete + weight resync as ONE atomic unit ──
    # Cache invalidation MUST run in its own transactional boundary —
    # if cache work fails and we rollback within the same transaction,
    # the deletion gets reverted too and we'd return 204 while the row
    # still exists in the DB.
    db.delete(db_reading)

    if was_weight:
        latest_weight = db.query(models.HealthReading).filter(
            models.HealthReading.profile_id == profile_id,
            models.HealthReading.reading_type == "weight",
            models.HealthReading.weight_value.isnot(None),
            models.HealthReading.id != reading_id,
        ).order_by(models.HealthReading.reading_timestamp.desc()).first()
        profile = db.query(models.Profile).filter(
            models.Profile.id == profile_id
        ).first()
        if profile is not None:
            profile.weight = latest_weight.weight_value if latest_weight else None

    db.commit()

    # ── Stage 2: cache invalidation in a fresh transaction ─────────────
    # Failures here must NOT undo the delete. _insight_cache is
    # in-memory so it's free to clear unconditionally.
    stale = [k for k in _insight_cache if k[0] == profile_id]
    for k in stale:
        del _insight_cache[k]
    try:
        db.query(models.TrendSummaryCache).filter(
            models.TrendSummaryCache.profile_id == profile_id
        ).delete()
        db.query(models.AiInsightLog).filter(
            models.AiInsightLog.profile_id == profile_id,
            models.AiInsightLog.model_used != "invalidated",
        ).update({"model_used": "invalidated"})
        db.commit()
    except Exception:
        logger.warning(
            "Insight cache invalidation failed for profile %s",
            profile_id,
            exc_info=True,
        )
        db.rollback()  # safe — only rolls back the cache work, delete is already committed

    _refresh_doctor_triage_for_profile(db, profile_id)

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
            # Gemini sometimes returns pulse under different key names
            pulse = (
                parsed.get("pulse")
                or parsed.get("pulse_rate")
                or parsed.get("heart_rate")
                or parsed.get("hr")
            )
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


def _rule_based_insight(recent: list, db: Session, total_count: int = 0, language: str = "en") -> str:
    """Simple rule-based fallback used when Gemini is unavailable.

    Health-safety critical: every branch must return in the caller's
    language. Telugu/Tamil patients receiving a CRITICAL alert in
    English is a known regression mode — every key in `_T` must cover
    all 5 supported languages.
    """
    language = language if language in _SUPPORTED_LANGS else "en"

    _T = {
        "welcome_back": {
            "en": "Welcome back! You have {n} readings on file. Log today's reading to get fresh insights.",
            "hi": "वापसी पर स्वागत है! आपके पास {n} रीडिंग हैं। नए सुझाव पाने के लिए आज की रीडिंग दर्ज करें।",
            "kn": "ಮರಳಿ ಸ್ವಾಗತ! ನಿಮ್ಮ ಬಳಿ {n} ರೀಡಿಂಗ್‌ಗಳಿವೆ. ಹೊಸ ಒಳನೋಟಗಳನ್ನು ಪಡೆಯಲು ಇಂದಿನ ರೀಡಿಂಗ್ ದಾಖಲಿಸಿ.",
            "te": "తిరిగి స్వాగతం! మీకు {n} రీడింగ్‌లు ఉన్నాయి. తాజా అంతర్దృష్టుల కోసం నేటి రీడింగ్‌ను నమోదు చేయండి.",
            "ta": "மீண்டும் வரவேற்கிறோம்! உங்களிடம் {n} அளவீடுகள் உள்ளன. புதிய பார்வைகளுக்கு இன்றைய அளவீட்டைப் பதிவு செய்யுங்கள்.",
        },
        "log_first": {
            "en": "Log your first reading to start tracking your health.",
            "hi": "अपनी पहली रीडिंग दर्ज करके अपने स्वास्थ्य पर नज़र रखना शुरू करें।",
            "kn": "ನಿಮ್ಮ ಆರೋಗ್ಯವನ್ನು ಟ್ರ್ಯಾಕ್ ಮಾಡಲು ನಿಮ್ಮ ಮೊದಲ ರೀಡಿಂಗ್ ದಾಖಲಿಸಿ.",
            "te": "మీ ఆరోగ్యాన్ని ట్రాక్ చేయడం ప్రారంభించడానికి మీ మొదటి రీడింగ్‌ను నమోదు చేయండి.",
            "ta": "உங்கள் உடல்நலத்தைக் கண்காணிக்க உங்கள் முதல் அளவீட்டைப் பதிவு செய்யுங்கள்.",
        },
        "critical": {
            "en": "⚠️ A recent reading was critical. Please seek medical attention immediately.",
            "hi": "⚠️ एक हालिया रीडिंग गंभीर थी। कृपया तुरंत डॉक्टर से मिलें।",
            "kn": "⚠️ ಇತ್ತೀಚಿನ ಒಂದು ರೀಡಿಂಗ್ ಗಂಭೀರವಾಗಿತ್ತು. ದಯವಿಟ್ಟು ತಕ್ಷಣ ವೈದ್ಯರನ್ನು ಸಂಪರ್ಕಿಸಿ.",
            "te": "⚠️ ఇటీవలి రీడింగ్ ప్రమాదకరంగా ఉంది. దయచేసి వెంటనే వైద్య సహాయం పొందండి.",
            "ta": "⚠️ சமீபத்திய அளவீடு ஆபத்தானது. உடனடியாக மருத்துவ உதவியை நாடுங்கள்.",
        },
        "stage2_bp": {
            "en": "⚠️ Your BP ({sys:.0f}/{dia:.0f}) is dangerously high. Have you taken your medication? Please see a doctor today.",
            "hi": "⚠️ आपका बीपी ({sys:.0f}/{dia:.0f}) बहुत अधिक है। क्या आपने दवा ली है? कृपया आज ही डॉक्टर से मिलें।",
            "kn": "⚠️ ನಿಮ್ಮ ರಕ್ತದೊತ್ತಡ ({sys:.0f}/{dia:.0f}) ಅಪಾಯಕಾರಿಯಾಗಿ ಹೆಚ್ಚಾಗಿದೆ. ನೀವು ಔಷಧಿ ತೆಗೆದುಕೊಂಡಿದ್ದೀರಾ? ದಯವಿಟ್ಟು ಇಂದೇ ವೈದ್ಯರನ್ನು ಭೇಟಿ ಮಾಡಿ.",
            "te": "⚠️ మీ రక్తపోటు ({sys:.0f}/{dia:.0f}) ప్రమాదకరంగా ఎక్కువగా ఉంది. మీరు మందులు తీసుకున్నారా? దయచేసి ఈరోజే వైద్యుడిని కలవండి.",
            "ta": "⚠️ உங்கள் இரத்த அழுத்தம் ({sys:.0f}/{dia:.0f}) ஆபத்தான அளவில் உள்ளது. மருந்து உட்கொண்டீர்களா? இன்றே மருத்துவரைச் சந்திக்கவும்.",
        },
        "stage2_generic": {
            "en": "⚠️ A reading is in Stage 2 range. Have you taken your medication? Please consult your doctor.",
            "hi": "⚠️ एक रीडिंग स्टेज 2 के स्तर पर है। क्या आपने दवा ली है? कृपया डॉक्टर से सलाह लें।",
            "kn": "⚠️ ಒಂದು ರೀಡಿಂಗ್ ಹಂತ 2 ರಲ್ಲಿದೆ. ನೀವು ಔಷಧಿ ತೆಗೆದುಕೊಂಡಿದ್ದೀರಾ? ದಯವಿಟ್ಟು ನಿಮ್ಮ ವೈದ್ಯರನ್ನು ಸಂಪರ್ಕಿಸಿ.",
            "te": "⚠️ ఒక రీడింగ్ స్టేజ్ 2 పరిధిలో ఉంది. మీరు మందులు తీసుకున్నారా? దయచేసి మీ వైద్యుడిని సంప్రదించండి.",
            "ta": "⚠️ ஒரு அளவீடு நிலை 2 வரம்பில் உள்ளது. மருந்து உட்கொண்டீர்களா? உங்கள் மருத்துவரை அணுகவும்.",
        },
        "bmi_high_with_elev": {
            "en": "Some readings are elevated, and your BMI is {bmi:.1f}. Focus on diet and movement.",
            "hi": "कुछ रीडिंग अधिक हैं, और आपका BMI {bmi:.1f} है। आहार और व्यायाम पर ध्यान दें।",
            "kn": "ಕೆಲವು ರೀಡಿಂಗ್‌ಗಳು ಹೆಚ್ಚಾಗಿವೆ, ಮತ್ತು ನಿಮ್ಮ BMI {bmi:.1f} ಆಗಿದೆ. ಆಹಾರ ಮತ್ತು ವ್ಯಾಯಾಮದ ಬಗ್ಗೆ ಗಮನಹರಿಸಿ.",
            "te": "కొన్ని రీడింగ్‌లు ఎక్కువగా ఉన్నాయి, మరియు మీ BMI {bmi:.1f}. ఆహారం మరియు వ్యాయామంపై దృష్టి పెట్టండి.",
            "ta": "சில அளவீடுகள் அதிகமாக உள்ளன, உங்கள் BMI {bmi:.1f}. உணவு மற்றும் உடற்பயிற்சியில் கவனம் செலுத்துங்கள்.",
        },
        "bmi_overweight": {
            "en": "Your BMI is {bmi:.1f} (Overweight). Try reducing carbs and aim for daily activity.",
            "hi": "आपका BMI {bmi:.1f} (अधिक वजन) है। कार्ब्स कम करें और रोज़ व्यायाम करें।",
            "kn": "ನಿಮ್ಮ BMI {bmi:.1f} (ಹೆಚ್ಚು ತೂಕ) ಆಗಿದೆ. ಕಾರ್ಬ್ಸ್ ಕಡಿಮೆ ಮಾಡಿ ಮತ್ತು ದೈನಂದಿನ ವ್ಯಾಯಾಮವನ್ನು ಗುರಿಯಾಗಿಸಿ.",
            "te": "మీ BMI {bmi:.1f} (అధిక బరువు). కార్బ్‌లను తగ్గించి, రోజువారీ వ్యాయామాన్ని లక్ష్యంగా చేసుకోండి.",
            "ta": "உங்கள் BMI {bmi:.1f} (அதிக எடை). கார்போஹைட்ரேட்டைக் குறைத்து, தினசரி உடற்பயிற்சியில் ஈடுபடுங்கள்.",
        },
        "bmi_underweight": {
            "en": "Your BMI is {bmi:.1f} (Underweight). Ensure you are getting enough nutrition.",
            "hi": "आपका BMI {bmi:.1f} (कम वजन) है। सुनिश्चित करें कि आप पर्याप्त पोषण ले रहे हैं।",
            "kn": "ನಿಮ್ಮ BMI {bmi:.1f} (ಕಡಿಮೆ ತೂಕ) ಆಗಿದೆ. ಸಾಕಷ್ಟು ಪೌಷ್ಟಿಕಾಂಶ ಸಿಗುತ್ತಿದೆ ಎಂದು ಖಚಿತಪಡಿಸಿಕೊಳ್ಳಿ.",
            "te": "మీ BMI {bmi:.1f} (తక్కువ బరువు). మీరు తగినంత పోషణ పొందుతున్నారని నిర్ధారించుకోండి.",
            "ta": "உங்கள் BMI {bmi:.1f} (எடை குறைவு). போதுமான ஊட்டச்சத்து கிடைப்பதை உறுதிசெய்யுங்கள்.",
        },
        "high_general": {
            "en": "Some readings were elevated this week. Stay hydrated and keep active.",
            "hi": "इस सप्ताह कुछ रीडिंग अधिक थीं। पानी पीते रहें और सक्रिय रहें।",
            "kn": "ಈ ವಾರ ಕೆಲವು ರೀಡಿಂಗ್‌ಗಳು ಹೆಚ್ಚಾಗಿದ್ದವು. ನೀರು ಕುಡಿಯಿರಿ ಮತ್ತು ಸಕ್ರಿಯರಾಗಿರಿ.",
            "te": "ఈ వారం కొన్ని రీడింగ్‌లు ఎక్కువగా ఉన్నాయి. తగినంత నీరు తాగండి మరియు చురుకుగా ఉండండి.",
            "ta": "இந்த வாரம் சில அளவீடுகள் அதிகமாக இருந்தன. நீர்ச்சத்துடன் சுறுசுறுப்பாக இருங்கள்.",
        },
        "all_normal": {
            "en": "All recent readings look healthy. Keep up the great work!",
            "hi": "सभी हालिया रीडिंग सामान्य लग रही हैं। बहुत बढ़िया!",
            "kn": "ಎಲ್ಲಾ ಇತ್ತೀಚಿನ ರೀಡಿಂಗ್‌ಗಳು ಆರೋಗ್ಯಕರವಾಗಿವೆ. ಹೀಗೆಯೇ ಮುಂದುವರಿಸಿ!",
            "te": "ఇటీవలి అన్ని రీడింగ్‌లు ఆరోగ్యకరంగా కనిపిస్తున్నాయి. మంచి పనిని కొనసాగించండి!",
            "ta": "சமீபத்திய அனைத்து அளவீடுகளும் ஆரோக்கியமாக உள்ளன. சிறப்பான வேலையைத் தொடருங்கள்!",
        },
        "default": {
            "en": "Readings logged. Keep tracking daily for better health insights.",
            "hi": "रीडिंग दर्ज की गई। बेहतर सुझावों के लिए रोज़ाना ट्रैक करें।",
            "kn": "ರೀಡಿಂಗ್ ದಾಖಲಿಸಲಾಗಿದೆ. ಉತ್ತಮ ಒಳನೋಟಗಳಿಗಾಗಿ ಪ್ರತಿದಿನ ಟ್ರ್ಯಾಕ್ ಮಾಡಿ.",
            "te": "రీడింగ్‌లు నమోదు చేయబడ్డాయి. మెరుగైన అంతర్దృష్టుల కోసం ప్రతిరోజూ ట్రాక్ చేయండి.",
            "ta": "அளவீடுகள் பதிவு செய்யப்பட்டன. சிறந்த உடல்நல பார்வைகளுக்கு தினமும் கண்காணியுங்கள்.",
        },
    }

    def t(key: str, **kwargs) -> str:
        return _T[key][language].format(**kwargs)

    if not recent:
        if total_count > 0:
            return t("welcome_back", n=total_count)
        return t("log_first")

    statuses = {r.status_flag for r in recent if r.status_flag}
    if "CRITICAL" in statuses:
        return t("critical")

    if "HIGH - STAGE 2" in statuses:
        stage2 = next((r for r in reversed(recent) if r.status_flag == "HIGH - STAGE 2"), None)
        if stage2 and stage2.reading_type == "blood_pressure" and stage2.systolic:
            return t("stage2_bp", sys=stage2.systolic, dia=stage2.diastolic)
        return t("stage2_generic")

    # Weight specific tips (check this BEFORE general NORMAL status)
    weight_readings = [r for r in recent if r.reading_type == "weight" and r.weight_value]
    if weight_readings:
        latest_w = weight_readings[-1].weight_value
        profile = db.query(models.Profile).filter(models.Profile.id == weight_readings[-1].profile_id).first()
        if profile and profile.height:
            bmi = latest_w / ((profile.height / 100) ** 2)
            if bmi >= 25:
                if any("HIGH" in (s or "") for s in statuses):
                    return t("bmi_high_with_elev", bmi=bmi)
                return t("bmi_overweight", bmi=bmi)
            if bmi < 18.5:
                return t("bmi_underweight", bmi=bmi)

    if any("HIGH" in (s or "") for s in statuses):
        return t("high_general")

    if statuses and all(s == "NORMAL" for s in statuses):
        return t("all_normal")

    return t("default")


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
