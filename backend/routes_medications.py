"""Medication intake API (NUO-127).

Patient logs medicines they've taken. Doctor sees them in the patient
summary + report. This is *taken intake*, not a prescription tracker.
"""
import os
import logging
from datetime import datetime, timedelta, timezone
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, UploadFile, status
from slowapi import Limiter
from slowapi.util import get_remote_address
from sqlalchemy.orm import Session

from config import settings
import models
import schemas
from database import get_db
from dependencies import get_current_user, get_profile_access_or_403, get_profile_editor_or_403, require_india_writer
from medication_photo_storage import delete_medication_photo, load_medication_photo, save_medication_photo

logger = logging.getLogger(__name__)

_enabled = os.environ.get("TESTING", "").lower() != "true"
limiter = Limiter(key_func=get_remote_address, enabled=_enabled)

router = APIRouter()


def _doctor_has_profile_access(profile_id: int, doctor_id: int, db: Session) -> bool:
    link = (
        db.query(models.DoctorPatientLink)
        .filter(
            models.DoctorPatientLink.profile_id == profile_id,
            models.DoctorPatientLink.doctor_id == doctor_id,
            models.DoctorPatientLink.status == "active",
            models.DoctorPatientLink.is_active.is_(True),
        )
        .first()
    )
    return link is not None


def _assert_photo_read_access(med: models.Medication, user: models.User, db: Session) -> None:
    if user.role == models.UserRole.doctor:
        if not _doctor_has_profile_access(med.profile_id, user.id, db):
            raise HTTPException(status_code=403, detail="No access to this profile")
        return
    get_profile_access_or_403(med.profile_id, user, db)


async def _read_valid_photo_or_422(photo: UploadFile) -> tuple[bytes, str]:
    mime = photo.content_type or ""
    if mime not in settings.ALLOWED_IMAGE_MIME_TYPES:
        raise HTTPException(
            status_code=422,
            detail=f"Unsupported image type. Allowed: {', '.join(settings.ALLOWED_IMAGE_MIME_TYPES)}",
        )
    content = await photo.read()
    if not content:
        raise HTTPException(status_code=422, detail="Medication photo is empty")
    if len(content) > settings.MAX_UPLOAD_SIZE_BYTES:
        max_mb = settings.MAX_UPLOAD_SIZE_BYTES // (1024 * 1024)
        raise HTTPException(status_code=422, detail=f"Medication photo exceeds {max_mb} MB")
    return content, mime


@router.post("/medications", status_code=status.HTTP_201_CREATED, response_model=schemas.MedicationResponse)
@limiter.limit("30/minute")
async def create_medication(
    request: Request,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
    _region: dict = Depends(require_india_writer),
):
    """Log a medicine that the patient has taken.

    NUO-135: writes are gated to India IPs (with locale fallback).
    """
    content_type = (request.headers.get("content-type") or "").lower()
    photo: UploadFile | None = None
    if content_type.startswith("multipart/form-data"):
        form = await request.form()
        raw = {
            "profile_id": form.get("profile_id"),
            "name": form.get("name"),
            "dose": form.get("dose"),
            "frequency": form.get("frequency"),
            "intake_period": form.get("intake_period"),
            "taken_at": form.get("taken_at"),
            "notes": form.get("notes"),
        }
        maybe_photo = form.get("photo")
        if getattr(maybe_photo, "filename", None) is not None and hasattr(maybe_photo, "read"):
            photo = maybe_photo
    else:
        raw = await request.json()
    payload = schemas.MedicationCreate.model_validate(raw)
    get_profile_editor_or_403(payload.profile_id, user, db)

    med = models.Medication(
        profile_id=payload.profile_id,
        logged_by=user.id,
        name=payload.name.strip(),
        dose=(payload.dose or "").strip() or None,
        frequency=(payload.frequency or "").strip() or None,
        intake_period=payload.intake_period,
        taken_at=payload.taken_at,
        notes=(payload.notes or "").strip() or None,
    )
    db.add(med)
    db.flush()

    if photo is not None:
        image_bytes, mime_type = await _read_valid_photo_or_422(photo)
        med.photo_path = save_medication_photo(
            profile_id=med.profile_id,
            medication_id=med.id,
            image_bytes=image_bytes,
            mime_type=mime_type,
        )
        med.has_photo = True

    db.commit()
    db.refresh(med)
    return schemas.MedicationResponse.model_validate(med)


