"""
Manual test script to verify Twilio WhatsApp reports across MULTIPLE profiles.
Usage:
1. Update .env with Twilio credentials.
2. Update the phone_number in this script to your own.
3. Run: python test_whatsapp_report.py
"""
import sys
import os
from datetime import datetime, timedelta

# Add current directory to path so we can import modules
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from database import SessionLocal
from models import User, Profile, HealthReading, ProfileAccess
from report_service import send_weekly_reports

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

def setup_multi_profile_test_data(request_phone: str):
    db = SessionLocal()
    try:
        normalized = normalize_phone(request_phone)
        
        # 1. Get or create a test user
        # Try finding by exact match or normalized match
        user = db.query(User).filter(
            (User.phone_number == request_phone) | (User.phone_number == normalized)
        ).first()
        
        if not user:
            user = User(
                email=f"test_{datetime.now().timestamp()}@example.com",
                full_name="Deepak (Tester)",
                password_hash="unused_in_this_test",
                phone_number=normalized,
                timezone="Asia/Kolkata"
            )
            db.add(user)
            db.commit()
            db.refresh(user)
            print(f"✅ User found/created: {user.full_name} ({user.phone_number})")
        else:
            print(f"✅ Using existing user: {user.full_name} ({user.phone_number})")

        # 2. Setup multiple profiles
        profile_names = ["Deepak", "Papa", "Mummy"]
        
        for p_name in profile_names:
            # Check if user already owns a profile with this name
            profile = db.query(Profile).join(ProfileAccess).filter(
                ProfileAccess.user_id == user.id,
                ProfileAccess.access_level == "owner",
                Profile.name == p_name
            ).first()
            
            if not profile:
                profile = Profile(name=p_name, relationship="family")
                if p_name == "Deepak": 
                    profile.relationship = "myself"
                db.add(profile)
                db.commit()
                db.refresh(profile)
                
                # Associate user as owner
                access = ProfileAccess(user_id=user.id, profile_id=profile.id, access_level="owner")
                db.add(access)
                db.commit()
                print(f"✅ Created profile: {p_name}")
            else:
                print(f"✅ Profile already exists: {p_name}")

            # 3. Add fresh readings for today (last 24h) for this profile
            # Glucose
            reading = HealthReading(
                profile_id=profile.id,
                reading_type="glucose",
                glucose_value=125.0 if p_name == "Deepak" else 172.0,
                value_numeric=125.0 if p_name == "Deepak" else 172.0,
                unit_display="mg/dL",
                status_flag="NORMAL" if p_name == "Deepak" else "HIGH",
                reading_timestamp=datetime.utcnow()
            )
            db.add(reading)
            
            # Blood Pressure
            bp_sys = 120.0 if p_name == "Deepak" else 145.0
            bp_dia = 80.0 if p_name == "Deepak" else 90.0
            bp = HealthReading(
                profile_id=profile.id,
                reading_type="blood_pressure",
                systolic=bp_sys,
                diastolic=bp_dia,
                value_numeric=bp_sys,
                unit_display="mmHg",
                status_flag="NORMAL" if p_name == "Deepak" else "HIGH - STAGE 1",
                reading_timestamp=datetime.utcnow()
            )
            db.add(bp)
            
        db.commit()
        print("✅ Added today's readings for ALL profiles to the database.")
        
    finally:
        db.close()

if __name__ == "__main__":
    # --- IMPORTANT: CHANGE THIS TO YOUR PHONE NUMBER ---
    # Put your real number here to see the aggregated report
    TEST_PHONE = "+918700151250" 
    # ---------------------------------------------------
    
    # if TEST_PHONE == "+918700151250":
    #     print("❌ Error: Please edit 'test_whatsapp_report.py' and set your phone number in TEST_PHONE.")
    #     sys.exit(1)
        
    print(f"🚀 Setting up multi-profile test data for {TEST_PHONE}...")
    setup_multi_profile_test_data(TEST_PHONE)
    
    print("\n📩 Triggering Weekly WhatsApp report service for all users...")
    send_weekly_reports()
    
    print("\n🏁 Aggregated Weekly test complete. Check your WhatsApp!")
