"""Health Readings API Routes"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import Annotated, List, Optional
from datetime import datetime
import models
import schemas
import auth
from database import get_db

router = APIRouter()


@router.post("/readings", response_model=schemas.HealthReadingResponse, status_code=status.HTTP_201_CREATED)
def save_reading(
    reading: schemas.HealthReadingCreate,
    token: Annotated[str, Depends(auth.oauth2_scheme)],
    db: Session = Depends(get_db)
):
    """Save a new health reading (glucose or blood pressure)"""
    # Get current user
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    payload = auth.decode_access_token(token)
    if payload is None:
        raise credentials_exception
    
    email: str = payload.get("sub")
    if email is None:
        raise credentials_exception
    
    user = db.query(models.User).filter(models.User.email == email).first()
    if user is None:
        raise credentials_exception
    
    # Validate reading type
    if reading.reading_type not in ['glucose', 'blood_pressure']:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid reading type. Must be 'glucose' or 'blood_pressure'"
        )
    
    # Create and save reading
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
    
    print(f"✓ Saved {reading.reading_type} reading for user {user.email}: {reading.value_numeric} {reading.unit_display}")
    
    return db_reading


@router.get("/readings", response_model=List[schemas.HealthReadingResponse])
def get_readings(
    token: Annotated[str, Depends(auth.oauth2_scheme)],
    db: Session = Depends(get_db),
    reading_type: Optional[str] = None,
    limit: int = 100,
    offset: int = 0
):
    """Get user's health readings with optional filtering"""
    # Get current user
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    payload = auth.decode_access_token(token)
    if payload is None:
        raise credentials_exception
    
    email: str = payload.get("sub")
    if email is None:
        raise credentials_exception
    
    user = db.query(models.User).filter(models.User.email == email).first()
    if user is None:
        raise credentials_exception
    
    # Build query
    query = db.query(models.HealthReading).filter(
        models.HealthReading.user_id == user.id
    )
    
    # Filter by reading type if specified
    if reading_type:
        if reading_type not in ['glucose', 'blood_pressure']:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid reading type. Must be 'glucose' or 'blood_pressure'"
            )
        query = query.filter(models.HealthReading.reading_type == reading_type)
    
    # Order by timestamp (most recent first) and apply pagination
    readings = query.order_by(
        models.HealthReading.reading_timestamp.desc()
    ).offset(offset).limit(limit).all()
    
    return readings


@router.get("/readings/{reading_id}", response_model=schemas.HealthReadingResponse)
def get_reading(
    reading_id: int,
    token: Annotated[str, Depends(auth.oauth2_scheme)],
    db: Session = Depends(get_db)
):
    """Get a specific reading by ID"""
    # Get current user
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    payload = auth.decode_access_token(token)
    if payload is None:
        raise credentials_exception
    
    email: str = payload.get("sub")
    if email is None:
        raise credentials_exception
    
    user = db.query(models.User).filter(models.User.email == email).first()
    if user is None:
        raise credentials_exception
    
    # Get reading
    reading = db.query(models.HealthReading).filter(
        models.HealthReading.id == reading_id,
        models.HealthReading.user_id == user.id
    ).first()
    
    if reading is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Reading not found"
        )
    
    return reading


@router.delete("/readings/{reading_id}")
def delete_reading(
    reading_id: int,
    token: Annotated[str, Depends(auth.oauth2_scheme)],
    db: Session = Depends(get_db)
):
    """Delete a reading"""
    # Get current user
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    payload = auth.decode_access_token(token)
    if payload is None:
        raise credentials_exception
    
    email: str = payload.get("sub")
    if email is None:
        raise credentials_exception
    
    user = db.query(models.User).filter(models.User.email == email).first()
    if user is None:
        raise credentials_exception
    
    # Get reading
    reading = db.query(models.HealthReading).filter(
        models.HealthReading.id == reading_id,
        models.HealthReading.user_id == user.id
    ).first()
    
    if reading is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Reading not found"
        )
    
    # Delete reading
    db.delete(reading)
    db.commit()
    
    return {"message": "Reading deleted successfully"}


@router.get("/readings/stats/summary")
def get_readings_summary(
    token: Annotated[str, Depends(auth.oauth2_scheme)],
    db: Session = Depends(get_db)
):
    """Get summary statistics for user's readings"""
    # Get current user
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    payload = auth.decode_access_token(token)
    if payload is None:
        raise credentials_exception
    
    email: str = payload.get("sub")
    if email is None:
        raise credentials_exception
    
    user = db.query(models.User).filter(models.User.email == email).first()
    if user is None:
        raise credentials_exception
    
    # Get total count
    total_readings = db.query(models.HealthReading).filter(
        models.HealthReading.user_id == user.id
    ).count()
    
    # Get glucose count
    glucose_count = db.query(models.HealthReading).filter(
        models.HealthReading.user_id == user.id,
        models.HealthReading.reading_type == 'glucose'
    ).count()
    
    # Get BP count
    bp_count = db.query(models.HealthReading).filter(
        models.HealthReading.user_id == user.id,
        models.HealthReading.reading_type == 'blood_pressure'
    ).count()
    
    # Get latest reading
    latest_reading = db.query(models.HealthReading).filter(
        models.HealthReading.user_id == user.id
    ).order_by(
        models.HealthReading.reading_timestamp.desc()
    ).first()
    
    return {
        "total_readings": total_readings,
        "glucose_readings": glucose_count,
        "bp_readings": bp_count,
        "latest_reading": schemas.HealthReadingResponse.from_orm(latest_reading) if latest_reading else None
    }