@router.get("/medications", response_model=List[schemas.MedicationResponse])
@limiter.limit("30/minute")
async def list_medications(
    request: Request,
    profile_id: int = Query(...),
    days: int = Query(30, ge=1, le=365),
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """List medications taken by the patient in the recent window."""
    get_profile_access_or_403(profile_id, user, db)

    since = datetime.now(timezone.utc) - timedelta(days=days)
    meds = (
        db.query(models.Medication)
        .filter(
            models.Medication.profile_id == profile_id,
            models.Medication.taken_at >= since,
        )
        .order_by(models.Medication.taken_at.desc())
        # Safety cap: days can reach 365 and a daily-logging patient
        # accumulates 1000+ rows/year, each decrypted via the AES-GCM ORM
        # getter. Bound the response (doctor route already caps at 200).
        # Switch to cursor pagination if demand grows past this.
        .limit(500)
        .all()
    )
    return [schemas.MedicationResponse.model_validate(m) for m in meds]


@router.get("/medications/{med_id}/photo")
@limiter.limit("60/minute")
async def get_medication_photo(
    request: Request,
    med_id: int,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    med = db.query(models.Medication).filter(models.Medication.id == med_id).first()
    if not med:
        raise HTTPException(status_code=404, detail="Medication not found")
    _assert_photo_read_access(med, user, db)
    if not med.has_photo or not med.photo_path:
        raise HTTPException(status_code=404, detail="Medication photo not found")
    try:
        image_bytes, mime_type = load_medication_photo(med.photo_path)
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail="Medication photo not found")
    except Exception:
        raise HTTPException(status_code=500, detail="Unable to load medication photo")
    return Response(content=image_bytes, media_type=mime_type)


@router.patch("/medications/{med_id}", response_model=schemas.MedicationResponse)
@limiter.limit("30/minute")
async def update_medication(
    request: Request,
    med_id: int,
    data: schemas.MedicationUpdate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
    _region: dict = Depends(require_india_writer),
):
    """Edit a logged medication (patient correcting an entry)."""
    med = db.query(models.Medication).filter(models.Medication.id == med_id).first()
    if not med:
        raise HTTPException(status_code=404, detail="Medication not found")
    # IDOR hardening (OWASP A01): hide existence from callers with NO access
    # to the profile, so sequential med IDs can't be enumerated by telling
    # 403 (exists, someone else's) from 404 (absent). A viewer (has read
    # access but isn't an editor) already sees the row via GET, so they
    # correctly keep getting 403 — that leaks nothing — rather than a 404.
    try:
        get_profile_editor_or_403(med.profile_id, user, db)
    except HTTPException:
        try:
            get_profile_access_or_403(med.profile_id, user, db)
        except HTTPException:
            raise HTTPException(status_code=404, detail="Medication not found")
        raise

    if data.name is not None:
        med.name = data.name.strip()
    if data.dose is not None:
        med.dose = data.dose.strip() or None
    if data.frequency is not None:
        med.frequency = data.frequency.strip() or None
    if data.intake_period is not None:
        med.intake_period = data.intake_period
    if data.taken_at is not None:
        med.taken_at = data.taken_at
    if data.notes is not None:
        med.notes = data.notes.strip() or None

    db.commit()
    db.refresh(med)
    return schemas.MedicationResponse.model_validate(med)


@router.delete("/medications/{med_id}", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit("30/minute")
async def delete_medication(
    request: Request,
    med_id: int,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
    _region: dict = Depends(require_india_writer),
):
    """Delete a medication entry."""
    med = db.query(models.Medication).filter(models.Medication.id == med_id).first()
    if not med:
        raise HTTPException(status_code=404, detail="Medication not found")
    # IDOR hardening (OWASP A01): hide existence from callers with NO access
    # to the profile, so sequential med IDs can't be enumerated by telling
    # 403 (exists, someone else's) from 404 (absent). A viewer (has read
    # access but isn't an editor) already sees the row via GET, so they
    # correctly keep getting 403 — that leaks nothing — rather than a 404.
    try:
        get_profile_editor_or_403(med.profile_id, user, db)
    except HTTPException:
        try:
            get_profile_access_or_403(med.profile_id, user, db)
        except HTTPException:
            raise HTTPException(status_code=404, detail="Medication not found")
        raise

    db.delete(med)
    db.commit()
    delete_medication_photo(med.photo_path)
    return None
