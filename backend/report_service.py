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

def format_report_message(user: User, profiles_data: list) -> str:
    """Format the cumulative report message for a user."""
    # Date in user's timezone if possible, or fallback to IST since it's an Indian app
    user_tz_str = getattr(user, "timezone", "Asia/Kolkata")
    try:
        tz = pytz.timezone(user_tz_str)
    except Exception:
        tz = pytz.timezone("Asia/Kolkata")
        
    # Use the current time in user's timezone for the report header date
    now = datetime.now(tz)
    date_str = now.strftime("%A, %d %b %Y")
    
    msg = [
        "📊 *Daily Health Report*",
        f"📅 {date_str}",
        "══════════════════════════\n"
    ]
    
    for p in profiles_data:
        msg.append(f"👤 *{p['name']}*")
        msg.append("──────────────────────")
        
        # Sugar
        if p['glucose']:
            val = p['glucose'].glucose_value
            status = classify_glucose(val)
            # Match status to user icons
            icon = "✅" if status == "NORMAL" else "⚠️"
            # Clean up status text (e.g. HIGH -> High)
            status_text = status.replace("_", " ").title()
            msg.append(f"🩸 Sugar: {int(val)} mg/dL — {status_text} {icon}")
        else:
            msg.append("🩸 Sugar: No reading today")
            
        # BP
        if p['bp']:
            sys, dia = p['bp'].systolic, p['bp'].diastolic
            status = classify_bp(sys, dia)
            icon = "✅" if status == "NORMAL" else "⚠️"
            status_text = status.replace(" - ", " ").title()
            msg.append(f"💓 BP: {int(sys)}/{int(dia)} mmHg — {status_text} {icon}\n")
        else:
            msg.append("💓 BP: No reading today\n")
            
    msg.append("💚 Stay healthy! — *Swasth*")
    return "\n".join(msg)

def trigger_single_user_report(db: Session, user: User, trigger_type: ReportTriggerType = ReportTriggerType.SCHEDULED) -> bool:
    """
    Generates and sends a report for a single user with full auditing.
    Returns True if a message was successfully attempted.
    """
    controlled_profiles = db.query(Profile).join(ProfileAccess).filter(
        ProfileAccess.user_id == user.id,
        ProfileAccess.access_level == 'owner'
    ).all()
    
    requested_ids = [p.id for p in controlled_profiles]
    
    # 1. Initialize Generation Log
    gen_log = ReportGenerationLog(
        user_id=user.id,
        trigger_type=trigger_type,
        report_date=date.today(),
        members_requested=requested_ids,
        members_with_data=[],
        members_skipped=[],
        status=ReportGenerationStatus.FAILED
    )
    db.add(gen_log)
    db.commit()
    db.refresh(gen_log)

    try:
        if not controlled_profiles:
            gen_log.error_message = "No controlled profiles found for user."
            db.commit()
            return False

        profiles_data = []
        with_data_ids = []
        skipped_ids = []
        all_reading_ids = []

        last_24h = datetime.utcnow() - timedelta(hours=24)

        for profile in controlled_profiles:
            # Latest Glucose
            glucose = db.query(HealthReading).filter(
                HealthReading.profile_id == profile.id,
                HealthReading.reading_type == "glucose",
                HealthReading.reading_timestamp >= last_24h
            ).order_by(HealthReading.reading_timestamp.desc()).first()
            
            # Latest BP
            bp = db.query(HealthReading).filter(
                HealthReading.profile_id == profile.id,
                HealthReading.reading_type == "blood_pressure",
                HealthReading.reading_timestamp >= last_24h
            ).order_by(HealthReading.reading_timestamp.desc()).first()
            
            if glucose or bp:
                profiles_data.append({
                    "name": profile.name,
                    "glucose": glucose,
                    "bp": bp
                })
                with_data_ids.append(profile.id)
                if glucose: all_reading_ids.append(glucose.id)
                if bp: all_reading_ids.append(bp.id)
            else:
                skipped_ids.append(profile.id)

        # Update Generation Log status
        gen_log.members_with_data = with_data_ids
        gen_log.members_skipped = skipped_ids
        
        if not profiles_data:
            gen_log.status = ReportGenerationStatus.FAILED
            gen_log.error_message = "No data found for any profile in the last 24h."
            db.commit()
            return False

        gen_log.status = ReportGenerationStatus.PARTIAL if skipped_ids else ReportGenerationStatus.SUCCESS
        db.commit()

        # 2. Build Message and Start Delivery Log
        message_text = format_report_message(user, profiles_data)
        
        # Normalize phone
        phone = user.phone_number.strip()
        for char in [" ", "-", "(", ")"]: phone = phone.replace(char, "")
        if len(phone) == 10 and phone.isdigit(): phone = f"+91{phone}"
        elif not phone.startswith("+") and phone.startswith("91") and len(phone) == 12: phone = f"+{phone}"

        delivery_log = WhatsAppMessageLog(
            user_id=user.id,
            phone_number=phone,
            trigger_type=trigger_type,
            report_date=date.today(),
            member_ids_included=with_data_ids,
            reading_ids_included=all_reading_ids,
            message_snapshot=message_text,
            status=WhatsAppMessageStatus.QUEUED
        )
        db.add(delivery_log)
        db.commit()
        db.refresh(delivery_log)

        # 3. Call Twilio
        success, sid, twilio_error = whatsapp_service.send_whatsapp(phone, message_text)
        
        delivery_log.twilio_sid = sid
        delivery_log.error_message = twilio_error
        delivery_log.status = WhatsAppMessageStatus.SENT if success else WhatsAppMessageStatus.FAILED
        db.commit()
        
        return success

    except Exception as e:
        error_msg = str(e)
        print(f"Error generating report for user {user.id}: {error_msg}")
        gen_log.status = ReportGenerationStatus.FAILED
        gen_log.error_message = error_msg
        db.commit()
        return False

def send_daily_reports(db: Optional[Session] = None, trigger_type: ReportTriggerType = ReportTriggerType.SCHEDULED):
    """Main task to aggregate data and send WhatsApp reports to all users."""
    managed_session = False
    if db is None:
        db = SessionLocal()
        managed_session = True
        
    try:
        # Fetch users with phone numbers
        users = db.query(User).filter(User.phone_number != None, User.phone_number != "").all()
        
        for user in users:
            trigger_single_user_report(db, user, trigger_type=trigger_type)
                
    except Exception as e:
        print(f"Error in global send_daily_reports task: {e}")
    finally:
        if managed_session:
            db.close()

if __name__ == "__main__":
    # For quick manual testing
    send_daily_reports(trigger_type=ReportTriggerType.MANUAL)
