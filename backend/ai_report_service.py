"""
Dedicated service for generating AI evaluations specifically for the Weekly WhatsApp Report.
Decoupled from dashboard logic to ensure ZERO impact on dashboard caching/display.
"""
from datetime import datetime, timedelta, date, timezone
from sqlalchemy.orm import Session
import models
import ai_service
from health_utils import classify_glucose, classify_bp


def get_weekly_ai_insight(db: Session, profile_id: int, user: models.User) -> str:
    """
    Analyzes 7 days of health data and generates a weekly AI evaluation.
    Falls back to rule-based insight if consent is missing or AI fails.
    """
    if not user.ai_consent:
        return _get_weekly_rule_based_fallback(db, profile_id)

    # UTC-aware cutoff — matches how readings are stored
    period_start = datetime.now(timezone.utc) - timedelta(days=7)

    profile = db.query(models.Profile).filter(models.Profile.id == profile_id).first()
    readings = (
        db.query(models.HealthReading)
        .filter(
            models.HealthReading.profile_id == profile_id,
            models.HealthReading.reading_timestamp >= period_start,
        )
        .order_by(models.HealthReading.reading_timestamp.asc())
        .all()
    )

    glucose_readings = [r for r in readings if r.reading_type == "glucose" and r.glucose_value]
    bp_readings = [r for r in readings if r.reading_type == "blood_pressure" and r.systolic and r.diastolic]
    weight_readings = [r for r in readings if r.reading_type == "weight" and r.weight_value]

    if not glucose_readings and not bp_readings and not weight_readings:
        return "Not enough readings logged this week for an AI evaluation."

    summary_parts = []

    if glucose_readings:
        vals = [r.glucose_value for r in glucose_readings]
        avg_g = sum(vals) / len(vals)
        # Trend: compare first-half avg vs second-half avg
        mid = len(vals) // 2
        trend = ""
        if mid > 0:
            first_avg = sum(vals[:mid]) / mid
            second_avg = sum(vals[mid:]) / (len(vals) - mid)
            if second_avg > first_avg + 10:
                trend = ", trending UP"
            elif second_avg < first_avg - 10:
                trend = ", trending DOWN"
        criticals = sum(1 for r in glucose_readings if classify_glucose(r.glucose_value) in ("HIGH", "VERY_HIGH", "CRITICAL"))
        summary_parts.append(
            f"Glucose: avg {avg_g:.0f} mg/dL, min {min(vals):.0f}, max {max(vals):.0f}{trend}"
            f" over {len(vals)} readings ({criticals} high/critical)"
        )

    if bp_readings:
        sys_vals = [r.systolic for r in bp_readings]
        dia_vals = [r.diastolic for r in bp_readings]
        avg_sys = sum(sys_vals) / len(sys_vals)
        avg_dia = sum(dia_vals) / len(dia_vals)
        mid = len(sys_vals) // 2
        trend = ""
        if mid > 0:
            first_avg = sum(sys_vals[:mid]) / mid
            second_avg = sum(sys_vals[mid:]) / (len(sys_vals) - mid)
            if second_avg > first_avg + 5:
                trend = ", trending UP"
            elif second_avg < first_avg - 5:
                trend = ", trending DOWN"
        criticals = sum(1 for r in bp_readings if classify_bp(r.systolic, r.diastolic) in ("HIGH", "VERY_HIGH", "CRITICAL", "HYPERTENSIVE_CRISIS"))
        summary_parts.append(
            f"BP: avg {avg_sys:.0f}/{avg_dia:.0f} mmHg{trend}"
            f" over {len(bp_readings)} readings ({criticals} high/critical)"
        )

    if weight_readings:
        w_vals = [r.weight_value for r in weight_readings]
        summary_parts.append(
            f"Weight: latest {w_vals[-1]:.1f} kg"
            + (f", changed {w_vals[-1] - w_vals[0]:+.1f} kg this week" if len(w_vals) > 1 else "")
        )

    prompt_summary = ". ".join(summary_parts)

    age = profile.age if (profile and profile.age) else "unknown"
    conditions = ", ".join(profile.medical_conditions) if (profile and profile.medical_conditions) else "None"

    prompt = (
        f"Patient: Age {age}, Conditions: {conditions}.\n"
        f"7-day health data: {prompt_summary}.\n\n"
        f"Tasks:\n"
        f"1. In one sentence, describe the week's trend (improving/stable/worsening) with the most important number.\n"
        f"2. In one sentence, give the single most important actionable tip for next week based on their conditions and data.\n\n"
        f"Constraints: Exactly 2 sentences. No greetings. Max 45 words total. Be specific, not generic."
    )

    insight = ai_service.generate_health_insight(prompt, profile_id, db, f"WEEKLY_REPORT: {prompt_summary}")
    return insight if insight else _get_weekly_rule_based_fallback(db, profile_id)


def _get_weekly_rule_based_fallback(db: Session, profile_id: int) -> str:
    """Deterministic fallback for users without AI consent or when AI fails."""
    period_start = datetime.now(timezone.utc) - timedelta(days=7)

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
