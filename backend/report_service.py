from datetime import datetime, timedelta
import pytz
from typing import Optional
from sqlalchemy.orm import Session
from database import SessionLocal
from models import User, Profile, HealthReading, ProfileAccess
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

def send_daily_reports(db: Optional[Session] = None):
    """Main task to aggregate data and send WhatsApp reports to all users with phone numbers."""
    managed_session = False
    if db is None:
        db = SessionLocal()
        managed_session = True
        
    try:
        # Fetch users with phone numbers
        users = db.query(User).filter(User.phone_number != None, User.phone_number != "").all()
        
        for user in users:
            # Normalize phone number for Twilio (E.164 format)
            phone = user.phone_number.strip()
            # Strip common characters
            for char in [" ", "-", "(", ")"]:
                phone = phone.replace(char, "")
                
            # Assume India (+91) if it's 10 digits without a prefix
            if len(phone) == 10 and phone.isdigit():
                phone = f"+91{phone}"
            elif not phone.startswith("+"):
                # If it's something like 91870..., add the +
                if phone.startswith("91") and len(phone) == 12:
                    phone = f"+{phone}"
                else:
                    # Fallback to current behavior but logging it
                    pass
            profiles_data = []
            
            # Find profiles where user is owner (Primary controlled profiles)
            controlled_profiles = db.query(Profile).join(ProfileAccess).filter(
                ProfileAccess.user_id == user.id,
                ProfileAccess.access_level == 'owner'
            ).all()
            
            if not controlled_profiles:
                continue
                
            # Aggregate latest readings from last 24 hours
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
            
            if profiles_data:
                message_text = format_report_message(user, profiles_data)
                # Note: Prefix with whatsapp: is handled in twilio_service.py
                whatsapp_service.send_whatsapp(phone, message_text)
                print(f"Daily report sent to {user.full_name} ({phone})")
                
    except Exception as e:
        print(f"Error in send_daily_reports task: {e}")
    finally:
        if managed_session:
            db.close()

if __name__ == "__main__":
    # For quick manual testing
    send_daily_reports()
