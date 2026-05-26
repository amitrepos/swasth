import logging
import re
from datetime import datetime, timedelta, date, timezone
from typing import Optional
from sqlalchemy.orm import Session
from database import SessionLocal
from sqlalchemy import func
from models import (
    User, Profile, HealthReading, ProfileAccess,
    ReportGenerationLog, WhatsAppMessageLog,
    ReportTriggerType, WhatsAppMessageStatus, ReportGenerationStatus,
    DoctorPatientLink, DoctorReportGenerationLog, DoctorProfile
)
from health_utils import classify_bp, classify_glucose, classify_spo2
from utils.phone import normalize_phone
from utils.datetime_helpers import ensure_utc
from twilio_service import whatsapp_service
from config import settings
import ai_report_service

logger = logging.getLogger(__name__)


def build_doctor_summary(db: Session, doctor_id: int, last_7d: datetime) -> dict:
    """Builds an aggregate summary of all active patients for a doctor.

    Returns:
        {
            "patients": [{
                "name": str,
                "metrics": {
                    "glucose": {avg, min, max, count},
                    "bp": {avg_sys, avg_dia, count},
                    "spo2": {avg, min, max, count},
                    "steps": {total}
                },
                "critical_metrics": [str],  # e.g. ["BP", "Glucose"]
            }],
            "critical_patients": [str],     # Names of patients with critical readings
            "patients_with_data_count": int,
            "total_patients_count": int
        }
    """
    links = db.query(DoctorPatientLink).filter(
        DoctorPatientLink.doctor_id == doctor_id,
        DoctorPatientLink.status == 'active'
    ).all()

    summary = {
        "patients": [],
        "critical_patients": [],
        "patients_with_data_count": 0,
        "total_patients_count": len(links)
    }

    for link in links:
        profile = db.query(Profile).filter(Profile.id == link.profile_id).first()
        if not profile:
            continue

        readings = db.query(HealthReading).filter(
            HealthReading.profile_id == profile.id,
            HealthReading.reading_timestamp >= last_7d
        ).all()

        if not readings:
            continue

        summary["patients_with_data_count"] += 1
        p_summary = {
            "name": profile.name,
            "metrics": {},
            "critical_metrics": []
        }

        # Aggregate Glucose
        g_readings = [r for r in readings if r.reading_type == 'glucose' and r.glucose_value]
        if g_readings:
            g_vals = [r.glucose_value for r in g_readings]
            p_summary["metrics"]["glucose"] = {
                "avg": sum(g_vals) / len(g_vals),
                "min": min(g_vals),
                "max": max(g_vals),
                "count": len(g_vals)
            }
            if any(classify_glucose(v) == "CRITICAL" for v in g_vals):
                p_summary["critical_metrics"].append("Sugar")

        # Aggregate BP
        bp_readings = [r for r in readings if r.reading_type == 'blood_pressure' and r.systolic and r.diastolic]
        if bp_readings:
            sys_vals = [r.systolic for r in bp_readings]
            dia_vals = [r.diastolic for r in bp_readings]
            p_summary["metrics"]["bp"] = {
                "avg_sys": sum(sys_vals) / len(sys_vals),
                "avg_dia": sum(dia_vals) / len(dia_vals),
                "count": len(bp_readings)
            }
            if any(classify_bp(s, d) == "HIGH - STAGE 2" for s, d in zip(sys_vals, dia_vals)):
                p_summary["critical_metrics"].append("BP")

        # Aggregate SpO2
        s_readings = [r for r in readings if r.reading_type == 'spo2' and r.spo2_value]
        if s_readings:
            s_vals = [r.spo2_value for r in s_readings]
            p_summary["metrics"]["spo2"] = {
                "avg": sum(s_vals) / len(s_vals),
                "min": min(s_vals),
                "max": max(s_vals),
                "count": len(s_vals)
            }
            if any(classify_spo2(v) == "CRITICAL" for v in s_vals):
                p_summary["critical_metrics"].append("SpO2")

        # Aggregate Steps
        steps_readings = [r for r in readings if r.reading_type == 'steps' and r.steps_count]
        if steps_readings:
            p_summary["metrics"]["steps"] = {
                "total": sum(r.steps_count for r in steps_readings)
            }

        if p_summary["critical_metrics"]:
            summary["critical_patients"].append(profile.name)

        summary["patients"].append(p_summary)

    return summary


