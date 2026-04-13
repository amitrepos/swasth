"""
Dedicated service for generating AI evaluations specifically for the Weekly WhatsApp Report.
Decoupled from dashboard logic to ensure ZERO impact on dashboard caching/display.
"""
from datetime import datetime, timedelta, date
from sqlalchemy.orm import Session
from sqlalchemy import func
import models
import ai_service
from health_utils import classify_glucose, classify_bp

def get_weekly_ai_insight(db: Session, profile_id: int, user: models.User) -> str:
    """
    Analyzes 7 days of health data and generates a weekly AI evaluation.
    Falls back to rule-based insight if consent is missing or AI fails.
    """
    # ── 1. Consent Check ───────────────────────────────────────────────
    if not user.ai_consent:
        return _get_weekly_rule_based_fallback(db, profile_id)

    # ── 2. Gather 7-day Data ───────────────────────────────────────────
    today = date.today()
    period_start = datetime.combine(today - timedelta(days=6), datetime.min.time())
    
    profile = db.query(models.Profile).filter(models.Profile.id == profile_id).first()
    readings = (
        db.query(models.HealthReading)
        .filter(
            models.HealthReading.profile_id == profile_id,
            models.HealthReading.reading_timestamp >= period_start,
        )
        .all()
    )

    glucose_vals = [r.glucose_value for r in readings if r.reading_type == "glucose" and r.glucose_value]
    bp_readings = [(r.systolic, r.diastolic) for r in readings if r.reading_type == "blood_pressure" and r.systolic and r.diastolic]

    if not glucose_vals and not bp_readings:
        return "Not enough readings logged this week for an AI evaluation."

    # ── 3. Build Stats Summary for prompt ─────────────────────────────
    summary_parts = []
    if glucose_vals:
        avg_g = sum(glucose_vals) / len(glucose_vals)
        summary_parts.append(f"Glucose: avg {avg_g:.0f} mg/dL over {len(glucose_vals)} readings")
    if bp_readings:
        avg_sys = sum(s for s, _ in bp_readings) / len(bp_readings)
        avg_dia = sum(d for _, d in bp_readings) / len(bp_readings)
        summary_parts.append(f"BP: avg {avg_sys:.0f}/{avg_dia:.0f} mmHg over {len(bp_readings)} readings")

    prompt_summary = ". ".join(summary_parts)
    
    # ── 4. Generate AI Insight ───────────────────────────────────────
    age = profile.age if (profile and profile.age) else "unknown"
    conditions = ", ".join(profile.medical_conditions) if (profile and profile.medical_conditions) else "None"
    
    prompt = f"""Patient Age: {age}, Conditions: {conditions}. 
    Weekly Data Summary: {prompt_summary}.
    
    Tasks:
    1. Summarize their health trend for the last 7 days.
    2. Provide one actionable medical tip for the coming week.
    
    Constraint: Exactly 2 short sentences. No greetings. Max 40 words."""

    insight = ai_service.generate_health_insight(prompt, profile_id, db, f"WEEKLY_REPORT: {prompt_summary}")
    
    if insight:
        return insight

    # ── 5. Final Fallback (AI Failed) ────────────────────────────────
    return _get_weekly_rule_based_fallback(db, profile_id)

def _get_weekly_rule_based_fallback(db: Session, profile_id: int) -> str:
    """Deterministic logic for users without AI consent or on service failure."""
    today = date.today()
    period_start = datetime.combine(today - timedelta(days=6), datetime.min.time())
    
    recent = (
        db.query(models.HealthReading)
        .filter(
            models.HealthReading.profile_id == profile_id,
            models.HealthReading.reading_timestamp >= period_start,
        )
        .all()
    )
    
    if not recent:
        return "Keep tracking your sugar and BP daily to receive weekly medical evaluations."

    criticals = [r for r in recent if r.status_flag == "CRITICAL"]
    if criticals:
        return "⚠️ Multiple readings were critical this week. Please prioritize a doctor visit to review your medication."
    
    highs = [r for r in recent if "HIGH" in (r.status_flag or "")]
    if highs:
        return "Some readings were elevated this week. Consider reducing salt intake and increasing water consumption."
        
    return "All readings were normal this week. Maintain your current diet and exercise routine!"
