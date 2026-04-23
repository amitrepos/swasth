import logging
import re
from datetime import datetime, timedelta, date
import pytz
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
from twilio_service import whatsapp_service
from config import settings
import ai_report_service

logger = logging.getLogger(__name__)

def trigger_single_profile_report(db: Session, profile: Profile, trigger_type: ReportTriggerType = ReportTriggerType.SCHEDULED, owner: Optional[User] = None) -> dict | None:
    """Generates report data for a single profile, or None if no report should be sent.

    On failure, returns a FAILED status dict rather than raising — the caller owns
    the transaction and must not have it rolled back by this function.
    """
    if owner is None:
        owner_access = db.query(ProfileAccess).filter(
            ProfileAccess.profile_id == profile.id,
            ProfileAccess.access_level == 'owner'
        ).first()
        owner = db.query(User).filter(User.id == owner_access.user_id).first() if owner_access else None

    # C4 Fix: Guard upfront
    if not owner:
        logger.warning("No owner found for profile %s. Skipping report.", profile.id)
        return None

    # C2 Fix (Privacy): Always dispatch to owner per senior feedback
    target_phone = normalize_phone(owner.phone_number)
    if not target_phone:
        logger.warning(
            "Profile %s owner %s has no valid phone — skipping report",
            profile.id, owner.id
        )
        return None

    try:
        last_7d = datetime.utcnow() - timedelta(days=7)

        # Latest Glucose (up to 7 days old)
        glucose = db.query(HealthReading).filter(
            HealthReading.profile_id == profile.id,
            HealthReading.reading_type == "glucose",
            HealthReading.reading_timestamp >= last_7d
        ).order_by(HealthReading.reading_timestamp.desc()).first()
        
        # Latest BP (up to 7 days old)
        bp = db.query(HealthReading).filter(
            HealthReading.profile_id == profile.id,
            HealthReading.reading_type == "blood_pressure",
            HealthReading.reading_timestamp >= last_7d
        ).order_by(HealthReading.reading_timestamp.desc()).first()
        
        # Check for ANY data in 7d
        any_data = db.query(HealthReading).filter(
            HealthReading.profile_id == profile.id,
            HealthReading.reading_timestamp >= last_7d
        ).first()

        if not any_data:
            return None

        # Generate AI Insight
        insight = ai_report_service.get_weekly_ai_insight(db, profile.id, owner)
        
        profile_data = {
            "glucose": glucose,
            "bp": bp,
            "insight": insight
        }

        # Build individual snippet for this profile
        glucose_line = ""
        if glucose:
            status = classify_glucose(glucose.glucose_value)
            icon = "✅" if status == "NORMAL" else "⚠️"
            # Label older readings
            age_days = (datetime.utcnow() - glucose.reading_timestamp).days
            age_str = f" ({age_days}d ago)" if age_days > 0 else ""
            glucose_line = f"🩸 Sugar: {int(glucose.glucose_value)} mg/dL{age_str} ({status.title()}) {icon}"
        else:
            glucose_line = "🩸 Sugar: No checks this week"

        bp_line = ""
        if bp:
            status = classify_bp(bp.systolic, bp.diastolic)
            icon = "✅" if status == "NORMAL" else "⚠️"
            # Label older readings
            age_days = (datetime.utcnow() - bp.reading_timestamp).days
            age_str = f" ({age_days}d ago)" if age_days > 0 else ""
            bp_line = f"💓 BP: {int(bp.systolic)}/{int(bp.diastolic)} mmHg{age_str} ({status.title()}) {icon}"
        else:
            bp_line = "💓 BP: No checks this week"

        insight_line = ""
        if insight:
            insight_clean = re.sub(r"\s+", " ", insight.replace('\n', ' ').replace('\t', ' ')).strip()
            insight_line = f"✨ *AI Evaluation:* {insight_clean}"

        snippet = f"👤 *{profile.name}*\n{glucose_line}\n{bp_line}"
        if insight_line:
            snippet += f"\n{insight_line}"

        reading_ids = []
        if glucose: reading_ids.append(glucose.id)
        if bp: reading_ids.append(bp.id)

        return {
            "status": ReportGenerationStatus.SUCCESS,
            "profile_id": profile.id,
            "owner_id": owner.id,
            "target_phone": target_phone,
            "snippet": snippet,
            "reading_ids": reading_ids,
            "profile_name": profile.name,
            "profile_data": profile_data
        }

    except Exception as e:
        logger.error("Error generating report data for profile %s", profile.id, exc_info=True)
        return {
            "status": ReportGenerationStatus.FAILED,
            "profile_id": profile.id,
            "owner_id": owner.id if owner else None,
            "error_message": str(e)
        }