def send_doctor_weekly_reports(
    db: Optional[Session] = None,
    trigger_type: ReportTriggerType = ReportTriggerType.SCHEDULED,
    doctor_user_id: Optional[int] = None,
) -> dict:
    """Sends a weekly digest report to doctors for all their linked patients."""
    managed_session = False
    if db is None:
        db = SessionLocal()
        managed_session = True

    results = {"total_doctors": 0, "successful_deliveries": 0, "failed_deliveries": 0, "errors": []}

    try:
        if not settings.TWILIO_DOCTOR_REPORT_CONTENT_SID:
            raise ValueError("TWILIO_DOCTOR_REPORT_CONTENT_SID is not configured")

        now = datetime.now(timezone.utc)
        last_7d = now - timedelta(days=7)
        last_week_str = (now - timedelta(days=6)).strftime("%d %b")
        date_str = now.strftime("%d %b %Y")

        # Find all doctors with active links
        doctor_query = db.query(User).join(
            DoctorProfile, DoctorProfile.user_id == User.id
        ).filter(
            User.role == 'doctor',
            User.is_active == True
        )

        if doctor_user_id:
            doctor_query = doctor_query.filter(User.id == doctor_user_id)

        doctors = doctor_query.all()
        results["total_doctors"] = len(doctors)

        for doctor in doctors:
            d_id = doctor.id
            try:
                summary = build_doctor_summary(db, d_id, last_7d)

                if summary["patients_with_data_count"] == 0:
                    logger.info("Doctor %s has no patient data for the week — skipping.", d_id)
                    continue

                # Compose the digest message
                # Header: Critical patients first
                critical_block = ""
                if summary["critical_patients"]:
                    critical_block = "🚨 CRITICAL: " + ", ".join(summary["critical_patients"]) + " | "

                # Per-patient summary lines
                patient_lines = []
                for p in summary["patients"]:
                    m = p["metrics"]
                    metric_parts = []
                    if "glucose" in m:
                        g = m["glucose"]
                        metric_parts.append(f"Sugar: {int(g['avg'])} avg ({int(g['min'])}-{int(g['max'])})")
                    if "bp" in m:
                        bp = m["bp"]
                        metric_parts.append(f"BP: {int(bp['avg_sys'])}/{int(bp['avg_dia'])} avg")
                    if "spo2" in m:
                        s = m["spo2"]
                        metric_parts.append(f"SpO2: {int(s['avg'])}% avg")
                    if "steps" in m:
                        metric_parts.append(f"Steps: {m['steps']['total']}")
                    
                    p_line = f"👤 {p['name']}: " + ", ".join(metric_parts)
                    if p["critical_metrics"]:
                        p_line += " ⚠️"
                    patient_lines.append(p_line)

                digest_snippet = critical_block + " | ".join(patient_lines)
                if len(digest_snippet) > 1000: # Twilio/WhatsApp limit safety
                    digest_snippet = digest_snippet[:997] + "..."

                # Log generation
                db.add(DoctorReportGenerationLog(
                    doctor_id=doctor.id,
                    trigger_type=trigger_type,
                    report_date=date.today(),
                    patients_linked_count=summary["total_patients_count"],
                    patients_with_data_count=summary["patients_with_data_count"],
                    critical_patients_count=len(summary["critical_patients"]),
                    status=ReportGenerationStatus.SUCCESS,
                ))
                db.commit()

                # Delivery
                target_phone = normalize_phone(doctor.phone_number)
                if not target_phone:
                    # Try doctor profile phone/whatsapp
                    dp = db.query(DoctorProfile).filter(DoctorProfile.user_id == doctor.id).first()
                    target_phone = normalize_phone(dp.whatsapp_number) or normalize_phone(dp.phone_number)

                if not target_phone:
                    logger.warning("Doctor %s has no phone number — skipping.", doctor.id)
                    continue

                # {{1}} = week start, {{2}} = week end, {{3}} = digest
                template_vars = [last_week_str, date_str, digest_snippet]

                delivery_log = WhatsAppMessageLog(
                    user_id=doctor.id,
                    phone_number=target_phone,
                    trigger_type=trigger_type,
                    report_date=date.today(),
                    member_ids_included=[], # not applicable for doctor
                    status=WhatsAppMessageStatus.QUEUED,
                    message_snapshot=digest_snippet
                )
                db.add(delivery_log)
                db.commit()

                success, sid, err = whatsapp_service.send_whatsapp_template(
                    target_phone, settings.TWILIO_DOCTOR_REPORT_CONTENT_SID, template_vars
                )
                delivery_log.status = WhatsAppMessageStatus.SENT if success else WhatsAppMessageStatus.FAILED
                delivery_log.twilio_sid = sid
                delivery_log.error_message = err
                db.commit()

                if success:
                    results["successful_deliveries"] += 1
                else:
                    results["failed_deliveries"] += 1
                    results["errors"].append(f"Doctor {doctor.id}: {err}")

            except Exception as e:
                logger.error("Failed to send report for doctor %s", doctor.id, exc_info=True)
                results["failed_deliveries"] += 1
                results["errors"].append(f"Doctor {doctor.id}: {str(e)}")

    except Exception as e:
        logger.error("Error in send_doctor_weekly_reports", exc_info=True)
        results["errors"].append(str(e))
    finally:
        if managed_session:
            db.close()

    return results


