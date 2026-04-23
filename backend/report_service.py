import logging
from datetime import datetime, timedelta, date
import pytz
from typing import Optional, List
from sqlalchemy.orm import Session
from database import SessionLocal
from models import (
    User, Profile, HealthReading, ProfileAccess,
    ReportGenerationLog, WhatsAppMessageLog,
    ReportTriggerType, WhatsAppMessageStatus, ReportGenerationStatus
)
from health_utils import classify_bp, classify_glucose
from twilio_service import whatsapp_service
from config import settings
import ai_report_service

logger = logging.getLogger(__name__)

def format_report_message(profile_name: str, profile_data: dict) -> str:
    """Format the individual weekly report message for a specific profile."""
    # Fallback to IST since it's an Indian app
    tz = pytz.timezone("Asia/Kolkata")
    now = datetime.now(tz)
    
    date_str = now.strftime("%d %b %Y")
    last_week_str = (now - timedelta(days=6)).strftime("%d %b")
    
    msg = [
        "📊 *Weekly Health Report*",
        f"📅 {last_week_str} – {date_str}",
        "══════════════════════",
        f"👤 *{profile_name}*"
    ]
    
    # Stats summary
    glucose = profile_data.get('glucose')
    if glucose:
        val = glucose.glucose_value
        status = classify_glucose(val)
        icon = "✅" if status == "NORMAL" else "⚠️"
        msg.append(f"🩸 Sugar: {int(val)} mg/dL ({status.title()}) {icon}")
    else:
        msg.append("🩸 Sugar: No checks today")
        
    bp = profile_data.get('bp')
    if bp:
        sys, dia = bp.systolic, bp.diastolic
        status = classify_bp(sys, dia)
        icon = "✅" if status == "NORMAL" else "⚠️"
        msg.append(f"💓 BP: {int(sys)}/{int(dia)} mmHg ({status.title()}) {icon}")
    else:
        msg.append("💓 BP: No checks today")

    # AI Insight Section
    if profile_data.get('insight'):
        msg.append(f"\n✨ *AI Evaluation:* {profile_data['insight']}")
            
    msg.append("══════════════════════")
    msg.append("💚 Stay healthy! — *Swasth*")
    
    return "\n".join(msg)

def format_report_template_variables(profile_name: str, profile_data: dict) -> List[str]:
    """
    Format template variables for Twilio WhatsApp template.
    Template has 3 variables and renders as:
    📊 *Weekly Health Report*
    📅 {{1}} – {{2}}
    ══════════════════════
    {{3}}
    ══════════════════════
    💚 Stay healthy! — *Swasth*
    
    NOTE: Twilio does not allow newlines in variable values, so {{3}} is formatted as lines separated by spaces.
    The template itself should handle line breaks.
    
    Returns a list of 3 strings for the template variables.
    """
    tz = pytz.timezone("Asia/Kolkata")
    now = datetime.now(tz)
    
    # {{1}}: Start date (e.g., "16 Apr")
    last_week_str = (now - timedelta(days=6)).strftime("%d %b")
    var1 = last_week_str
    
    # {{2}}: End date (e.g., "22 Apr 2026")
    date_str = now.strftime("%d %b %Y")
    var2 = date_str
    
    # {{3}}: Profile name + health readings + AI insight (NO newlines - Twilio constraint)
    msg_lines = [f"👤 *{profile_name}*"]
    
    glucose = profile_data.get('glucose')
    if glucose:
        val = glucose.glucose_value
        status = classify_glucose(val)
        icon = "✅" if status == "NORMAL" else "⚠️"
        msg_lines.append(f"🩸 Sugar: {int(val)} mg/dL ({status.title()}) {icon}")
    else:
        msg_lines.append("🩸 Sugar: No checks today")
        
    bp = profile_data.get('bp')
    if bp:
        sys, dia = bp.systolic, bp.diastolic
        status = classify_bp(sys, dia)
        icon = "✅" if status == "NORMAL" else "⚠️"
        msg_lines.append(f"💓 BP: {int(sys)}/{int(dia)} mmHg ({status.title()}) {icon}")
    else:
        msg_lines.append("💓 BP: No checks today")

    if profile_data.get('insight'):
        # Sanitize insight: remove newlines and excessive spaces
        insight = profile_data['insight']
        insight_clean = insight.replace('\n', ' ').replace('\t', ' ')
        while '  ' in insight_clean:
            insight_clean = insight_clean.replace('  ', ' ')
        msg_lines.append(f"✨ *AI Evaluation:* {insight_clean.strip()}")
    
    # Join with newlines for display, but will be sanitized in twilio_service.py
    var3 = "\n".join(msg_lines)
    
    return [var1, var2, var3]

