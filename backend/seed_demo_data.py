"""
Seed script: creates 3 demo users with 45 days of realistic health readings.
Run: cd backend && source venv/bin/activate && python seed_demo_data.py
"""
import random
from datetime import datetime, timedelta
from database import SessionLocal, engine, Base
from auth import get_password_hash
import models

# Ensure tables exist
Base.metadata.create_all(bind=engine)

db = SessionLocal()

# ── Demo user profiles ─────────────────────────────────────────────────────

DEMO_USERS = [
    {
        "email": "ramesh@demo.swasth.app",
        "password": "Demo@1234",
        "full_name": "Ramesh Kumar",
        "phone": "9876500001",
        "profile_name": "Ramesh",
        "age": 58,
        "gender": "Male",
        "conditions": ["Diabetes", "Hypertension"],
        "medications": "Metformin 500mg, Amlodipine 5mg",
        "doctor_name": "Dr. Jaya Sharma",
        "doctor_specialty": "General Physician",
        "doctor_whatsapp": "919876543210",
        # Glucose: poorly controlled diabetic, 140-260 range with some normal days
        "glucose_base": 180, "glucose_var": 60,
        # BP: stage 1 hypertension, 128-155 / 82-98
        "sys_base": 142, "sys_var": 15, "dia_base": 88, "dia_var": 8,
    },
    {
        "email": "sunita@demo.swasth.app",
        "password": "Demo@1234",
        "full_name": "Sunita Devi",
        "phone": "9876500002",
        "profile_name": "Sunita",
        "age": 45,
        "gender": "Female",
        "conditions": ["Diabetes"],
        "medications": "Glimepiride 2mg",
        "doctor_name": "Dr. Kavita Singh",
        "doctor_specialty": "Endocrinologist",
        "doctor_whatsapp": "919876543211",
        # Glucose: moderately controlled, 90-180 range, improving trend
        "glucose_base": 135, "glucose_var": 35,
        # BP: mostly normal, occasional elevated
        "sys_base": 122, "sys_var": 10, "dia_base": 78, "dia_var": 6,
    },
    {
        "email": "arjun@demo.swasth.app",
        "password": "Demo@1234",
        "full_name": "Arjun Prasad",
        "phone": "9876500003",
        "profile_name": "Arjun",
        "age": 34,
        "gender": "Male",
        "conditions": [],
        "medications": None,
        "doctor_name": "Dr. Jaya Sharma",
        "doctor_specialty": "General Physician",
        "doctor_whatsapp": "919876543210",
        # Glucose: healthy, 75-120 range
        "glucose_base": 95, "glucose_var": 20,
        # BP: healthy, 110-125 / 70-80
        "sys_base": 118, "sys_var": 8, "dia_base": 74, "dia_var": 5,
    },
]

DAYS = 45  # days of historical data


def glucose_status(v):
    if v < 70: return "LOW"
    if v <= 130: return "NORMAL"
    if v <= 180: return "HIGH"
    return "CRITICAL"


def bp_status(sys, dia):
    if sys > 140 or dia > 90: return "HIGH - STAGE 2"
    if sys > 131 or dia > 86: return "HIGH - STAGE 1"
    if sys < 90 or dia < 60: return "LOW"
    return "NORMAL"