def trigger_single_profile_report(
    db: Session,
    profile: Profile,
    trigger_type: ReportTriggerType = ReportTriggerType.SCHEDULED,
    owner: Optional[User] = None,
) -> dict | None:
    """Builds report data for one profile. Returns None if no 7-day data exists.

    Returns a FAILED dict on error so the caller's transaction is not rolled back.
    """
    if owner is None:
        owner_access = db.query(ProfileAccess).filter(
            ProfileAccess.profile_id == profile.id,
            ProfileAccess.access_level == 'owner'
        ).first()
        owner = db.query(User).filter(User.id == owner_access.user_id).first() if owner_access else None

    if not owner:
        logger.warning("No owner found for profile %s — skipping.", profile.id)
        return None

    # Send to the profile's own phone; fall back to owner's phone for profiles
    # that belong to family members without their own smartphone (e.g. elderly parent)
    target_phone = normalize_phone(profile.phone_number) or normalize_phone(owner.phone_number)
    if not target_phone:
        logger.warning(
            "Profile %s (%s) has no phone and owner %s has no phone — skipping.",
            profile.id, profile.name, owner.id
        )
        return None

    logger.info(
        "Profile %s (%s) → sending to %s",
        profile.id, profile.name,
        "profile's own number" if normalize_phone(profile.phone_number) else "owner's number"
    )

    try:
        last_7d = datetime.now(timezone.utc) - timedelta(days=7)

        glucose = db.query(HealthReading).filter(
            HealthReading.profile_id == profile.id,
            HealthReading.reading_type == "glucose",
            HealthReading.reading_timestamp >= last_7d
        ).order_by(HealthReading.reading_timestamp.desc()).first()

        bp = db.query(HealthReading).filter(
            HealthReading.profile_id == profile.id,
            HealthReading.reading_type == "blood_pressure",
            HealthReading.reading_timestamp >= last_7d
        ).order_by(HealthReading.reading_timestamp.desc()).first()

        weight = db.query(HealthReading).filter(
            HealthReading.profile_id == profile.id,
            HealthReading.reading_type == "weight",
            HealthReading.reading_timestamp >= last_7d
        ).order_by(HealthReading.reading_timestamp.desc()).first()

        any_data = db.query(HealthReading).filter(
            HealthReading.profile_id == profile.id,
            HealthReading.reading_timestamp >= last_7d
        ).first()

        if not any_data:
            logger.info("Profile %s (%s) has no 7-day data — skipping.", profile.id, profile.name)
            return None

        insight = ai_report_service.get_weekly_ai_insight(db, profile.id, owner)

        # Build each metric line — no \n anywhere (template variable constraint)
        if glucose:
            g_status = classify_glucose(glucose.glucose_value)
            g_icon = "✅" if g_status == "NORMAL" else "⚠️"
            age_days = (datetime.now(timezone.utc) - ensure_utc(glucose.reading_timestamp)).days
            age_str = f" ({age_days}d ago)" if age_days > 0 else ""
            glucose_line = f"🩸 Sugar: {int(glucose.glucose_value)} mg/dL{age_str} ({g_status.title()}) {g_icon}"
        else:
            glucose_line = "🩸 Sugar: No checks this week"

        if bp:
            bp_status = classify_bp(bp.systolic, bp.diastolic)
            bp_icon = "✅" if bp_status == "NORMAL" else "⚠️"
            age_days = (datetime.now(timezone.utc) - ensure_utc(bp.reading_timestamp)).days
            age_str = f" ({age_days}d ago)" if age_days > 0 else ""
            bp_line = f"💓 BP: {int(bp.systolic)}/{int(bp.diastolic)} mmHg{age_str} ({bp_status.title()}) {bp_icon}"
        else:
            bp_line = "💓 BP: No checks this week"

        weight_line = None
        if weight and weight.weight_value:
            age_days = (datetime.now(timezone.utc) - ensure_utc(weight.reading_timestamp)).days
            age_str = f" ({age_days}d ago)" if age_days > 0 else ""
            weight_line = f"⚖️ Weight: {weight.weight_value:.1f} kg{age_str}"

        insight_line = None
        if insight:
            insight_clean = re.sub(r"\s+", " ", insight).strip()
            insight_line = f"✨ AI: {insight_clean}"

        # {{3}}: profile name + all metrics pipe-separated, no \n
        parts = [f"👤 *{profile.name}*", glucose_line, bp_line]
        if weight_line:
            parts.append(weight_line)
        if insight_line:
            parts.append(insight_line)
        snippet = " | ".join(parts)

        reading_ids = []
        if glucose: reading_ids.append(glucose.id)
        if bp: reading_ids.append(bp.id)
        if weight: reading_ids.append(weight.id)

        return {
            "status": ReportGenerationStatus.SUCCESS,
            "profile_id": profile.id,
            "owner_id": owner.id,
            "target_phone": target_phone,
            "snippet": snippet,
            "reading_ids": reading_ids,
            "profile_name": profile.name,
            "profile_data": {"glucose": glucose, "bp": bp, "weight": weight, "insight": insight},
        }

    except Exception as e:
        logger.error("Error building report for profile %s", profile.id, exc_info=True)
        return {
            "status": ReportGenerationStatus.FAILED,
            "profile_id": profile.id,
            "owner_id": owner.id if owner else None,
            "error_message": str(e),
        }


