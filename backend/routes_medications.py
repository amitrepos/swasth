"""Medication intake API (NUO-127).

Patient logs medicines they've taken. Doctor sees them in the patient
summary + report. This is *taken intake*, not a prescription tracker.
"""
import os
import logging
from datetime import datetime, timedelta, timezone
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from slowapi import Limiter
from slowapi.util import get_remote_address
from sqlalchemy.orm import Session

import models
import schemas
from database import get_db
from dependencies import get_current_user, get_profile_access_or_403, get_profile_editor_or_403, require_india_writer

logger = logging.getLogger(__name__)

_enabled = os.environ.get("TESTING", "").lower() != "true"
limiter = Limiter(key_func=get_remote_address, enabled=_enabled)

router = APIRouter()


@router.post("/medications", status_code=status.HTTP_201_CREATED, response_model=schemas.MedicationResponse)
@limiter.limit("30/minute")
async def create_medication(
    request: Request,
    data: schemas.MedicationCreate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
    _region: dict = Depends(require_india_writer),
):
    """Log a medicine that the patient has taken.

    NUO-135: writes are gated to India IPs (with locale fallback).
    """
    get_profile_editor_or_403(data.profile_id, user, db)

    med = models.Medication(
        profile_id=data.profile_id,
        logged_by=user.id,
        name=data.name.strip(),
        dose=(data.dose or "").strip() or None,
        frequency=(data.frequency or "").strip() or None,
        taken_at=data.taken_at,
        notes=(data.notes or "").strip() or None,
    )
    db.add(med)
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
    get_profile_editor_or_403(med.profile_id, user, db)

    if data.name is not None:
        med.name = data.name.strip()
    if data.dose is not None:
        med.dose = data.dose.strip() or None
    if data.frequency is not None:
        med.frequency = data.frequency.strip() or None
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
    get_profile_editor_or_403(med.profile_id, user, db)

    db.delete(med)
    db.commit()
