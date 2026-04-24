"""Seed Amit + test doctors after the 0006 destructive migration.

Run on the target DB server via:
    cd /var/www/swasth/backend && source venv/bin/activate && \
      python seeds/pii_seed.py

Requires ENCRYPTION_KEY and PII_ENCRYPTION_KEY to be set in env — the seed
writes through the ORM properties, so the keys must be configured.

Idempotent: if the user already exists (looked up by email_hash / nmc_hash),
skip insertion. Safe to re-run after the migration or at any later time.
"""
import os
import sys
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import SessionLocal
from auth import get_password_hash
from encryption_service import hash_email, hash_nmc
import models


AMIT = {
    "email": "amitkumarmishra@gmail.com",
    "password": "Test@1234",  # dev/pre-prod only; rotate on prod
    "full_name": "Amit Kumar",
    "phone_number": "+919876500000",
    "profile_name": "My Health",
    "timezone": "Asia/Kolkata",
}

TEST_DOCTORS = [
    {
        "email": "drjaya@test.swasth.app",
        "password": "Test@1234",
        "full_name": "Dr. Jaya Sharma",
        "phone_number": "+919876543210",
        "nmc_number": "KA12345",
        "specialty": "General Physician",
        "clinic_name": "Bangalore General Clinic",
        "doctor_code": "DRJAYA1",
        "whatsapp_number": "+919876543210",
    },
    {
        "email": "drkavita@test.swasth.app",
        "password": "Test@1234",
        "full_name": "Dr. Kavita Singh",
        "phone_number": "+919876543211",
        "nmc_number": "MH98765",
        "specialty": "Endocrinologist",
        "clinic_name": "Mumbai Endocrine Centre",
        "doctor_code": "DRKAVI1",
        "whatsapp_number": "+919876543211",
    },
]


def seed_amit(db):
    existing = db.query(models.User).filter(
        models.User.email_hash == hash_email(AMIT["email"])
    ).first()
    if existing:
        print(f"SKIP Amit — already exists (id={existing.id})")
        return existing

    now_utc = datetime.now(timezone.utc)
    user = models.User(
        email=AMIT["email"],
        password_hash=get_password_hash(AMIT["password"]),
        full_name=AMIT["full_name"],
        phone_number=AMIT["phone_number"],
        role=models.UserRole.patient,
        timezone=AMIT["timezone"],
        is_active=True,
        is_admin=True,  # Amit has admin access in dev/prod
        email_verified=True,
        email_verified_at=now_utc,
        consent_timestamp=now_utc,
        consent_app_version="pii-seed",
        consent_language="en",
        ai_consent=True,
        ai_consent_timestamp=now_utc,
    )
    db.add(user)
    db.flush()

    profile = models.Profile(
        name=AMIT["profile_name"],
        relationship="myself",
        gender="Male",
        phone_number=AMIT["phone_number"],
    )
    db.add(profile)
    db.flush()

    db.add(models.ProfileAccess(
        user_id=user.id,
        profile_id=profile.id,
        access_level="owner",
    ))
    db.commit()
    print(f"SEED Amit created (user_id={user.id}, profile_id={profile.id})")
    return user


def seed_doctor(db, doc):
    existing_user = db.query(models.User).filter(
        models.User.email_hash == hash_email(doc["email"])
    ).first()
    if existing_user:
        print(f"SKIP {doc['full_name']} — already exists (id={existing_user.id})")
        return existing_user

    existing_dp = db.query(models.DoctorProfile).filter(
        models.DoctorProfile.nmc_hash == hash_nmc(doc["nmc_number"])
    ).first()
    if existing_dp:
        print(f"SKIP {doc['full_name']} — NMC already taken (dp_id={existing_dp.id})")
        return None

    now_utc = datetime.now(timezone.utc)
    user = models.User(
        email=doc["email"],
        password_hash=get_password_hash(doc["password"]),
        full_name=doc["full_name"],
        phone_number=doc["phone_number"],
        role=models.UserRole.doctor,
        timezone="Asia/Kolkata",
        is_active=True,
        email_verified=True,
        email_verified_at=now_utc,
        consent_timestamp=now_utc,
        consent_app_version="pii-seed",
        consent_language="en",
        ai_consent=True,
        ai_consent_timestamp=now_utc,
    )
    db.add(user)
    db.flush()

    dp = models.DoctorProfile(
        user_id=user.id,
        nmc_number=doc["nmc_number"],
        specialty=doc["specialty"],
        clinic_name=doc["clinic_name"],
        doctor_code=doc["doctor_code"],
        phone_number=doc["phone_number"],
        whatsapp_number=doc["whatsapp_number"],
        is_verified=True,
        verified_at=now_utc,
    )
    db.add(dp)
    db.commit()
    print(f"SEED {doc['full_name']} created (user_id={user.id}, doctor_code={doc['doctor_code']})")
    return user


def main():
    if not os.environ.get("ENCRYPTION_KEY") or not os.environ.get("PII_ENCRYPTION_KEY"):
        print("ERROR: ENCRYPTION_KEY and PII_ENCRYPTION_KEY must be set. Refusing to seed.")
        sys.exit(1)

    db = SessionLocal()
    try:
        seed_amit(db)
        for doc in TEST_DOCTORS:
            seed_doctor(db, doc)
        print("DONE")
    finally:
        db.close()


if __name__ == "__main__":
    main()
