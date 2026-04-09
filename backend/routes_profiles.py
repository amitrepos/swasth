"""Profile CRUD and invite management endpoints."""
from datetime import datetime, timedelta, timezone
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

import models
import schemas
from database import get_db
from dependencies import get_current_user, get_profile_access_or_403, get_profile_owner_or_403
from email_service import email_service

router = APIRouter()

INVITE_TTL_DAYS = 7


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _build_profile_response(profile: models.Profile, access_level: str, relationship: str = None) -> schemas.ProfileResponse:
    # Profile-level relationship (set at creation) takes precedence;
    # fall back to access-level relationship (set when sharing/linking).
    rel = profile.relationship or relationship
    return schemas.ProfileResponse(
        id=profile.id,
        name=profile.name,
        age=profile.age,
        gender=profile.gender,
        height=profile.height,
        weight=profile.weight,
        blood_group=profile.blood_group,
        medical_conditions=profile.medical_conditions,
        other_medical_condition=profile.other_medical_condition,
        current_medications=profile.current_medications,
        doctor_name=profile.doctor_name,
        doctor_specialty=profile.doctor_specialty,
        doctor_whatsapp=profile.doctor_whatsapp,
        access_level=access_level,
        relationship=rel,
        created_at=profile.created_at,
        updated_at=profile.updated_at,
    )


# ---------------------------------------------------------------------------
# Profile CRUD
# ---------------------------------------------------------------------------

