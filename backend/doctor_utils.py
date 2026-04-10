"""Shared helpers for the doctor portal.

Lives in its own module so that both routes_doctor.py and routes_admin.py
can import the same implementation without a circular import.
"""
import random
import string

from sqlalchemy.orm import Session

import models


def _doctor_code_candidate(full_name: str) -> str:
    """Generate one candidate doctor code from a full name.

    Format: DR + 3 letters (uppercased, padded with X) + 2 random digits.
    random (not secrets) is correct here — doctor_code is a public
    shareable identifier, not an auth secret. Collisions are handled by
    uniqueness constraint + retry in ensure_unique_doctor_code.
    """
    letters = "".join(c for c in full_name.upper() if c.isalpha())
    prefix = letters[:3] if len(letters) >= 3 else letters.ljust(3, "X")
    digits = "".join(random.choices(string.digits, k=2))
    return f"DR{prefix}{digits}"


def ensure_unique_doctor_code(db: Session, full_name: str) -> str:
    """Return a DoctorProfile.doctor_code that's guaranteed unique at the
    point of query.

    Tries the name-prefixed format first (DRRAJ52 style). If 20 collisions
    happen, falls back to a longer random suffix and retries 10 more times.
    Both stages check uniqueness against the DB before returning. Raises
    RuntimeError on the extraordinarily unlikely event that all 30 tries
    collide.
    """
    for _ in range(20):
        code = _doctor_code_candidate(full_name)
        if not db.query(models.DoctorProfile).filter(
            models.DoctorProfile.doctor_code == code,
        ).first():
            return code

    for _ in range(10):
        suffix = "".join(random.choices(string.ascii_uppercase + string.digits, k=5))
        code = f"DR{suffix}"
        if not db.query(models.DoctorProfile).filter(
            models.DoctorProfile.doctor_code == code,
        ).first():
            return code

    raise RuntimeError("Unable to generate unique doctor code after 30 attempts")
