"""Doctor Portal API routes (Module E).

All doctor-specific endpoints live here. This file NEVER imports from
routes_chat.py — doctor access to patient data is deliberately scoped
to readings, trends, and profile info (not AI chat history).
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func, case, and_
from datetime import datetime, timezone, timedelta
import logging

import models
import schemas
import auth
from database import get_db
from dependencies import get_current_user, get_doctor_patient_access, get_profile_access_or_403
from doctor_utils import ensure_unique_doctor_code
from models import UserRole

logger = logging.getLogger(__name__)
router = APIRouter()


def _log_doctor_access(db: Session, doctor_id: int, profile_id: int, action: str, endpoint: str = None):
    """Record doctor data access for DPDPA audit trail."""
    log = models.DoctorAccessLog(
        doctor_id=doctor_id,
        profile_id=profile_id,
        action=action,
        endpoint=endpoint,
    )
    db.add(log)


def _compute_triage_status(profile_id: int, db: Session) -> dict:
    """Compute triage status for a patient profile.

    Returns dict with: triage_status, last_reading_value, last_reading_type,
    last_reading_at, compliance_7d, trend_direction.
    """
    now = datetime.now(timezone.utc)
    day_ago = now - timedelta(hours=24)
    week_ago = now - timedelta(days=7)

    # Last reading
    last_reading = (
        db.query(models.HealthReading)
        .filter(models.HealthReading.profile_id == profile_id)
        .order_by(models.HealthReading.reading_timestamp.desc())
        .first()
    )

    if not last_reading:
        return {
            "triage_status": "no_data",
            "last_reading_value": None,
            "last_reading_type": None,
            "last_reading_at": None,
            "compliance_7d": 0,
            "trend_direction": None,
        }

    # Format last reading value
    if last_reading.reading_type == "blood_pressure":
        last_value = f"{int(last_reading.systolic)}/{int(last_reading.diastolic)}"
    elif last_reading.reading_type == "glucose":
        last_value = str(int(last_reading.glucose_value))
    else:
        last_value = str(last_reading.value_numeric)

    # Check for critical readings in last 24 hours
    recent_readings = (
        db.query(models.HealthReading)
        .filter(
            models.HealthReading.profile_id == profile_id,
            models.HealthReading.reading_timestamp >= day_ago,
        )
        .all()
    )

    triage_status = "stable"
    triage_reason = None

    for r in recent_readings:
        if r.reading_type == "blood_pressure" and r.systolic and r.diastolic:
            if r.systolic > 180 or r.diastolic > 120:
                triage_status = "critical"
                triage_reason = f"BP {int(r.systolic)}/{int(r.diastolic)} — hypertensive crisis"
                break
            if r.systolic < 90 or r.diastolic < 60:
                triage_status = "critical"
                triage_reason = f"BP {int(r.systolic)}/{int(r.diastolic)} — hypotension"
                break
        if r.reading_type == "glucose" and r.glucose_value:
            if r.glucose_value < 70:
                triage_status = "critical"
                triage_reason = f"Glucose {int(r.glucose_value)} — hypoglycemia"
                break
            if r.glucose_value > 300:
                triage_status = "critical"
                triage_reason = f"Glucose {int(r.glucose_value)} — severe hyperglycemia"
                break

    # Check for attention-level issues
    if triage_status != "critical":
        # Non-compliance: no reading in 3+ days
        if last_reading.reading_timestamp:
            last_ts = last_reading.reading_timestamp
            if last_ts.tzinfo is None:
                last_ts = last_ts.replace(tzinfo=timezone.utc)
            days_since = (now - last_ts).days
            if days_since >= 3:
                triage_status = "attention"
                triage_reason = f"No reading for {days_since}d"

        # Check for elevated readings in last 24h
        for r in recent_readings:
            if r.reading_type == "blood_pressure" and r.systolic:
                if r.systolic > 140 or r.diastolic > 90:
                    triage_status = "attention"
                    triage_reason = f"BP elevated {int(r.systolic)}/{int(r.diastolic)}"
                    break
            if r.reading_type == "glucose" and r.glucose_value:
                if r.glucose_value > 180:
                    triage_status = "attention"
                    triage_reason = f"Glucose high {int(r.glucose_value)}"
                    break

    # Compliance: count unique days with readings in last 7 days
    compliance_7d = (
        db.query(func.count(func.distinct(func.date(models.HealthReading.reading_timestamp))))
        .filter(
            models.HealthReading.profile_id == profile_id,
            models.HealthReading.reading_timestamp >= week_ago,
        )
        .scalar()
    ) or 0

    # Trend direction (simplified)
    trend_direction = "stable"
    week_readings = (
        db.query(models.HealthReading)
        .filter(
            models.HealthReading.profile_id == profile_id,
            models.HealthReading.reading_timestamp >= week_ago,
            models.HealthReading.reading_type.in_(["glucose", "blood_pressure"]),
        )
        .order_by(models.HealthReading.reading_timestamp.asc())
        .all()
    )
    if len(week_readings) >= 3:
        # Compare first half average to second half
        mid = len(week_readings) // 2
        first_half = week_readings[:mid]
        second_half = week_readings[mid:]

        def avg_value(readings):
            vals = []
            for r in readings:
                if r.reading_type == "glucose" and r.glucose_value:
                    vals.append(r.glucose_value)
                elif r.reading_type == "blood_pressure" and r.systolic:
                    vals.append(r.systolic)
            return sum(vals) / len(vals) if vals else 0

        avg_first = avg_value(first_half)
        avg_second = avg_value(second_half)
        if avg_first > 0:
            change = (avg_second - avg_first) / avg_first
            if change > 0.05:
                trend_direction = "worsening"
            elif change < -0.05:
                trend_direction = "improving"

    return {
        "triage_status": triage_status,
        "triage_reason": triage_reason,
        "last_reading_value": last_value,
        "last_reading_type": last_reading.reading_type,
        "last_reading_at": last_reading.reading_timestamp,
        "compliance_7d": compliance_7d,
        "trend_direction": trend_direction,
    }


# ---------------------------------------------------------------------------
# Doctor Registration
# ---------------------------------------------------------------------------

@router.post("/register", response_model=schemas.DoctorProfileResponse, status_code=status.HTTP_201_CREATED)
def register_doctor(data: schemas.DoctorRegister, db: Session = Depends(get_db)):
    """Register a new doctor account.

    Creates a User with role=doctor and a DoctorProfile with NMC number.
    Doctor must be verified by admin before accessing patient data.
    """
    # Check email uniqueness
    if db.query(models.User).filter(models.User.email == data.email).first():
        raise HTTPException(status_code=400, detail="Email already registered")

    # Check NMC uniqueness
    if db.query(models.DoctorProfile).filter(models.DoctorProfile.nmc_number == data.nmc_number).first():
        raise HTTPException(status_code=400, detail="NMC number already registered")

    # Create user
    now_utc = datetime.now(timezone.utc)
    user = models.User(
        email=data.email,
        password_hash=auth.get_password_hash(data.password),
        full_name=data.full_name,
        phone_number=data.phone_number,
        role=UserRole.doctor,
        timezone=data.timezone,
        created_at=now_utc,
        updated_at=now_utc,
    )
    db.add(user)
    db.flush()

    # Generate unique doctor code
    doctor_code = ensure_unique_doctor_code(db, data.full_name)

    # Create doctor profile
    doctor_profile = models.DoctorProfile(
        user_id=user.id,
        nmc_number=data.nmc_number,
        specialty=data.specialty,
        clinic_name=data.clinic_name,
        doctor_code=doctor_code,
    )
    db.add(doctor_profile)
    db.commit()
    db.refresh(doctor_profile)
    db.refresh(user)

    return schemas.DoctorProfileResponse(
        user_id=user.id,
        full_name=user.full_name,
        nmc_number=doctor_profile.nmc_number,
        specialty=doctor_profile.specialty,
        clinic_name=doctor_profile.clinic_name,
        doctor_code=doctor_profile.doctor_code,
        is_verified=doctor_profile.is_verified,
        created_at=doctor_profile.created_at or now_utc,
    )


@router.get("/me", response_model=schemas.DoctorProfileResponse)
def get_doctor_profile(
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get the current doctor's profile."""
    if user.role != UserRole.doctor:
        raise HTTPException(status_code=403, detail="Not a doctor account")
    dp = db.query(models.DoctorProfile).filter(models.DoctorProfile.user_id == user.id).first()
    if not dp:
        raise HTTPException(status_code=404, detail="Doctor profile not found")
    return schemas.DoctorProfileResponse(
        user_id=user.id,
        full_name=user.full_name,
        nmc_number=dp.nmc_number,
        specialty=dp.specialty,
        clinic_name=dp.clinic_name,
        doctor_code=dp.doctor_code,
        is_verified=dp.is_verified,
        created_at=dp.created_at,
    )


