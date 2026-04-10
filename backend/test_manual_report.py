import sys
import os

# Ensure backend path is in sys.path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from sqlalchemy.orm import Session
from database import SessionLocal
from models import User, ReportTriggerType, ReportGenerationLog, WhatsAppMessageLog
from report_service import trigger_single_user_report

def run_test_for_user(email: str):
    db = SessionLocal()
    try:
        # 1. Find the user
        user = db.query(User).filter(User.email == email).first()
        if not user:
            print(f"❌ User with email {email} not found.")
            return

        print(f"🚀 Triggering manual report for: {user.full_name} ({user.phone_number})")
        print("-" * 50)

        # 2. Trigger the report
        success = trigger_single_user_report(db, user, trigger_type=ReportTriggerType.MANUAL)

        # 3. Fetch and display logs
        print("\n📊 --- AUDIT LOGS ---")
        
        # Generation Log
        gen_log = db.query(ReportGenerationLog).filter(
            ReportGenerationLog.user_id == user.id
        ).order_by(ReportGenerationLog.generated_at.desc()).first()
        
        if gen_log:
            print(f"✅ Generation Log ID: {gen_log.id}")
            print(f"   Status: {gen_log.status}")
            print(f"   Members Requested: {gen_log.members_requested}")
            print(f"   Members With Data: {gen_log.members_with_data}")
            if gen_log.error_message:
                print(f"   Error: {gen_log.error_message}")
        
        # Message Log
        msg_log = db.query(WhatsAppMessageLog).filter(
            WhatsAppMessageLog.user_id == user.id
        ).order_by(WhatsAppMessageLog.sent_at.desc()).first()
        
        if msg_log:
            print(f"\n📱 WhatsApp Delivery Log ID: {msg_log.id}")
            print(f"   Status: {msg_log.status}")
            print(f"   Twilio SID: {msg_log.twilio_sid}")
            if msg_log.error_message:
                print(f"   Delivery Error: {msg_log.error_message}")
            if msg_log.message_snapshot:
                print("\n📝 --- MESSAGE SNAPSHOT ---")
                print(msg_log.message_snapshot)
        else:
            print("\nℹ️ No WhatsApp log created (likely because no data was found).")

        if success:
            print("\n✨ Test completed successfully!")
        else:
            print("\n⚠️ Test finished but report was not sent (check logic/data availability).")

    finally:
        db.close()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        # Try to find the latest registered user as a default
        db_temp = SessionLocal()
        latest_user = db_temp.query(User).order_by(User.id.desc()).first()
        db_temp.close()
        
        if latest_user:
            print(f"No email provided. Using latest user: {latest_user.email}")
            run_test_for_user(latest_user.email)
        else:
            print("Usage: python test_manual_report.py your-email@example.com")
    else:
        run_test_for_user(sys.argv[1])