def send_weekly_reports(db: Optional[Session] = None, trigger_type: ReportTriggerType = ReportTriggerType.SCHEDULED, user_id: Optional[int] = None) -> dict:
    """Main task: Groups profiles by recipient phone and sends ONE consolidated message.
    
    If user_id is provided, only sends for profiles owned by that user.
    Returns a dict summary of results.
    """
    managed_session = False
    if db is None:
        db = SessionLocal()
        managed_session = True
        
    results = {"total_profiles": 0, "successful_deliveries": 0, "failed_deliveries": 0, "errors": []}
    
    try:
        if not settings.TWILIO_REPORT_CONTENT_SID:
            raise ValueError("TWILIO_REPORT_CONTENT_SID is not configured")

        # 1. Collect all reportable data — keyed by owner_id so two owners
        # sharing a device phone each get their own DPDP audit record.
        recipient_map: dict[int, list] = {}
        skipped_by_owner: dict[int, list] = {}  # owner_id -> profile_ids with no 7-day data

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
            if not rows: break

            for p, owner in rows:
                results["total_profiles"] += 1
                data = trigger_single_profile_report(db, p, trigger_type, owner=owner)
                if not data:
                    skipped_by_owner.setdefault(owner.id, []).append(p.id)
                    continue

                if data['status'] == ReportGenerationStatus.FAILED:
                    if data.get('owner_id'):
                        try:
                            gen_log = ReportGenerationLog(
                                user_id=data['owner_id'],
                                trigger_type=trigger_type,
                                report_date=date.today(),
                                members_requested=[data['profile_id']],
                                members_with_data=[],
                                status=ReportGenerationStatus.FAILED,
                                error_message=data.get('error_message')
                            )
                            db.add(gen_log)
                            db.commit()
                        except Exception:
                            logger.error("Failed to log generation failure", exc_info=True)
                else:
                    recipient_map.setdefault(data['owner_id'], []).append(data)
            
            offset += batch_size

        # 2. Send consolidated messages
        tz = pytz.timezone("Asia/Kolkata")
        now = datetime.now(tz)
        last_week_str = (now - timedelta(days=6)).strftime("%d %b")
        date_str = now.strftime("%d %b %Y")

        for owner_id, profile_list in recipient_map.items():
            phone = profile_list[0]['target_phone']
            try:
                profile_ids = [p['profile_id'] for p in profile_list]
                all_reading_ids = []
                for p in profile_list: all_reading_ids.extend(p['reading_ids'])
                
                gen_log = ReportGenerationLog(
                    user_id=owner_id,
                    trigger_type=trigger_type,
                    report_date=date.today(),
                    members_requested=profile_ids + skipped_by_owner.get(owner_id, []),
                    members_with_data=profile_ids,
                    members_skipped=skipped_by_owner.get(owner_id, []) or None,
                    status=ReportGenerationStatus.SUCCESS
                )
                db.add(gen_log)
                db.commit()

                # Build consolidation snippet
                full_body = "\n\n".join([p['snippet'] for p in profile_list])
                template_vars = [last_week_str, date_str, full_body]
                
                delivery_log = WhatsAppMessageLog(
                    user_id=owner_id,
                    phone_number=phone,
                    trigger_type=trigger_type,
                    report_date=date.today(),
                    member_ids_included=profile_ids,
                    reading_ids_included=all_reading_ids,
                    message_snapshot=full_body,
                    status=WhatsAppMessageStatus.QUEUED
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
                else:
                    results["failed_deliveries"] += 1
                    results["errors"].append(f"Phone ***{phone[-4:]}: {err}")

            except Exception as e:
                logger.error("Failed to send consolidated report to %s", phone, exc_info=True)
                results["failed_deliveries"] += 1
                results["errors"].append(f"Phone ***{phone[-4:]}: {str(e)}")

    except Exception as e:
        logger.error("Error in send_weekly_reports task", exc_info=True)
        results["errors"].append(str(e))
    finally:
        if managed_session:
            db.close()
    
    return results

if __name__ == "__main__":
    # For quick manual testing
    send_weekly_reports(trigger_type=ReportTriggerType.MANUAL)
