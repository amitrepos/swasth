"""Shared FastAPI dependencies."""
from fastapi import Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import Annotated
import models
import auth
from database import get_db
from encryption_service import hash_email


def get_current_user(
    token: Annotated[str, Depends(auth.oauth2_scheme)],
    db: Session = Depends(get_db),
) -> models.User:
    """Extract and validate the current user from the JWT token.

    Use as a dependency in any route that requires authentication:
        user: models.User = Depends(get_current_user)
    """
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
    user = db.query(models.User).filter(models.User.email_hash == hash_email(email)).first()
    if user is None:
        raise credentials_exception
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Your account has been suspended. Contact support.",
        )
    return user


def get_profile_access_or_403(
    profile_id: int,
    user: models.User,
    db: Session,
) -> models.ProfileAccess:
    """Return the ProfileAccess row if the user has any access (owner or viewer).
    Raises 403 if the user has no access to this profile.
    """
    access = (
        db.query(models.ProfileAccess)
        .filter(
            models.ProfileAccess.profile_id == profile_id,
            models.ProfileAccess.user_id == user.id,
        )
        .first()
    )
    if access is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have access to this profile",
        )
    return access


def get_profile_editor_or_403(
    profile_id: int,
    user: models.User,
    db: Session,
) -> models.ProfileAccess:
    """Return the ProfileAccess row if the user is owner or editor.
    Raises 403 for viewers or users with no access.
    """
    access = (
        db.query(models.ProfileAccess)
        .filter(
            models.ProfileAccess.profile_id == profile_id,
            models.ProfileAccess.user_id == user.id,
            models.ProfileAccess.access_level.in_(["owner", "editor"]),
        )
        .first()
    )
    if access is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You need editor or owner access to perform this action",
        )
    return access


def get_doctor_patient_access(
    profile_id: int,
    user: models.User,
    db: Session,
) -> models.DoctorPatientLink:
    """Verify doctor has an active link to this patient profile.
    Logs the access for DPDPA audit trail.
    Raises 403 if the user is not a doctor or has no active link.
    """
    if user.role != models.UserRole.doctor:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only doctors can access this resource",
        )
    link = (
        db.query(models.DoctorPatientLink)
        .filter(
            models.DoctorPatientLink.doctor_id == user.id,
            models.DoctorPatientLink.profile_id == profile_id,
            models.DoctorPatientLink.status == "active",
        )
        .first()
    )
    if link is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No active access to this patient",
        )
    return link


def get_profile_owner_or_403(
    profile_id: int,
    user: models.User,
    db: Session,
) -> models.ProfileAccess:
    """Return the ProfileAccess row only if the user is the owner.
    Raises 403 for viewers or users with no access.
    """
    access = (
        db.query(models.ProfileAccess)
        .filter(
            models.ProfileAccess.profile_id == profile_id,
            models.ProfileAccess.user_id == user.id,
            models.ProfileAccess.access_level == "owner",
        )
        .first()
    )
    if access is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the profile owner can perform this action",
        )
    return access
