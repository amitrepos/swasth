"""Health Readings API Routes"""
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime
import models
import schemas
from database import get_db
from dependencies import get_current_user

router = APIRouter()

_VALID_READING_TYPES = {'glucose', 'blood_pressure'}


@router.post("/readings", response_model=schemas.HealthReadingResponse, status_code=status.HTTP_201_CREATED)
def save_reading(
    reading: schemas.HealthReadingCreate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """Save a new health reading (glucose or blood pressure)."""
    if reading.reading_type not in _VALID_READING_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid reading type. Must be 'glucose' or 'blood_pressure'",
        )

    db_reading = models.HealthReading(
        user_id=user.id,
        reading_type=reading.reading_type,
        glucose_value=reading.glucose_value,
        glucose_unit=reading.glucose_unit,
        sample_type=reading.sample_type,
        systolic=reading.systolic,
        diastolic=reading.diastolic,
        mean_arterial_pressure=reading.mean_arterial_pressure,
        pulse_rate=reading.pulse_rate,
        bp_unit=reading.bp_unit,
        bp_status=reading.bp_status,
        value_numeric=reading.value_numeric,
        unit_display=reading.unit_display,
        status_flag=reading.status_flag,
        notes=reading.notes,
        reading_timestamp=reading.reading_timestamp,
    )
    db.add(db_reading)
    db.commit()
    db.refresh(db_reading)
    return db_reading


@router.get("/readings", response_model=List[schemas.HealthReadingResponse])
def get_readings(
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
    reading_type: Optional[str] = None,
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
):
    """Get user's health readings with optional filtering."""
    query = db.query(models.HealthReading).filter(models.HealthReading.user_id == user.id)

    if reading_type:
        if reading_type not in _VALID_READING_TYPES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid reading type. Must be 'glucose' or 'blood_pressure'",
            )
        query = query.filter(models.HealthReading.reading_type == reading_type)

    return query.order_by(models.HealthReading.reading_timestamp.desc()).offset(offset).limit(limit).all()


@router.get("/readings/stats/summary")
def get_readings_summary(
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """Get summary statistics for user's readings."""
    total_readings = db.query(models.HealthReading).filter(
        models.HealthReading.user_id == user.id
    ).count()

    glucose_count = db.query(models.HealthReading).filter(
        models.HealthReading.user_id == user.id,
        models.HealthReading.reading_type == 'glucose',
    ).count()

    bp_count = db.query(models.HealthReading).filter(
        models.HealthReading.user_id == user.id,
        models.HealthReading.reading_type == 'blood_pressure',
    ).count()

    latest_reading = db.query(models.HealthReading).filter(
        models.HealthReading.user_id == user.id
    ).order_by(models.HealthReading.reading_timestamp.desc()).first()

    return {
        "total_readings": total_readings,
        "glucose_readings": glucose_count,
        "bp_readings": bp_count,
        "latest_reading": schemas.HealthReadingResponse.from_orm(latest_reading) if latest_reading else None,
    }


@router.get("/readings/{reading_id}", response_model=schemas.HealthReadingResponse)
def get_reading(
    reading_id: int,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """Get a specific reading by ID."""
    reading = _get_user_reading(db, reading_id, user.id)
    if reading is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reading not found")
    return reading


@router.delete("/readings/{reading_id}")
def delete_reading(
    reading_id: int,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """Delete a reading."""
    reading = _get_user_reading(db, reading_id, user.id)
    if reading is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reading not found")
    db.delete(reading)
    db.commit()
    return {"message": "Reading deleted successfully"}


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

def _get_user_reading(db: Session, reading_id: int, user_id: int):
    """Fetch a reading that belongs to the given user, or return None."""
    return db.query(models.HealthReading).filter(
        models.HealthReading.id == reading_id,
        models.HealthReading.user_id == user_id,
    ).first()