def trigger_single_profile_report(db: Session, profile: Profile, trigger_type: ReportTriggerType = ReportTriggerType.SCHEDULED) -> bool:
    """
    Generates and sends a report for a single profile to its own phone number.
    Returns True if a message was successfully attempted.
    """
    # Find the owner user to check for AI consent
    owner_access = db.query(ProfileAccess).filter(
        ProfileAccess.profile_id == profile.id,
        ProfileAccess.access_level == 'owner'
    ).first()
    
    owner = db.query(User).filter(User.id == owner_access.user_id).first() if owner_access else None
    
    # 1. Initialize Generation Log (we link it to the owner user for auditing)
    # If no owner, we can't really audit/send properly under current schema, but we'll try.
    audit_user_id = owner.id if owner else 0

    gen_log = ReportGenerationLog(
        user_id=audit_user_id,
        trigger_type=trigger_type,
        report_date=date.today(),
        members_requested=[profile.id],
        members_with_data=[],
        members_skipped=[],
        status=ReportGenerationStatus.FAILED
    )
    db.add(gen_log)
    db.commit()
    db.refresh(gen_log)

    try:
        last_7d = datetime.utcnow() - timedelta(days=7)

        # Latest Glucose (within last 24h for the 'Latest' spot)
        glucose = db.query(HealthReading).filter(
            HealthReading.profile_id == profile.id,
            HealthReading.reading_type == "glucose",
            HealthReading.reading_timestamp >= (datetime.utcnow() - timedelta(hours=24))
        ).order_by(HealthReading.reading_timestamp.desc()).first()
        
        # Latest BP
        bp = db.query(HealthReading).filter(
            HealthReading.profile_id == profile.id,
            HealthReading.reading_type == "blood_pressure",
            HealthReading.reading_timestamp >= (datetime.utcnow() - timedelta(hours=24))
        ).order_by(HealthReading.reading_timestamp.desc()).first()
        
        # Check for any data in 7d to decide if we send the report
        any_data = db.query(HealthReading).filter(
            HealthReading.profile_id == profile.id,
            HealthReading.reading_timestamp >= last_7d
        ).first()

        if not any_data:
            gen_log.members_skipped = [profile.id]
            gen_log.status = ReportGenerationStatus.FAILED
            gen_log.error_message = "No data found for profile in the last 7 days."
            db.commit()
            return False

        # Generate AI Insight for the week
        # ai_report_service.get_weekly_ai_insight handles consent check internally via owner user
        insight = ai_report_service.get_weekly_ai_insight(db, profile.id, owner) if owner else "Owner not found."
        
        profile_data = {
            "glucose": glucose,
            "bp": bp,
            "insight": insight
        }

        # Update Generation Log status
        gen_log.members_with_data = [profile.id]
        gen_log.status = ReportGenerationStatus.SUCCESS
        db.commit()

        # 2. Format template variables and Normalize phone
        template_vars = format_report_template_variables(profile.name, profile_data)
        message_snapshot = format_report_message(profile.name, profile_data)  # For logging/audit
        
        phone = profile.phone_number.strip()
        for char in [" ", "-", "(", ")"]: phone = phone.replace(char, "")
        if len(phone) == 10 and phone.isdigit(): phone = f"+91{phone}"
        elif not phone.startswith("+") and phone.startswith("91") and len(phone) == 12: phone = f"+{phone}"

        reading_ids = []
        if glucose: reading_ids.append(glucose.id)
        if bp: reading_ids.append(bp.id)

        delivery_log = WhatsAppMessageLog(
            user_id=audit_user_id,
            phone_number=phone,
            trigger_type=trigger_type,
            report_date=date.today(),
            member_ids_included=[profile.id],
            reading_ids_included=reading_ids,
            message_snapshot=message_snapshot,
            status=WhatsAppMessageStatus.QUEUED
        )
        db.add(delivery_log)
        db.commit()
        db.refresh(delivery_log)

        # 3. Send via Twilio Template
        if not settings.TWILIO_REPORT_CONTENT_SID:
            logger.error("TWILIO_REPORT_CONTENT_SID not configured. Cannot send template message.")
            delivery_log.status = WhatsAppMessageStatus.FAILED
            delivery_log.error_message = "TWILIO_REPORT_CONTENT_SID not configured"
            db.commit()
            return False
        
        success, sid, twilio_error = whatsapp_service.send_whatsapp_template(
            phone, 
            settings.TWILIO_REPORT_CONTENT_SID,
            template_vars
        )
        
        delivery_log.twilio_sid = sid
        delivery_log.error_message = twilio_error
        delivery_log.status = WhatsAppMessageStatus.SENT if success else WhatsAppMessageStatus.FAILED
        db.commit()
        
        return success

    except Exception as e:
        error_msg = str(e)
        logger.error(
            "Error generating report for profile %s", profile.id, exc_info=True
        )
        gen_log.status = ReportGenerationStatus.FAILED
        gen_log.error_message = error_msg
        db.commit()
        return False

def send_weekly_reports(db: Optional[Session] = None, trigger_type: ReportTriggerType = ReportTriggerType.SCHEDULED):
    """Main task to send Weekly WhatsApp reports to all profiles in batches."""
    import time
    managed_session = False
    if db is None:
        db = SessionLocal()
        managed_session = True
        
    try:
        # Fetch profiles with a phone number (Batching logic)
        batch_size = 20
        offset = 0
        
        while True:
            profiles = db.query(Profile).filter(
                Profile.phone_number != None, 
                Profile.phone_number != ""
            ).offset(offset).limit(batch_size).all()
            
            if not profiles:
                break
                
            for profile in profiles:
                try:
                    trigger_single_profile_report(db, profile, trigger_type=trigger_type)
                except Exception:
                    logger.error(
                        "Failed to process profile %s in batch",
                        profile.id,
                        exc_info=True,
                    )
            
            offset += batch_size
            time.sleep(1) # Small pause between batches to breathe
            
    except Exception:
        logger.error("Error in global send_weekly_reports task", exc_info=True)
    finally:
        if managed_session:
            db.close()

if __name__ == "__main__":
    # For quick manual testing
    send_weekly_reports(trigger_type=ReportTriggerType.MANUAL)
