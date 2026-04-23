"""
Manual test script to verify Twilio WhatsApp reports across MULTIPLE profiles.
Fetches user and profiles from DB and sends reports.

Usage:
1. Update .env with Twilio credentials.
2. Update TEST_PHONE to your own.
3. Run: python test_whatsapp_report.py
"""
import sys
import os
from datetime import datetime, timedelta

# Add current directory to path so we can import modules
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from database import SessionLocal
from models import User, Profile, HealthReading, ProfileAccess, ReportTriggerType
from report_service import trigger_single_profile_report

def normalize_phone(phone: str) -> str:
    """Basic normalization for searching/creating."""
    phone = phone.strip()
    for char in [" ", "-", "(", ")"]:
        phone = phone.replace(char, "")
    if len(phone) == 10 and phone.isdigit():
        return f"+91{phone}"
    if phone.startswith("91") and len(phone) == 12:
        return f"+{phone}"
    return phone

def test_existing_profile_reports(request_phone: str):
    db = SessionLocal()
    try:
        normalized = normalize_phone(request_phone)
        
        # 1. Fetch existing user
        user = db.query(User).filter(
            (User.phone_number == request_phone) | (User.phone_number == normalized)
        ).first()
        
        if not user:
            print(f"❌ No user found for phone: {request_phone}. Creating a test user and profiles...")
            # Optional: fallback to creation if you want the test to be self-contained
            user = User(
                email=f"tester_{datetime.now().timestamp()}@swasth.app",
                full_name="Deepak (Tester)",
                password_hash="unused",
                phone_number=normalized,
                timezone="Asia/Kolkata",
                ai_consent=True
            )
            db.add(user)
            db.commit()
            db.refresh(user)
        else:
            print(f"✅ Found user: {user.full_name} ({user.phone_number})")

        # 2. Fetch profiles owned by this user
        profiles = db.query(Profile).join(ProfileAccess).filter(
            ProfileAccess.user_id == user.id,
            ProfileAccess.access_level == "owner"
        ).all()

        if not profiles:
            print(f"⚠️ No profiles found for user {user.full_name}. Creating test profiles...")
            # Create a few test profiles if none exist
            p_names = ["Deepak", "Papa"]
            for name in p_names:
                p = Profile(name=name, phone_number=normalized)
                db.add(p)
                db.commit()
                db.refresh(p)
                db.add(ProfileAccess(user_id=user.id, profile_id=p.id, access_level="owner"))
                profiles.append(p)
            db.commit()
        else:
            print(f"✅ Found {len(profiles)} profiles for user.")

        # 3. Ensure they have some fresh data so the report isn't empty
        print("📊 Checking for fresh data (last 7 days)...")
        for p in profiles:
            # Ensure profile has the test phone number for this manual test
            if p.phone_number != normalized:
                p.phone_number = normalized
            
            any_data = db.query(HealthReading).filter(
                HealthReading.profile_id == p.id,
                HealthReading.reading_timestamp >= (datetime.utcnow() - timedelta(days=7))
            ).first()
            
            if not any_data:
                print(f"   ➕ Adding fresh sample data for {p.name}...")
                db.add(HealthReading(
                    profile_id=p.id,
                    reading_type="glucose",
                    glucose_value=120.0,
                    value_numeric=120.0,
                    unit_display="mg/dL",
                    reading_timestamp=datetime.now()
                ))
        db.commit()

        # 4. Trigger reports
        print(f"\n📩 Triggering separate WhatsApp reports...")
        for p in profiles:
            print(f"   -> Sending report for {p.name} to {p.phone_number}...")
            success = trigger_single_profile_report(db, p, trigger_type=ReportTriggerType.MANUAL)
            if success:
                print(f"      ✅ Success!")
            else:
                print(f"      ❌ Failed (likely no data or Twilio error).")
        
    finally:
        db.close()

if __name__ == "__main__":
    # --- IMPORTANT: CHANGE THIS TO YOUR PHONE NUMBER ---
    TEST_PHONE = "918700151250" 
    # ---------------------------------------------------
    
    if TEST_PHONE == "918700151250":
        print("❌ ERROR: Please update TEST_PHONE in the script to your own number.")
        sys.exit(1)
    
    print(f"🚀 Starting profile report test for: {TEST_PHONE}")
    test_existing_profile_reports(TEST_PHONE)
    
    print("\n🏁 Test complete. Check your WhatsApp!")