def create_user_with_data(u):
    # Check if user already exists
    existing = db.query(models.User).filter(models.User.email == u["email"]).first()
    if existing:
        print(f"  ⏭  {u['email']} already exists, skipping")
        return

    # Create user
    user = models.User(
        email=u["email"],
        password_hash=get_password_hash(u["password"]),
        full_name=u["full_name"],
        phone_number=u["phone"],
        consent_timestamp=datetime.utcnow(),
        consent_app_version="1.0.0",
        consent_language="en",
    )
    db.add(user)
    db.flush()

    # Create profile
    profile = models.Profile(
        name=u["profile_name"],
        age=u["age"],
        gender=u["gender"],
        medical_conditions=u["conditions"] if u["conditions"] else None,
        current_medications=u["medications"],
        doctor_name=u["doctor_name"],
        doctor_specialty=u["doctor_specialty"],
        doctor_whatsapp=u["doctor_whatsapp"],
        phone_number=u["phone"],
    )
    db.add(profile)
    db.flush()

    # Grant owner access
    access = models.ProfileAccess(
        user_id=user.id,
        profile_id=profile.id,
        access_level="owner",
    )
    db.add(access)
    db.flush()

    print(f"  ✓ Created user {u['email']} (id={user.id}, profile={profile.id})")

    # Generate readings for each day
    now = datetime.utcnow()
    readings_count = 0

    for day_offset in range(DAYS, 0, -1):
        day = now - timedelta(days=day_offset)

        # Some days have no readings (simulates missed days)
        if random.random() < 0.12:
            continue

        # Trend: values improve slightly over time for Sunita
        trend_factor = 1.0
        if "improving" not in u.get("notes", ""):
            trend_factor = 1 - (day_offset / DAYS) * 0.08  # slight improvement

        # ── Glucose reading (morning fasting, 6-8 AM) ──────────────
        hour = random.randint(6, 8)
        ts = day.replace(hour=hour, minute=random.randint(0, 59))

        glucose_val = round(
            u["glucose_base"] * trend_factor + random.uniform(-u["glucose_var"], u["glucose_var"]),
            1,
        )
        glucose_val = max(40, min(glucose_val, 400))  # clamp
        status_g = glucose_status(glucose_val)

        meal_notes = random.choice([
            "Fasting", "Fasting", "Fasting",  # mostly fasting
            "Before breakfast", "After tea",
        ])

        reading_g = models.HealthReading(
            profile_id=profile.id,
            logged_by=user.id,
            reading_type="glucose",
            glucose_value=glucose_val,
            glucose_unit="mg/dL",
            sample_type="Fasting",
            value_numeric=glucose_val,
            unit_display="mg/dL",
            status_flag=status_g,
            notes=meal_notes,
            reading_timestamp=ts,
        )
        db.add(reading_g)
        readings_count += 1

        # Some days have a second glucose reading (post-meal)
        if random.random() < 0.35:
            ts2 = day.replace(hour=random.randint(13, 15), minute=random.randint(0, 59))
            post_meal = round(glucose_val + random.uniform(20, 60), 1)
            post_meal = min(post_meal, 400)
            reading_g2 = models.HealthReading(
                profile_id=profile.id,
                logged_by=user.id,
                reading_type="glucose",
                glucose_value=post_meal,
                glucose_unit="mg/dL",
                sample_type="Post-meal",
                value_numeric=post_meal,
                unit_display="mg/dL",
                status_flag=glucose_status(post_meal),
                notes="After lunch",
                reading_timestamp=ts2,
            )
            db.add(reading_g2)
            readings_count += 1

        # ── BP reading (evening, 6-9 PM) ───────────────────────────
        # Not every day has BP — ~70% chance
        if random.random() < 0.70:
            hour_bp = random.randint(18, 21)
            ts_bp = day.replace(hour=hour_bp, minute=random.randint(0, 59))

            sys_val = round(u["sys_base"] * trend_factor + random.uniform(-u["sys_var"], u["sys_var"]))
            dia_val = round(u["dia_base"] * trend_factor + random.uniform(-u["dia_var"], u["dia_var"]))
            pulse = random.randint(62, 92)
            sys_val = max(80, min(sys_val, 200))
            dia_val = max(50, min(dia_val, 130))
            status_bp = bp_status(sys_val, dia_val)

            reading_bp = models.HealthReading(
                profile_id=profile.id,
                logged_by=user.id,
                reading_type="blood_pressure",
                systolic=float(sys_val),
                diastolic=float(dia_val),
                pulse_rate=float(pulse),
                bp_unit="mmHg",
                bp_status=status_bp,
                value_numeric=float(sys_val),
                unit_display="mmHg",
                status_flag=status_bp,
                notes=None,
                reading_timestamp=ts_bp,
            )
            db.add(reading_bp)
            readings_count += 1

    db.commit()
    print(f"    → {readings_count} readings over {DAYS} days")


# ── Main ────────────────────────────────────────────────────────────────────

print("Seeding demo data...")
print()

for u in DEMO_USERS:
    create_user_with_data(u)

print()
print("Done! Demo credentials (password: Demo@1234):")
print("  1. ramesh@demo.swasth.app  — Diabetic + Hypertensive (58M)")
print("  2. sunita@demo.swasth.app  — Diabetic, improving (45F)")
print("  3. arjun@demo.swasth.app   — Healthy young adult (34M)")

db.close()