@router.get("/profiles", response_model=List[schemas.ProfileResponse])
def list_profiles(
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """List all profiles the current user has access to (owned + shared)."""
    accesses = (
        db.query(models.ProfileAccess)
        .filter(models.ProfileAccess.user_id == user.id)
        .all()
    )
    result = []
    for access in accesses:
        profile = db.query(models.Profile).filter(models.Profile.id == access.profile_id).first()
        if profile:
            result.append(_build_profile_response(profile, access.access_level, access.relationship))
    return result


@router.post("/profiles", response_model=schemas.ProfileResponse, status_code=status.HTTP_201_CREATED)
def create_profile(
    data: schemas.ProfileCreate,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Create a new profile. The caller becomes the owner."""
    profile = models.Profile(
        name=data.name,
        relationship=data.relationship,
        age=data.age,
        gender=data.gender,
        height=data.height,
        weight=data.weight,
        blood_group=data.blood_group,
        medical_conditions=data.medical_conditions,
        other_medical_condition=data.other_medical_condition,
        current_medications=data.current_medications,
    )
    db.add(profile)
    db.flush()   # populate profile.id before creating access row

    access = models.ProfileAccess(
        user_id=user.id,
        profile_id=profile.id,
        access_level="owner",
    )
    db.add(access)
    db.commit()
    db.refresh(profile)
    return _build_profile_response(profile, "owner")


@router.get("/profiles/{profile_id}", response_model=schemas.ProfileResponse)
def get_profile(
    profile_id: int,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get a single profile. Accessible by owner or viewer."""
    access = get_profile_access_or_403(profile_id, user, db)
    profile = db.query(models.Profile).filter(models.Profile.id == profile_id).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    return _build_profile_response(profile, access.access_level)


@router.put("/profiles/{profile_id}", response_model=schemas.ProfileResponse)
def update_profile(
    profile_id: int,
    data: schemas.ProfileUpdate,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Update profile details. Owner only."""
    get_profile_owner_or_403(profile_id, user, db)
    profile = db.query(models.Profile).filter(models.Profile.id == profile_id).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    update_data = data.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(profile, field, value)

    db.commit()
    db.refresh(profile)
    return _build_profile_response(profile, "owner")


@router.delete("/profiles/{profile_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_profile(
    profile_id: int,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Delete a profile and all its readings. Owner only."""
    get_profile_owner_or_403(profile_id, user, db)
    profile = db.query(models.Profile).filter(models.Profile.id == profile_id).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    db.delete(profile)
    db.commit()


# ---------------------------------------------------------------------------
# Invite management — owner sends invites
# ---------------------------------------------------------------------------

@router.post("/profiles/{profile_id}/invite", status_code=status.HTTP_201_CREATED)
def send_invite(
    profile_id: int,
    data: schemas.InviteRequest,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Send an invite email to share this profile. Owner only."""
    get_profile_owner_or_403(profile_id, user, db)

    profile = db.query(models.Profile).filter(models.Profile.id == profile_id).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    # Prevent inviting yourself
    if data.email.lower() == user.email.lower():
        raise HTTPException(status_code=400, detail="You cannot invite yourself")

    # Check for existing pending invite
    existing = (
        db.query(models.ProfileInvite)
        .filter(
            models.ProfileInvite.profile_id == profile_id,
            models.ProfileInvite.invited_email == data.email.lower(),
            models.ProfileInvite.status == "pending",
        )
        .first()
    )
    if existing:
        raise HTTPException(status_code=409, detail="A pending invite already exists for this email")

    # Check if the invitee already has access
    invitee_user = db.query(models.User).filter(models.User.email == data.email.lower()).first()
    if invitee_user:
        already_has_access = (
            db.query(models.ProfileAccess)
            .filter(
                models.ProfileAccess.profile_id == profile_id,
                models.ProfileAccess.user_id == invitee_user.id,
            )
            .first()
        )
        if already_has_access:
            raise HTTPException(status_code=409, detail="This user already has access to the profile")

    invite = models.ProfileInvite(
        profile_id=profile_id,
        invited_by_user_id=user.id,
        invited_email=data.email.lower(),
        invited_user_id=invitee_user.id if invitee_user else None,
        relationship=data.relationship,
        access_level=data.access_level or "viewer",
        status="pending",
        expires_at=datetime.now(timezone.utc) + timedelta(days=INVITE_TTL_DAYS),
    )
    db.add(invite)
    db.commit()
    db.refresh(invite)

    email_service.send_profile_invite_email(
        invitee_email=data.email,
        inviter_name=user.full_name,
        profile_name=profile.name,
        invite_id=invite.id,
    )

    return {"message": "Invite sent", "invite_id": invite.id}


@router.delete("/profiles/{profile_id}/invites/{invite_id}", status_code=status.HTTP_204_NO_CONTENT)
def cancel_invite(
    profile_id: int,
    invite_id: int,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Cancel a pending invite. Owner only."""
    get_profile_owner_or_403(profile_id, user, db)

    invite = (
        db.query(models.ProfileInvite)
        .filter(
            models.ProfileInvite.id == invite_id,
            models.ProfileInvite.profile_id == profile_id,
            models.ProfileInvite.status == "pending",
        )
        .first()
    )
    if not invite:
        raise HTTPException(status_code=404, detail="Pending invite not found")

    db.delete(invite)
    db.commit()


@router.get("/profiles/{profile_id}/access")
def list_profile_access(
    profile_id: int,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """List all users who have access to this profile. Any member can view."""
    get_profile_access_or_403(profile_id, user, db)

    accesses = (
        db.query(models.ProfileAccess)
        .filter(models.ProfileAccess.profile_id == profile_id)
        .all()
    )
    profile = db.query(models.Profile).filter(models.Profile.id == profile_id).first()
    result = []
    for a in accesses:
        u = db.query(models.User).filter(models.User.id == a.user_id).first()
        if u:
            # For owners, fall back to Profile.relationship (e.g. "father")
            rel = a.relationship
            if not rel and a.access_level == "owner" and profile:
                rel = profile.relationship
            result.append({
                "user_id": u.id,
                "full_name": u.full_name,
                "email": u.email,
                "phone_number": u.phone_number,
                "access_level": a.access_level,
                "relationship": rel,
                "granted_at": a.created_at,
                "last_login_at": u.last_login_at,
            })
    return result


@router.delete("/profiles/{profile_id}/access/{target_user_id}", status_code=status.HTTP_204_NO_CONTENT)
def revoke_access(
    profile_id: int,
    target_user_id: int,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Revoke a viewer's access to this profile. Owner only. Cannot revoke owner."""
    get_profile_owner_or_403(profile_id, user, db)

    if target_user_id == user.id:
        raise HTTPException(status_code=400, detail="Cannot revoke your own owner access")

    access = (
        db.query(models.ProfileAccess)
        .filter(
            models.ProfileAccess.profile_id == profile_id,
            models.ProfileAccess.user_id == target_user_id,
            models.ProfileAccess.access_level.in_(["viewer", "editor"]),
        )
        .first()
    )
    if not access:
        raise HTTPException(status_code=404, detail="Non-owner access not found")

    db.delete(access)
    db.commit()


@router.patch("/profiles/{profile_id}/access/{target_user_id}")
def update_access_level(
    profile_id: int,
    target_user_id: int,
    data: dict,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Update a user's access level and/or relationship. Owner only."""
    get_profile_owner_or_403(profile_id, user, db)

    new_level = data.get("access_level", "").strip().lower() if data.get("access_level") else None
    new_relationship = data.get("relationship")

    if new_level and new_level not in ("viewer", "editor"):
        raise HTTPException(status_code=400, detail="access_level must be 'viewer' or 'editor'")

    if not new_level and new_relationship is None:
        raise HTTPException(status_code=400, detail="Provide access_level and/or relationship")

    if target_user_id == user.id:
        raise HTTPException(status_code=400, detail="Cannot change your own owner access")

    access = (
        db.query(models.ProfileAccess)
        .filter(
            models.ProfileAccess.profile_id == profile_id,
            models.ProfileAccess.user_id == target_user_id,
            models.ProfileAccess.access_level.in_(["viewer", "editor"]),
        )
        .first()
    )
    if not access:
        raise HTTPException(status_code=404, detail="Non-owner access not found")

    if new_level:
        access.access_level = new_level
    if new_relationship is not None:
        access.relationship = new_relationship.strip() if new_relationship else None
    db.commit()

    u = db.query(models.User).filter(models.User.id == target_user_id).first()
    return {
        "user_id": target_user_id,
        "full_name": u.full_name if u else None,
        "email": u.email if u else None,
        "access_level": access.access_level,
        "relationship": access.relationship,
    }


# ---------------------------------------------------------------------------
# Invite management — invitee responds
# ---------------------------------------------------------------------------

@router.get("/invites/pending", response_model=List[schemas.InviteResponse])
def list_pending_invites(
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """List all pending invites sent to the current user's email."""
    now = datetime.now(timezone.utc)
    invites = (
        db.query(models.ProfileInvite)
        .filter(
            models.ProfileInvite.invited_email == user.email.lower(),
            models.ProfileInvite.status == "pending",
            models.ProfileInvite.expires_at > now,
        )
        .all()
    )
    result = []
    for inv in invites:
        profile = db.query(models.Profile).filter(models.Profile.id == inv.profile_id).first()
        inviter = db.query(models.User).filter(models.User.id == inv.invited_by_user_id).first()
        result.append(schemas.InviteResponse(
            id=inv.id,
            profile_id=inv.profile_id,
            profile_name=profile.name if profile else "Unknown",
            invited_by_name=inviter.full_name if inviter else "Unknown",
            relationship=inv.relationship,
            access_level=inv.access_level or "viewer",
            status=inv.status,
            expires_at=inv.expires_at,
            created_at=inv.created_at,
        ))
    return result


@router.patch("/invites/{invite_id}")
@router.post("/invites/{invite_id}/respond", deprecated=True)
def respond_to_invite(
    invite_id: int,
    data: schemas.InviteRespondRequest,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Accept or reject a pending invite."""
    now = datetime.now(timezone.utc)
    invite = (
        db.query(models.ProfileInvite)
        .filter(
            models.ProfileInvite.id == invite_id,
            models.ProfileInvite.invited_email == user.email.lower(),
            models.ProfileInvite.status == "pending",
        )
        .first()
    )
    if not invite:
        raise HTTPException(status_code=404, detail="Pending invite not found")

    # Treat expired invites as rejected
    expires_at = invite.expires_at
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    if expires_at < now:
        invite.status = "rejected"
        db.commit()
        raise HTTPException(status_code=410, detail="This invite has expired")

    if data.action == "reject":
        invite.status = "rejected"
        db.commit()
        return {"message": "Invite rejected"}

    # Accept: create ProfileAccess with the access level specified in the invite
    existing = (
        db.query(models.ProfileAccess)
        .filter(
            models.ProfileAccess.profile_id == invite.profile_id,
            models.ProfileAccess.user_id == user.id,
        )
        .first()
    )
    if not existing:
        db.add(models.ProfileAccess(
            user_id=user.id,
            profile_id=invite.profile_id,
            access_level=invite.access_level or "viewer",
            relationship=invite.relationship,
        ))

    invite.status = "accepted"
    invite.invited_user_id = user.id
    db.commit()
    return {"message": "Invite accepted", "profile_id": invite.profile_id}
