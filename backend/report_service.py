import logging
import re
from datetime import datetime, timedelta, date, timezone
from typing import Optional
from sqlalchemy.orm import Session
from database import SessionLocal
from models import (
    User, Profile, HealthReading, ProfileAccess,
    ReportGenerationLog, WhatsAppMessageLog,
    ReportTriggerType, WhatsAppMessageStatus, ReportGenerationStatus
)
from health_utils import classify_bp, classify_glucose
from utils.phone import normalize_phone
from utils.datetime_helpers import ensure_utc
from twilio_service import whatsapp_service
from config import settings
import ai_report_service

logger = logging.getLogger(__name__)


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