def send_weekly_reports(
    db: Optional[Session] = None,
    trigger_type: ReportTriggerType = ReportTriggerType.SCHEDULED,
    user_id: Optional[int] = None,
) -> dict:
    """Sends one WhatsApp report per profile to its owner.

    Deepak owns 4 profiles → Deepak's phone receives 4 separate messages,
    each with one profile's weekly health data.
    Profiles with no 7-day data are silently skipped.
    """
    managed_session = False
    if db is None:
        db = SessionLocal()
        managed_session = True

    results = {"total_profiles": 0, "successful_deliveries": 0, "failed_deliveries": 0, "errors": []}

    try:
        if not settings.TWILIO_REPORT_CONTENT_SID:
            raise ValueError("TWILIO_REPORT_CONTENT_SID is not configured")

        now = datetime.now(timezone.utc)
        last_week_str = (now - timedelta(days=6)).strftime("%d %b")
        date_str = now.strftime("%d %b %Y")

        query = db.query(Profile, User).join(
            ProfileAccess, ProfileAccess.profile_id == Profile.id
        ).join(
            User, User.id == ProfileAccess.user_id
        ).filter(
            ProfileAccess.access_level == 'owner',
            User.is_active == True
        )
        if user_id:
            query = query.filter(ProfileAccess.user_id == user_id)

        batch_size = 50
        offset = 0
        while True:
            rows = query.offset(offset).limit(batch_size).all()
            if not rows:
                break

            for p, owner in rows:
                results["total_profiles"] += 1
                data = trigger_single_profile_report(db, p, trigger_type, owner=owner)

                if not data:
                    # No 7-day data — skip silently
                    continue

                if data['status'] == ReportGenerationStatus.FAILED:
                    try:
                        db.add(ReportGenerationLog(
                            user_id=data['owner_id'],
                            trigger_type=trigger_type,
                            report_date=date.today(),
                            members_requested=[data['profile_id']],
                            members_with_data=[],
                            status=ReportGenerationStatus.FAILED,
                            error_message=data.get('error_message'),
                        ))
                        db.commit()
                    except Exception:
                        logger.error("Failed to log generation failure for profile %s", p.id, exc_info=True)
                    results["failed_deliveries"] += 1
                    continue

                # Send individual report for this profile
                phone = data['target_phone']
                try:
                    db.add(ReportGenerationLog(
                        user_id=data['owner_id'],
                        trigger_type=trigger_type,
                        report_date=date.today(),
                        members_requested=[data['profile_id']],
                        members_with_data=[data['profile_id']],
                        status=ReportGenerationStatus.SUCCESS,
                    ))
                    db.commit()

                    # {{1}} = week start, {{2}} = week end, {{3}} = this profile's data
                    template_vars = [last_week_str, date_str, data['snippet']]

                    delivery_log = WhatsAppMessageLog(
                        user_id=data['owner_id'],
                        phone_number=phone,
                        trigger_type=trigger_type,
                        report_date=date.today(),
                        member_ids_included=[data['profile_id']],
                        reading_ids_included=data['reading_ids'],
                        message_snapshot=data['snippet'],
                        status=WhatsAppMessageStatus.QUEUED,
                    )
                    db.add(delivery_log)
                    db.commit()

                    success, sid, err = whatsapp_service.send_whatsapp_template(
                        phone, settings.TWILIO_REPORT_CONTENT_SID, template_vars
                    )
                    delivery_log.status = WhatsAppMessageStatus.SENT if success else WhatsAppMessageStatus.FAILED
                    delivery_log.twilio_sid = sid
                    delivery_log.error_message = err
                    db.commit()

                    if success:
                        results["successful_deliveries"] += 1
                        logger.info(
                            "[REPORT] Sent profile %s (%s) to owner %s → %s",
                            data['profile_id'], data['profile_name'], data['owner_id'], sid
                        )
                    else:
                        results["failed_deliveries"] += 1
                        results["errors"].append(f"Profile {data['profile_name']}: {err}")
                        logger.error(
                            "[REPORT] Failed profile %s (%s): %s",
                            data['profile_id'], data['profile_name'], err
                        )

                except Exception as e:
                    logger.error("Failed to send report for profile %s", p.id, exc_info=True)
                    results["failed_deliveries"] += 1
                    results["errors"].append(f"Profile {data['profile_name']}: {str(e)}")

            offset += batch_size

        logger.info(
            "[REPORT] Run complete — profiles: %d, sent: %d, failed: %d",
            results["total_profiles"], results["successful_deliveries"], results["failed_deliveries"]
        )

    except Exception as e:
        logger.error("Error in send_weekly_reports", exc_info=True)
        results["errors"].append(str(e))
    finally:
        if managed_session:
            db.close()

    return results


if __name__ == "__main__":
    send_weekly_reports(trigger_type=ReportTriggerType.MANUAL)