# ---------------------------------------------------------------------------
# Doctor Code Lookup (called by patient app)
# ---------------------------------------------------------------------------

@router.get("/lookup/{doctor_code}", response_model=schemas.DoctorCodeLookupResponse)
def lookup_doctor_code(
    doctor_code: str,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Patient looks up a doctor by their code before linking."""
    dp = db.query(models.DoctorProfile).filter(
        models.DoctorProfile.doctor_code == doctor_code.upper()
    ).first()
    if not dp:
        raise HTTPException(status_code=404, detail="Doctor code not found")

    doctor_user = db.query(models.User).filter(models.User.id == dp.user_id).first()
    return schemas.DoctorCodeLookupResponse(
        doctor_name=doctor_user.full_name,
        specialty=dp.specialty,
        clinic_name=dp.clinic_name,
        doctor_code=dp.doctor_code,
        is_verified=dp.is_verified,
    )


# ---------------------------------------------------------------------------
# Doctor-Patient Linking (consent flow)
# ---------------------------------------------------------------------------

@router.post("/link/{profile_id}", response_model=schemas.DoctorPatientLinkResponse, status_code=status.HTTP_201_CREATED)
def link_doctor_to_patient(
    profile_id: int,
    data: schemas.DoctorPatientLinkRequest,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Patient (or family member with editor access) links a profile to a doctor.

    Requires the doctor code and consent type (in_person_exam or video_consult).
    """
    # Verify user has editor/owner access to this profile
    access = get_profile_access_or_403(profile_id, user, db)
    if access.access_level not in ("owner", "editor"):
        raise HTTPException(status_code=403, detail="Need owner or editor access to link a doctor")

    # Look up doctor
    dp = db.query(models.DoctorProfile).filter(
        models.DoctorProfile.doctor_code == data.doctor_code.upper()
    ).first()
    if not dp:
        raise HTTPException(status_code=404, detail="Doctor code not found")

    # NMC 2020 § 5.2 + Consumer Protection Act 2019: the platform must
    # not facilitate a telemedicine relationship with a doctor whose
    # credentials have not been verified. The UI shows a "Verification
    # pending" badge on lookup — this is the hard gate that keeps
    # unverified doctors from actually receiving PHI.
    if not dp.is_verified:
        raise HTTPException(
            status_code=403,
            detail=(
                "This doctor is not yet verified by Swasth. "
                "Please try again after verification is complete."
            ),
        )

    doctor_user = db.query(models.User).filter(models.User.id == dp.user_id).first()

    # Check if link already exists
    existing = db.query(models.DoctorPatientLink).filter(
        models.DoctorPatientLink.doctor_id == dp.user_id,
        models.DoctorPatientLink.profile_id == profile_id,
    ).first()

    if existing and existing.is_active:
        raise HTTPException(status_code=400, detail="Already linked to this doctor")

    # Reactivate revoked link or create new
    if existing:
        existing.is_active = True
        existing.revoked_at = None
        existing.consent_granted_at = datetime.now(timezone.utc)
        existing.consent_granted_by = user.id
        existing.consent_type = data.consent_type
        existing.doctor_code_used = data.doctor_code.upper()
        db.flush()
        link = existing
    else:
        link = models.DoctorPatientLink(
            doctor_id=dp.user_id,
            profile_id=profile_id,
            consent_granted_at=datetime.now(timezone.utc),
            consent_granted_by=user.id,
            consent_type=data.consent_type,
            doctor_code_used=data.doctor_code.upper(),
        )
        db.add(link)
        db.flush()

    # Compute initial triage
    triage = _compute_triage_status(profile_id, db)
    link.triage_status = triage["triage_status"]
    link.last_reading_value = triage["last_reading_value"]
    link.last_reading_type = triage["last_reading_type"]
    link.last_reading_at = triage["last_reading_at"]
    link.compliance_7d = triage["compliance_7d"]
    link.trend_direction = triage["trend_direction"]
    link.triage_updated_at = datetime.now(timezone.utc)

    db.commit()
    db.refresh(link)

    profile = db.query(models.Profile).filter(models.Profile.id == profile_id).first()

    return schemas.DoctorPatientLinkResponse(
        id=link.id,
        doctor_id=dp.user_id,
        doctor_name=doctor_user.full_name,
        profile_id=profile_id,
        profile_name=profile.name if profile else "Unknown",
        consent_type=link.consent_type,
        is_active=link.is_active,
        created_at=link.created_at,
    )


@router.delete("/link/{profile_id}")
def revoke_doctor_link(
    profile_id: int,
    doctor_code: str,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Patient revokes doctor access to their profile."""
    access = get_profile_access_or_403(profile_id, user, db)
    if access.access_level not in ("owner", "editor"):
        raise HTTPException(status_code=403, detail="Need owner or editor access")

    dp = db.query(models.DoctorProfile).filter(
        models.DoctorProfile.doctor_code == doctor_code.upper()
    ).first()
    if not dp:
        raise HTTPException(status_code=404, detail="Doctor code not found")

    link = db.query(models.DoctorPatientLink).filter(
        models.DoctorPatientLink.doctor_id == dp.user_id,
        models.DoctorPatientLink.profile_id == profile_id,
        models.DoctorPatientLink.is_active == True,  # noqa: E712
    ).first()
    if not link:
        raise HTTPException(status_code=404, detail="No active link found")

    link.is_active = False
    link.revoked_at = datetime.now(timezone.utc)
    db.commit()

    return {"detail": "Doctor access revoked"}


@router.get("/link/{profile_id}", response_model=list)
def list_linked_doctors(
    profile_id: int,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """List all doctors linked to a patient profile (for patient app)."""
    get_profile_access_or_403(profile_id, user, db)

    links = (
        db.query(models.DoctorPatientLink, models.DoctorProfile, models.User)
        .join(models.DoctorProfile, models.DoctorProfile.user_id == models.DoctorPatientLink.doctor_id)
        .join(models.User, models.User.id == models.DoctorPatientLink.doctor_id)
        .filter(
            models.DoctorPatientLink.profile_id == profile_id,
            models.DoctorPatientLink.is_active == True,  # noqa: E712
        )
        .all()
    )

    return [
        {
            "doctor_name": u.full_name,
            "specialty": dp.specialty,
            "doctor_code": dp.doctor_code,
            "is_verified": dp.is_verified,
            "linked_since": link.consent_granted_at,
        }
        for link, dp, u in links
    ]


@router.get("/known-doctors")
def list_known_doctors(
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Return deduped verified doctors linked to any profile the user owns.

    Powers the LinkDoctor picker — instead of asking the patient to type
    a code, show a dropdown of doctors they already interact with across
    their own + family profiles. Only active links count; revoked links
    are excluded so a doctor the patient has already stopped sharing
    with doesn't reappear in the picker.

    Response shape:
      [
        {
          "doctor_name": "Dr. Rajesh Verma",
          "specialty": "General Physician",
          "clinic_name": "Patna Clinic",
          "doctor_code": "DRRAJ52",
          "is_verified": true,
          "linked_profile_ids": [1, 3]   # profiles the user owns that
                                         # are already linked to this doctor
        }
      ]
    """
    # Profiles the user owns (family sharing with editor/viewer access
    # is intentionally excluded — those aren't "their" doctors).
    owned_profile_ids = [
        row[0]
        for row in db.query(models.ProfileAccess.profile_id)
        .filter(
            models.ProfileAccess.user_id == user.id,
            models.ProfileAccess.access_level == "owner",
        )
        .all()
    ]
    if not owned_profile_ids:
        return []

    rows = (
        db.query(models.DoctorPatientLink, models.DoctorProfile, models.User)
        .join(
            models.DoctorProfile,
            models.DoctorProfile.user_id == models.DoctorPatientLink.doctor_id,
        )
        .join(models.User, models.User.id == models.DoctorPatientLink.doctor_id)
        .filter(
            models.DoctorPatientLink.profile_id.in_(owned_profile_ids),
            models.DoctorPatientLink.is_active == True,  # noqa: E712
        )
        .all()
    )

    # Dedupe by doctor_id; aggregate linked_profile_ids per doctor.
    by_doctor: dict[int, dict] = {}
    for link, dp, u in rows:
        entry = by_doctor.get(u.id)
        if entry is None:
            entry = {
                "doctor_name": u.full_name,
                "specialty": dp.specialty,
                "clinic_name": dp.clinic_name,
                "doctor_code": dp.doctor_code,
                "is_verified": dp.is_verified,
                "linked_profile_ids": [],
            }
            by_doctor[u.id] = entry
        if link.profile_id not in entry["linked_profile_ids"]:
            entry["linked_profile_ids"].append(link.profile_id)

    # Sort by doctor name for stable UI ordering.
    return sorted(by_doctor.values(), key=lambda d: (d["doctor_name"] or "").lower())


# ---------------------------------------------------------------------------
# Triage Dashboard (doctor view)
# ---------------------------------------------------------------------------

@router.get("/patients", response_model=list[schemas.TriagePatientCard])
def get_triage_board(
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get all linked patients sorted by triage status (critical first).

    This is the doctor's main dashboard view.
    """
    if user.role != UserRole.doctor:
        raise HTTPException(status_code=403, detail="Only doctors can access this")

    links = (
        db.query(models.DoctorPatientLink, models.Profile)
        .join(models.Profile, models.Profile.id == models.DoctorPatientLink.profile_id)
        .filter(
            models.DoctorPatientLink.doctor_id == user.id,
            models.DoctorPatientLink.is_active == True,  # noqa: E712
        )
        .all()
    )

    # Recompute triage live for every patient and update cache
    now = datetime.now(timezone.utc)
    triage_reasons = {}  # profile_id -> reason string
    for link, profile in links:
        triage = _compute_triage_status(profile.id, db)
        link.triage_status = triage["triage_status"]
        link.last_reading_value = triage["last_reading_value"]
        link.last_reading_type = triage["last_reading_type"]
        link.last_reading_at = triage["last_reading_at"]
        link.compliance_7d = triage["compliance_7d"]
        link.trend_direction = triage["trend_direction"]
        link.triage_updated_at = now
        triage_reasons[profile.id] = triage.get("triage_reason")

    _log_doctor_access(db, user.id, None, "viewed_triage_board", "/api/doctor/patients")
    db.commit()

    # Sort: critical first, then attention, then stable, then no_data
    status_order = {"critical": 1, "attention": 2, "stable": 3, "no_data": 4}
    sorted_links = sorted(
        links,
        key=lambda lp: (
            status_order.get(lp[0].triage_status or "no_data", 4),
            -(lp[0].last_reading_at.timestamp() if lp[0].last_reading_at else 0),
        ),
    )

    return [
        schemas.TriagePatientCard(
            profile_id=profile.id,
            profile_name=profile.name,
            age=profile.age,
            gender=profile.gender,
            medical_conditions=profile.medical_conditions,
            triage_status=link.triage_status or "no_data",
            triage_reason=triage_reasons.get(profile.id),
            last_reading_value=link.last_reading_value,
            last_reading_type=link.last_reading_type,
            last_reading_at=link.last_reading_at,
            compliance_7d=link.compliance_7d or 0,
            trend_direction=link.trend_direction,
            link_id=link.id,
        )
        for link, profile in sorted_links
    ]


# ---------------------------------------------------------------------------
# Patient Detail (doctor view)
# ---------------------------------------------------------------------------

@router.get("/patients/{profile_id}/readings")
def get_patient_readings(
    profile_id: int,
    days: int = 30,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get patient's health readings (doctor view). Max 90 days."""
    link = get_doctor_patient_access(profile_id, user, db)
    _log_doctor_access(db, user.id, profile_id, "viewed_readings", f"/api/doctor/patients/{profile_id}/readings")

    days = min(days, 90)
    since = datetime.now(timezone.utc) - timedelta(days=days)

    readings = (
        db.query(models.HealthReading)
        .filter(
            models.HealthReading.profile_id == profile_id,
            models.HealthReading.reading_timestamp >= since,
        )
        .order_by(models.HealthReading.reading_timestamp.desc())
        .limit(200)
        .all()
    )

    db.commit()

    return [
        {
            "id": r.id,
            "reading_type": r.reading_type,
            "glucose_value": r.glucose_value,
            "systolic": r.systolic,
            "diastolic": r.diastolic,
            "pulse_rate": r.pulse_rate,
            "spo2_value": r.spo2_value,
            "steps_count": r.steps_count,
            "value_numeric": r.value_numeric,
            "unit_display": r.unit_display,
            "status_flag": r.status_flag,
            "sample_type": r.sample_type,
            "notes": r.notes,
            "reading_timestamp": r.reading_timestamp,
            "created_at": r.created_at,
        }
        for r in readings
    ]


@router.get("/patients/{profile_id}/profile")
def get_patient_profile(
    profile_id: int,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get patient profile info (doctor view). Does NOT include AI chat data."""
    link = get_doctor_patient_access(profile_id, user, db)
    _log_doctor_access(db, user.id, profile_id, "viewed_profile", f"/api/doctor/patients/{profile_id}/profile")

    profile = db.query(models.Profile).filter(models.Profile.id == profile_id).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    db.commit()

    return {
        "id": profile.id,
        "name": profile.name,
        "age": profile.age,
        "gender": profile.gender,
        "height": profile.height,
        "weight": profile.weight,
        "blood_group": profile.blood_group,
        "medical_conditions": profile.medical_conditions,
        "current_medications": profile.current_medications,
        "bmi": round(profile.weight / ((profile.height / 100) ** 2), 1) if profile.weight and profile.height else None,
    }


@router.get("/patients/{profile_id}/summary")
def get_patient_summary(
    profile_id: int,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get quick stats summary for patient (7-day averages + compliance)."""
    link = get_doctor_patient_access(profile_id, user, db)
    _log_doctor_access(db, user.id, profile_id, "viewed_summary", f"/api/doctor/patients/{profile_id}/summary")

    week_ago = datetime.now(timezone.utc) - timedelta(days=7)

    readings = (
        db.query(models.HealthReading)
        .filter(
            models.HealthReading.profile_id == profile_id,
            models.HealthReading.reading_timestamp >= week_ago,
        )
        .all()
    )

    glucose_vals = [r.glucose_value for r in readings if r.reading_type == "glucose" and r.glucose_value]
    fasting_vals = [r.glucose_value for r in readings if r.reading_type == "glucose" and r.glucose_value and r.sample_type == "fasting"]
    postmeal_vals = [r.glucose_value for r in readings if r.reading_type == "glucose" and r.glucose_value and r.sample_type != "fasting"]
    systolic_vals = [r.systolic for r in readings if r.reading_type == "blood_pressure" and r.systolic]
    diastolic_vals = [r.diastolic for r in readings if r.reading_type == "blood_pressure" and r.diastolic]

    db.commit()

    return {
        "period_days": 7,
        "total_readings": len(readings),
        "compliance_7d": link.compliance_7d or 0,
        "glucose": {
            "avg": round(sum(glucose_vals) / len(glucose_vals), 1) if glucose_vals else None,
            "avg_fasting": round(sum(fasting_vals) / len(fasting_vals), 1) if fasting_vals else None,
            "avg_postmeal": round(sum(postmeal_vals) / len(postmeal_vals), 1) if postmeal_vals else None,
            "count": len(glucose_vals),
        },
        "bp": {
            "avg_systolic": round(sum(systolic_vals) / len(systolic_vals), 1) if systolic_vals else None,
            "avg_diastolic": round(sum(diastolic_vals) / len(diastolic_vals), 1) if diastolic_vals else None,
            "high_systolic": round(max(systolic_vals), 1) if systolic_vals else None,
            "low_systolic": round(min(systolic_vals), 1) if systolic_vals else None,
            "count": len(systolic_vals),
        },
        "triage_status": link.triage_status,
        "trend_direction": link.trend_direction,
    }


# ---------------------------------------------------------------------------
# Clinical Notes (doctor-private)
# ---------------------------------------------------------------------------

@router.post("/patients/{profile_id}/notes", response_model=schemas.DoctorNoteResponse, status_code=status.HTTP_201_CREATED)
def create_doctor_note(
    profile_id: int,
    data: schemas.DoctorNoteCreate,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Add a clinical note on a patient (optionally linked to a specific reading)."""
    link = get_doctor_patient_access(profile_id, user, db)

    # Validate reading belongs to this profile if specified
    if data.reading_id:
        reading = db.query(models.HealthReading).filter(
            models.HealthReading.id == data.reading_id,
            models.HealthReading.profile_id == profile_id,
        ).first()
        if not reading:
            raise HTTPException(status_code=404, detail="Reading not found for this profile")

    note = models.DoctorNote(
        doctor_id=user.id,
        profile_id=profile_id,
        reading_id=data.reading_id,
        note_text=data.note_text,
        is_shared_with_patient=data.is_shared_with_patient,
    )
    db.add(note)
    _log_doctor_access(db, user.id, profile_id, "added_note", f"/api/doctor/patients/{profile_id}/notes")
    db.commit()
    db.refresh(note)

    return schemas.DoctorNoteResponse(
        id=note.id,
        doctor_id=note.doctor_id,
        profile_id=note.profile_id,
        reading_id=note.reading_id,
        note_text=note.note_text,
        is_shared_with_patient=note.is_shared_with_patient,
        created_at=note.created_at,
        updated_at=note.updated_at,
    )


@router.get("/patients/{profile_id}/notes", response_model=list[schemas.DoctorNoteResponse])
def list_doctor_notes(
    profile_id: int,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """List all notes this doctor has made on a patient."""
    link = get_doctor_patient_access(profile_id, user, db)
    _log_doctor_access(db, user.id, profile_id, "viewed_notes", f"/api/doctor/patients/{profile_id}/notes")

    notes = (
        db.query(models.DoctorNote)
        .filter(
            models.DoctorNote.doctor_id == user.id,
            models.DoctorNote.profile_id == profile_id,
        )
        .order_by(models.DoctorNote.created_at.desc())
        .all()
    )
    db.commit()

    return [
        schemas.DoctorNoteResponse(
            id=n.id,
            doctor_id=n.doctor_id,
            profile_id=n.profile_id,
            reading_id=n.reading_id,
            note_text=n.note_text,
            is_shared_with_patient=n.is_shared_with_patient,
            created_at=n.created_at,
            updated_at=n.updated_at,
        )
        for n in notes
    ]


# ---------------------------------------------------------------------------
# Triage Refresh (called when a new reading is saved)
# ---------------------------------------------------------------------------

def refresh_triage_for_profile(profile_id: int, db: Session):
    """Recompute triage for all doctors linked to this profile.

    Called from routes_health.py when a new reading is saved.
    """
    links = (
        db.query(models.DoctorPatientLink)
        .filter(
            models.DoctorPatientLink.profile_id == profile_id,
            models.DoctorPatientLink.is_active == True,  # noqa: E712
        )
        .all()
    )
    if not links:
        return

    triage = _compute_triage_status(profile_id, db)
    for link in links:
        link.triage_status = triage["triage_status"]
        link.last_reading_value = triage["last_reading_value"]
        link.last_reading_type = triage["last_reading_type"]
        link.last_reading_at = triage["last_reading_at"]
        link.compliance_7d = triage["compliance_7d"]
        link.trend_direction = triage["trend_direction"]
        link.triage_updated_at = datetime.now(timezone.utc)


# ---------------------------------------------------------------------------
# Admin: Verify Doctor
# ---------------------------------------------------------------------------

@router.post("/verify/{doctor_id}")
def verify_doctor(
    doctor_id: int,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Admin verifies a doctor's NMC registration."""
    if not user.is_admin and user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="Admin only")

    dp = db.query(models.DoctorProfile).filter(models.DoctorProfile.user_id == doctor_id).first()
    if not dp:
        raise HTTPException(status_code=404, detail="Doctor profile not found")

    dp.is_verified = True
    dp.verified_at = datetime.now(timezone.utc)
    dp.verified_by = user.id
    db.commit()

    return {"detail": f"Doctor verified (NMC: {dp.nmc_number})"}


# ---------------------------------------------------------------------------
# Doctor Access Log (audit)
# ---------------------------------------------------------------------------

@router.get("/audit/{profile_id}")
def get_access_audit(
    profile_id: int,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get audit trail of doctor access to a patient's data.

    Accessible by: the patient (profile owner) or the doctor.
    """
    # Allow patient owner or the doctor themselves
    is_owner = db.query(models.ProfileAccess).filter(
        models.ProfileAccess.profile_id == profile_id,
        models.ProfileAccess.user_id == user.id,
        models.ProfileAccess.access_level == "owner",
    ).first()

    is_doctor_with_link = None
    if user.role == UserRole.doctor:
        is_doctor_with_link = db.query(models.DoctorPatientLink).filter(
            models.DoctorPatientLink.doctor_id == user.id,
            models.DoctorPatientLink.profile_id == profile_id,
        ).first()

    if not is_owner and not is_doctor_with_link:
        raise HTTPException(status_code=403, detail="Not authorized to view audit log")

    logs = (
        db.query(models.DoctorAccessLog, models.User)
        .join(models.User, models.User.id == models.DoctorAccessLog.doctor_id)
        .filter(models.DoctorAccessLog.profile_id == profile_id)
        .order_by(models.DoctorAccessLog.created_at.desc())
        .limit(100)
        .all()
    )

    return [
        {
            "doctor_name": u.full_name,
            "action": log.action,
            "endpoint": log.endpoint,
            "accessed_at": log.created_at,
        }
        for log, u in logs
    ]
