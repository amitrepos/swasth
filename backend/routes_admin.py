"""Admin dashboard endpoints — metrics, user management, operational stats.

All endpoints require is_admin=True on the authenticated user.
"""
import json
import os
from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from fastapi.responses import HTMLResponse, Response
from slowapi import Limiter
from slowapi.util import get_remote_address
from sqlalchemy import func, distinct, case
from sqlalchemy.orm import Session
from datetime import datetime, date, timedelta, timezone
from typing import Optional

import auth
import models
import schemas
from database import get_db
from dependencies import get_current_user
from doctor_utils import ensure_unique_doctor_code

router = APIRouter()

# Rate limiter — disabled under TESTING=true to keep the suite deterministic.
_limiter_enabled = os.environ.get("TESTING", "").lower() != "true"
limiter = Limiter(key_func=get_remote_address, enabled=_limiter_enabled)

_DASHBOARD_HTML = os.path.join(os.path.dirname(__file__), "admin_dashboard.html")


# ---------------------------------------------------------------------------
# Audit helper — call from every admin action (CERT-In 180-day requirement)
# ---------------------------------------------------------------------------

def _audit_log(
    db: Session,
    admin: models.User,
    action_type: str,
    target_user_id: int = None,
    target_profile_id: int = None,
    details: dict = None,
    outcome: str = "SUCCESS",
):
    """Append an immutable row to admin_audit_log."""
    entry = models.AdminAuditLog(
        admin_user_id=admin.id,
        action_type=action_type,
        target_user_id=target_user_id,
        target_profile_id=target_profile_id,
        details=json.dumps(details) if details else None,
        outcome=outcome,
    )
    db.add(entry)
    db.flush()  # flush so it persists even if caller commits later


@router.get("/admin", response_class=HTMLResponse)
def admin_dashboard_page():
    """Serve the admin dashboard HTML page."""
    with open(_DASHBOARD_HTML, "r") as f:
        return f.read()


def _require_admin(user: models.User = Depends(get_current_user)):
    if not user.is_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")
    return user


# ---------------------------------------------------------------------------
# VC Metrics — the numbers investors ask for
# ---------------------------------------------------------------------------

@router.get("/admin/metrics")
def get_metrics(
    db: Session = Depends(get_db),
    user: models.User = Depends(_require_admin),
):
    """Core metrics dashboard — DAU, MAU, retention, engagement, clinical outcomes."""
    today = date.today()
    now = datetime.utcnow()

    # ── User counts ──────────────────────────────────────────────────
    total_users = db.query(func.count(models.User.id)).scalar() or 0
    total_profiles = db.query(func.count(models.Profile.id)).scalar() or 0
    total_readings = db.query(func.count(models.HealthReading.id)).scalar() or 0

    # ── DAU / MAU ────────────────────────────────────────────────────
    day_ago = now - timedelta(days=1)
    week_ago = now - timedelta(days=7)
    month_ago = now - timedelta(days=30)

    dau = db.query(func.count(distinct(models.User.id))).filter(
        models.User.last_login_at >= day_ago,
    ).scalar() or 0

    wau = db.query(func.count(distinct(models.User.id))).filter(
        models.User.last_login_at >= week_ago,
    ).scalar() or 0

    mau = db.query(func.count(distinct(models.User.id))).filter(
        models.User.last_login_at >= month_ago,
    ).scalar() or 0

    stickiness = round(dau / mau * 100, 1) if mau > 0 else 0

    # ── Retention (D1, D7, D30) ──────────────────────────────────────
    def _retention(days_ago_start, days_ago_end):
        """% of users who signed up N days ago and logged in after."""
        signup_start = now - timedelta(days=days_ago_start + 1)
        signup_end = now - timedelta(days=days_ago_start)
        cohort = db.query(models.User).filter(
            models.User.created_at >= signup_start,
            models.User.created_at < signup_end,
        ).all()
        if not cohort:
            return None
        returned = 0
        for u in cohort:
            if u.last_login_at:
                login = u.last_login_at.replace(tzinfo=None) if u.last_login_at.tzinfo else u.last_login_at
                if login >= signup_end:
                    returned += 1
        return round(returned / len(cohort) * 100, 1)

    d1_retention = _retention(1, 0)
    d7_retention = _retention(7, 0)
    d30_retention = _retention(30, 0)

    # ── Engagement ───────────────────────────────────────────────────
    readings_this_week = db.query(func.count(models.HealthReading.id)).filter(
        models.HealthReading.created_at >= datetime.combine(today - timedelta(days=6), datetime.min.time()),
    ).scalar() or 0

    readings_per_user_week = round(readings_this_week / max(wau, 1), 1)

    # Streak distribution
    all_profiles = db.query(models.Profile).all()
    streak_counts = {"0": 0, "1-2": 0, "3-6": 0, "7-13": 0, "14-29": 0, "30+": 0}
    for profile in all_profiles:
        days_with = set()
        for r in db.query(models.HealthReading).filter(
            models.HealthReading.profile_id == profile.id,
            models.HealthReading.reading_timestamp >= datetime.combine(today - timedelta(days=60), datetime.min.time()),
        ).all():
            days_with.add(r.reading_timestamp.date())

        streak = 0
        check = today if today in days_with else (today - timedelta(days=1) if (today - timedelta(days=1)) in days_with else None)
        while check and check in days_with:
            streak += 1
            check -= timedelta(days=1)

        if streak == 0: streak_counts["0"] += 1
        elif streak <= 2: streak_counts["1-2"] += 1
        elif streak <= 6: streak_counts["3-6"] += 1
        elif streak <= 13: streak_counts["7-13"] += 1
        elif streak <= 29: streak_counts["14-29"] += 1
        else: streak_counts["30+"] += 1

    # ── Viral / Sharing ──────────────────────────────────────────────
    total_invites = db.query(func.count(models.ProfileInvite.id)).scalar() or 0
    accepted_invites = db.query(func.count(models.ProfileInvite.id)).filter(
        models.ProfileInvite.status == "accepted",
    ).scalar() or 0
    invite_accept_rate = round(accepted_invites / max(total_invites, 1) * 100, 1)

    users_with_shared = db.query(func.count(distinct(models.ProfileAccess.user_id))).filter(
        models.ProfileAccess.access_level != "owner",
    ).scalar() or 0
    sharing_rate = round(users_with_shared / max(total_users, 1) * 100, 1)

    # ── Clinical outcomes ────────────────────────────────────────────
    glucose_readings = db.query(models.HealthReading).filter(
        models.HealthReading.reading_type == "glucose",
        models.HealthReading.glucose_value.isnot(None),
    ).all()

    total_glucose = len(glucose_readings)
    normal_glucose = sum(1 for r in glucose_readings if r.status_flag == "NORMAL")
    critical_glucose = sum(1 for r in glucose_readings if r.status_flag == "CRITICAL")
    high_glucose = sum(1 for r in glucose_readings if r.status_flag and "HIGH" in r.status_flag)

    bp_readings = db.query(models.HealthReading).filter(
        models.HealthReading.reading_type == "blood_pressure",
        models.HealthReading.systolic.isnot(None),
    ).all()
    total_bp = len(bp_readings)
    normal_bp = sum(1 for r in bp_readings if r.status_flag == "NORMAL")

    # ── AI / Chat usage ──────────────────────────────────────────────
    total_chat_messages = db.query(func.count(models.ChatMessage.id)).scalar() or 0
    users_who_chatted = db.query(func.count(distinct(models.ChatMessage.user_id))).scalar() or 0
    chat_adoption = round(users_who_chatted / max(total_users, 1) * 100, 1)

    ai_calls = db.query(func.count(models.AiInsightLog.id)).scalar() or 0
    ai_failures = db.query(func.count(models.AiInsightLog.id)).filter(
        models.AiInsightLog.model_used == "failed",
    ).scalar() or 0
    ai_fallback_rate = round(ai_failures / max(ai_calls, 1) * 100, 1)

    # ── Signups over time (last 30 days) ─────────────────────────────
    signups_by_day = []
    for d in range(29, -1, -1):
        day = today - timedelta(days=d)
        day_start = datetime.combine(day, datetime.min.time())
        day_end = datetime.combine(day + timedelta(days=1), datetime.min.time())
        count = db.query(func.count(models.User.id)).filter(
            models.User.created_at >= day_start,
            models.User.created_at < day_end,
        ).scalar() or 0
        signups_by_day.append({"date": day.isoformat(), "count": count})

    # ── Readings over time (last 30 days) ────────────────────────────
    readings_by_day = []
    for d in range(29, -1, -1):
        day = today - timedelta(days=d)
        day_start = datetime.combine(day, datetime.min.time())
        day_end = datetime.combine(day + timedelta(days=1), datetime.min.time())
        count = db.query(func.count(models.HealthReading.id)).filter(
            models.HealthReading.created_at >= day_start,
            models.HealthReading.created_at < day_end,
        ).scalar() or 0
        readings_by_day.append({"date": day.isoformat(), "count": count})

    return {
        "generated_at": now.isoformat(),

        # User counts
        "total_users": total_users,
        "total_profiles": total_profiles,
        "total_readings": total_readings,

        # Activity
        "dau": dau,
        "wau": wau,
        "mau": mau,
        "stickiness_pct": stickiness,

        # Retention
        "d1_retention_pct": d1_retention,
        "d7_retention_pct": d7_retention,
        "d30_retention_pct": d30_retention,

        # Engagement
        "readings_this_week": readings_this_week,
        "readings_per_user_week": readings_per_user_week,
        "streak_distribution": streak_counts,

        # Viral
        "total_invites_sent": total_invites,
        "invite_accept_rate_pct": invite_accept_rate,
        "sharing_rate_pct": sharing_rate,

        # Clinical
        "glucose_readings_total": total_glucose,
        "glucose_normal_pct": round(normal_glucose / max(total_glucose, 1) * 100, 1),
        "glucose_critical_count": critical_glucose,
        "glucose_high_count": high_glucose,
        "bp_readings_total": total_bp,
        "bp_normal_pct": round(normal_bp / max(total_bp, 1) * 100, 1),

        # AI / Chat
        "chat_messages_total": total_chat_messages,
        "chat_adoption_pct": chat_adoption,
        "ai_calls_total": ai_calls,
        "ai_fallback_rate_pct": ai_fallback_rate,

        # Trends
        "signups_by_day": signups_by_day,
        "readings_by_day": readings_by_day,
    }


# ---------------------------------------------------------------------------
# User management
# ---------------------------------------------------------------------------

@router.get("/admin/users")
def list_users(
    db: Session = Depends(get_db),
    user: models.User = Depends(_require_admin),
):
    """List all users with activity stats."""
    users = db.query(models.User).order_by(models.User.created_at.desc()).all()
    today = date.today()

    result = []
    for u in users:
        # Count readings across all owned profiles
        owned_profiles = db.query(models.ProfileAccess).filter(
            models.ProfileAccess.user_id == u.id,
            models.ProfileAccess.access_level == "owner",
        ).all()
        total_readings = 0
        for pa in owned_profiles:
            total_readings += db.query(func.count(models.HealthReading.id)).filter(
                models.HealthReading.profile_id == pa.profile_id,
            ).scalar() or 0

        profile_count = db.query(func.count(models.ProfileAccess.id)).filter(
            models.ProfileAccess.user_id == u.id,
        ).scalar() or 0

        result.append({
            "id": u.id,
            "email": u.email,
            "full_name": u.full_name,
            "phone_number": u.phone_number,
            "is_admin": u.is_admin,
            "is_active": u.is_active,
            "role": u.role.value if hasattr(u.role, 'value') else (u.role or "patient"),
            "ai_consent": u.ai_consent,
            "profiles_count": profile_count,
            "total_readings": total_readings,
            "last_login": u.last_login_at.isoformat() if u.last_login_at else None,
            "signed_up": u.created_at.isoformat() if u.created_at else None,
        })

    return {"users": result, "total": len(result)}


@router.get("/admin/users/{user_id}/detail")
def get_user_detail(
    user_id: int,
    db: Session = Depends(get_db),
    user: models.User = Depends(_require_admin),
):
    """Full user detail for admin inspection — profiles, readings, chats, AI insights."""
    target = db.query(models.User).filter(models.User.id == user_id).first()
    if not target:
        raise HTTPException(status_code=404, detail="User not found")

    # ── Profiles via ProfileAccess ───────────────────────────────────
    access_rows = (
        db.query(models.ProfileAccess, models.Profile)
        .join(models.Profile, models.ProfileAccess.profile_id == models.Profile.id)
        .filter(models.ProfileAccess.user_id == user_id)
        .all()
    )
    profile_ids = [p.id for _, p in access_rows]
    profiles = []
    for pa, p in access_rows:
        profiles.append({
            "id": p.id,
            "name": p.name,
            "relationship": p.relationship,
            "access_level": pa.access_level,
            "age": p.age,
            "gender": p.gender,
            "height": p.height,
            "blood_group": p.blood_group,
            "medical_conditions": p.medical_conditions or [],
            "other_medical_condition": p.other_medical_condition,
            "current_medications": p.current_medications,
            "doctor_name": p.doctor_name,
            "doctor_specialty": p.doctor_specialty,
            "doctor_whatsapp": p.doctor_whatsapp,
        })

    # ── Recent health readings (last 50) ─────────────────────────────
    profile_name_map = {p["id"]: p["name"] for p in profiles}
    readings_q = (
        db.query(models.HealthReading)
        .filter(models.HealthReading.profile_id.in_(profile_ids))
        .order_by(models.HealthReading.reading_timestamp.desc())
        .limit(50)
        .all()
    ) if profile_ids else []

    recent_readings = []
    for r in readings_q:
        recent_readings.append({
            "id": r.id,
            "profile_name": profile_name_map.get(r.profile_id, "Unknown"),
            "reading_type": r.reading_type,
            "glucose_value": r.glucose_value,
            "sample_type": r.sample_type,
            "systolic": r.systolic,
            "diastolic": r.diastolic,
            "pulse_rate": r.pulse_rate,
            "value_numeric": r.value_numeric,
            "unit_display": r.unit_display,
            "status_flag": r.status_flag,
            "notes": r.notes,
            "reading_timestamp": r.reading_timestamp.isoformat() if r.reading_timestamp else None,
        })

    # ── Recent chat messages (last 20) ───────────────────────────────
    chats_q = (
        db.query(models.ChatMessage)
        .filter(models.ChatMessage.user_id == user_id)
        .order_by(models.ChatMessage.created_at.desc())
        .limit(20)
        .all()
    )
    recent_chats = []
    for c in chats_q:
        recent_chats.append({
            "id": c.id,
            "profile_id": c.profile_id,
            "profile_name": profile_name_map.get(c.profile_id, "Unknown"),
            "user_message": c.user_message,
            "ai_response": c.ai_response,
            "model_used": c.model_used,
            "tokens_used": c.tokens_used,
            "latency_ms": c.latency_ms,
            "created_at": c.created_at.isoformat() if c.created_at else None,
        })

    # ── Recent AI insight logs (last 20) ─────────────────────────────
    insights_q = (
        db.query(models.AiInsightLog)
        .filter(models.AiInsightLog.profile_id.in_(profile_ids))
        .order_by(models.AiInsightLog.created_at.desc())
        .limit(20)
        .all()
    ) if profile_ids else []

    recent_insights = []
    for i in insights_q:
        recent_insights.append({
            "id": i.id,
            "profile_id": i.profile_id,
            "profile_name": profile_name_map.get(i.profile_id, "Unknown"),
            "model_used": i.model_used,
            "prompt_summary": i.prompt_summary,
            "response_text": i.response_text,
            "fallback_reason": i.fallback_reason,
            "tokens_used": i.tokens_used,
            "latency_ms": i.latency_ms,
            "created_at": i.created_at.isoformat() if i.created_at else None,
        })

    # ── Feature usage summary ────────────────────────────────────────
    readings_count = db.query(func.count(models.HealthReading.id)).filter(
        models.HealthReading.profile_id.in_(profile_ids),
    ).scalar() or 0 if profile_ids else 0

    chat_count = db.query(func.count(models.ChatMessage.id)).filter(
        models.ChatMessage.user_id == user_id,
    ).scalar() or 0

    ai_insight_count = db.query(func.count(models.AiInsightLog.id)).filter(
        models.AiInsightLog.profile_id.in_(profile_ids),
    ).scalar() or 0 if profile_ids else 0

    invites_sent = db.query(func.count(models.ProfileInvite.id)).filter(
        models.ProfileInvite.invited_by_user_id == user_id,
    ).scalar() or 0

    invites_accepted = db.query(func.count(models.ProfileInvite.id)).filter(
        models.ProfileInvite.invited_by_user_id == user_id,
        models.ProfileInvite.status == "accepted",
    ).scalar() or 0

    # ── AI memory (ChatContextProfile) per profile ───────────────────
    ai_memory = []
    for pid in profile_ids:
        ctx = db.query(models.ChatContextProfile).filter(
            models.ChatContextProfile.profile_id == pid,
        ).first()
        ai_memory.append({
            "profile_id": pid,
            "profile_name": profile_name_map.get(pid, "Unknown"),
            "summary": ctx.summary if ctx else "",
            "message_count": ctx.message_count if ctx else 0,
            "last_updated": ctx.last_updated.isoformat() if ctx and ctx.last_updated else None,
        })

    _audit_log(db, user, "VIEW_USER_DETAIL", target_user_id=user_id)
    db.commit()

    return {
        "user": {
            "id": target.id,
            "email": target.email,
            "full_name": target.full_name,
            "phone_number": target.phone_number,
            "is_admin": target.is_admin,
            "is_active": target.is_active,
            "role": target.role.value if hasattr(target.role, 'value') else (target.role or "patient"),
            "ai_consent": target.ai_consent,
            "timezone": target.timezone,
            "last_login": target.last_login_at.isoformat() if target.last_login_at else None,
            "signed_up": target.created_at.isoformat() if target.created_at else None,
        },
        "profiles": profiles,
        "recent_readings": recent_readings,
        "recent_chats": recent_chats,
        "recent_ai_insights": recent_insights,
        "ai_memory": ai_memory,
        "feature_usage": {
            "readings_logged": readings_count,
            "chat_messages": chat_count,
            "ai_insights": ai_insight_count,
            "profiles_managed": len(profiles),
            "invites_sent": invites_sent,
            "invites_accepted": invites_accepted,
        },
    }


@router.put("/admin/profiles/{profile_id}/ai-memory")
def update_ai_memory(
    profile_id: int,
    payload: dict,
    db: Session = Depends(get_db),
    user: models.User = Depends(_require_admin),
):
    """Update the AI chat context summary for a profile."""
    ctx = db.query(models.ChatContextProfile).filter(
        models.ChatContextProfile.profile_id == profile_id,
    ).first()
    if not ctx:
        raise HTTPException(status_code=404, detail="No AI memory found for this profile")
    ctx.summary = payload.get("summary", ctx.summary)
    _audit_log(db, user, "EDIT_AI_MEMORY", target_profile_id=profile_id)
    db.commit()
    return {"message": "AI memory updated", "profile_id": profile_id}


@router.delete("/admin/profiles/{profile_id}/ai-memory", status_code=status.HTTP_204_NO_CONTENT)
def reset_ai_memory(
    profile_id: int,
    db: Session = Depends(get_db),
    user: models.User = Depends(_require_admin),
):
    """Reset the AI chat context summary for a profile."""
    ctx = db.query(models.ChatContextProfile).filter(
        models.ChatContextProfile.profile_id == profile_id,
    ).first()
    if ctx:
        ctx.summary = ""
        ctx.message_count = 0
        _audit_log(db, user, "RESET_AI_MEMORY", target_profile_id=profile_id)
        db.commit()
    return Response(status_code=204)


@router.patch("/admin/users/{user_id}")
def update_user_admin_status(
    user_id: int,
    body: schemas.AdminStatusUpdate,
    db: Session = Depends(get_db),
    user: models.User = Depends(_require_admin),
):
    """Update admin status for a user."""
    if not body.is_admin and user_id == user.id:
        raise HTTPException(status_code=400, detail="Cannot remove your own admin access")
    target = db.query(models.User).filter(models.User.id == user_id).first()
    if not target:
        raise HTTPException(status_code=404, detail="User not found")
    old_status = target.is_admin
    target.is_admin = body.is_admin
    if body.is_admin:
        target.role = models.UserRole.admin
    _audit_log(db, user, "TOGGLE_ADMIN", target_user_id=user_id,
               details={"old": old_status, "new": body.is_admin})
    db.commit()
    result_status = "now an admin" if body.is_admin else "no longer an admin"
    return {"message": f"{target.email} is {result_status}"}


# ---------------------------------------------------------------------------
# G2: Account suspension
# ---------------------------------------------------------------------------

@router.patch("/admin/users/{user_id}/suspend")
def suspend_user(
    user_id: int,
    body: schemas.AdminSuspendUser,
    db: Session = Depends(get_db),
    user: models.User = Depends(_require_admin),
):
    """Suspend or reactivate a user account."""
    if user_id == user.id:
        raise HTTPException(status_code=400, detail="Cannot suspend your own account")
    target = db.query(models.User).filter(models.User.id == user_id).first()
    if not target:
        raise HTTPException(status_code=404, detail="User not found")

    target.is_active = not body.suspend
    action = "SUSPEND_USER" if body.suspend else "UNSUSPEND_USER"
    _audit_log(db, user, action, target_user_id=user_id,
               details={"reason": body.reason, "suspend": body.suspend})
    db.commit()

    word = "suspended" if body.suspend else "reactivated"
    return {"message": f"{target.email} has been {word}"}


# ---------------------------------------------------------------------------
# G6: Admin-creates-user (patient only for now)
# ---------------------------------------------------------------------------


@router.post("/admin/users", status_code=status.HTTP_201_CREATED)
@limiter.limit("10/minute")
def admin_create_user(
    request: Request,
    body: schemas.AdminCreateUser,
    db: Session = Depends(get_db),
    user: models.User = Depends(_require_admin),
):
    """Admin creates a patient account on behalf of a user.

    Doctor-role creation is intentionally blocked (501 Not Implemented)
    until a first-login onboarding flow exists that captures the doctor's
    own ToS/DPA consent under DPDPA § 6. Until then, doctors must
    self-register via /api/doctor/register so their consent chain is clean.

    Patient accounts are created active and ready to log in; the user will
    still need to complete consent + profile creation on first login via
    the normal consent_screen.dart path.
    """
    if body.role == "doctor":
        raise HTTPException(
            status_code=status.HTTP_501_NOT_IMPLEMENTED,
            detail=(
                "Admin-created doctor accounts are not yet supported. "
                "Doctors must self-register at /api/doctor/register so their "
                "DPDPA consent is captured directly."
            ),
        )

    if db.query(models.User).filter(models.User.email == body.email).first():
        raise HTTPException(status_code=400, detail="Email already registered")

    now_utc = datetime.now(timezone.utc)
    new_user = models.User(
        email=body.email,
        password_hash=auth.get_password_hash(body.password),
        full_name=body.full_name,
        phone_number=body.phone_number,
        role=models.UserRole.patient,
        is_active=True,
        timezone="Asia/Kolkata",
        created_at=now_utc,
        updated_at=now_utc,
    )
    db.add(new_user)
    db.flush()

    # Audit log — only store redacted PII, not the full NMC number or
    # anything that could re-identify the user beyond what's already keyed.
    details = {"role": body.role, "email": body.email}
    _audit_log(db, user, "ADMIN_CREATE_USER", target_user_id=new_user.id, details=details)
    db.commit()
    db.refresh(new_user)

    return {
        "id": new_user.id,
        "email": new_user.email,
        "full_name": new_user.full_name,
        "role": "patient",
        "message": f"Patient account created for {new_user.email}",
    }


# ---------------------------------------------------------------------------
# G1: Doctor verification
# ---------------------------------------------------------------------------

@router.get("/admin/doctors")
def list_doctors(
    verified: Optional[str] = Query(None, regex="^(true|false|all)$"),
    db: Session = Depends(get_db),
    user: models.User = Depends(_require_admin),
):
    """List all doctors with verification status and patient count."""
    q = db.query(models.DoctorProfile, models.User).join(
        models.User, models.DoctorProfile.user_id == models.User.id
    )
    if verified == "true":
        q = q.filter(models.DoctorProfile.is_verified == True)  # noqa: E712
    elif verified == "false":
        q = q.filter(models.DoctorProfile.is_verified == False)  # noqa: E712

    doctors = q.order_by(models.DoctorProfile.created_at.desc()).all()
    result = []
    for dp, u in doctors:
        patient_count = db.query(func.count(models.DoctorPatientLink.id)).filter(
            models.DoctorPatientLink.doctor_id == u.id,
            models.DoctorPatientLink.is_active == True,  # noqa: E712
        ).scalar() or 0

        last_access = db.query(func.max(models.DoctorAccessLog.created_at)).filter(
            models.DoctorAccessLog.doctor_id == u.id,
        ).scalar()

        result.append({
            "user_id": u.id,
            "email": u.email,
            "full_name": u.full_name,
            "phone_number": u.phone_number,
            "nmc_number": dp.nmc_number,
            "specialty": dp.specialty,
            "clinic_name": dp.clinic_name,
            "doctor_code": dp.doctor_code,
            "is_verified": dp.is_verified,
            "verified_at": dp.verified_at.isoformat() if dp.verified_at else None,
            "created_at": dp.created_at.isoformat() if dp.created_at else None,
            "patient_count": patient_count,
            "last_access": last_access.isoformat() if last_access else None,
            "time_in_queue_hours": round((datetime.utcnow() - dp.created_at.replace(tzinfo=None)).total_seconds() / 3600, 1) if dp.created_at and not dp.is_verified else None,
        })

    _audit_log(db, user, "VIEW_DOCTORS_LIST")
    db.commit()
    return {"doctors": result, "total": len(result)}


@router.post("/admin/doctors/{user_id}/verify")
def verify_doctor(
    user_id: int,
    body: schemas.AdminVerifyDoctor,
    db: Session = Depends(get_db),
    user: models.User = Depends(_require_admin),
):
    """Approve a doctor's NMC verification."""
    dp = db.query(models.DoctorProfile).filter(
        models.DoctorProfile.user_id == user_id
    ).first()
    if not dp:
        raise HTTPException(status_code=404, detail="Doctor profile not found")
    if dp.is_verified:
        raise HTTPException(status_code=400, detail="Doctor is already verified")

    dp.is_verified = True
    dp.verified_at = datetime.utcnow()
    dp.verified_by = user.id

    _audit_log(db, user, "VERIFY_DOCTOR", target_user_id=user_id,
               details={"nmc_number": dp.nmc_number, "notes": body.notes})
    db.commit()
    return {"message": f"Doctor {dp.nmc_number} verified successfully"}


@router.post("/admin/doctors/{user_id}/reject")
def reject_doctor(
    user_id: int,
    body: schemas.AdminRejectDoctor,
    db: Session = Depends(get_db),
    user: models.User = Depends(_require_admin),
):
    """Reject a doctor's verification with reason."""
    dp = db.query(models.DoctorProfile).filter(
        models.DoctorProfile.user_id == user_id
    ).first()
    if not dp:
        raise HTTPException(status_code=404, detail="Doctor profile not found")

    dp.is_verified = False

    _audit_log(db, user, "REJECT_DOCTOR", target_user_id=user_id,
               details={"nmc_number": dp.nmc_number, "reason": body.reason, "notes": body.notes})
    db.commit()
    return {"message": f"Doctor {dp.nmc_number} verification rejected", "reason": body.reason}


# ---------------------------------------------------------------------------
# G5: Consent dashboard
# ---------------------------------------------------------------------------

@router.get("/admin/consent")
def consent_dashboard(
    db: Session = Depends(get_db),
    user: models.User = Depends(_require_admin),
):
    """Consent status for all users — DPDPA S6 compliance."""
    users = db.query(models.User).order_by(models.User.created_at.desc()).all()

    consented = []
    not_consented = []
    for u in users:
        record = {
            "id": u.id,
            "email": u.email,
            "full_name": u.full_name,
            "consent_timestamp": u.consent_timestamp.isoformat() if u.consent_timestamp else None,
            "consent_app_version": u.consent_app_version,
            "consent_language": u.consent_language,
            "ai_consent": u.ai_consent,
            "ai_consent_timestamp": u.ai_consent_timestamp.isoformat() if u.ai_consent_timestamp else None,
            "signed_up": u.created_at.isoformat() if u.created_at else None,
        }
        if u.consent_timestamp:
            consented.append(record)
        else:
            not_consented.append(record)

    _audit_log(db, user, "VIEW_CONSENT_DASHBOARD")
    db.commit()
    return {
        "total_users": len(users),
        "consented_count": len(consented),
        "not_consented_count": len(not_consented),
        "consented": consented,
        "not_consented": not_consented,
    }


# ---------------------------------------------------------------------------
# G4: Alerts center
# ---------------------------------------------------------------------------

@router.get("/admin/alerts")
def get_alerts(
    db: Session = Depends(get_db),
    user: models.User = Depends(_require_admin),
):
    """Computed alerts — critical readings, pending doctors, AI fallback, inactivity."""
    now = datetime.utcnow()
    alerts = []

    # 1. Critical readings unaddressed (no doctor note within 24h)
    critical_readings = db.query(models.HealthReading).filter(
        models.HealthReading.status_flag == "CRITICAL",
        models.HealthReading.created_at >= now - timedelta(days=7),
    ).all()
    for r in critical_readings:
        has_note = db.query(models.DoctorNote).filter(
            models.DoctorNote.profile_id == r.profile_id,
            models.DoctorNote.created_at >= r.created_at,
        ).first()
        if not has_note:
            hours_ago = round((now - r.created_at.replace(tzinfo=None)).total_seconds() / 3600, 1)
            if hours_ago >= 24:
                alerts.append({
                    "type": "CRITICAL_READING_UNADDRESSED",
                    "severity": "HIGH",
                    "message": f"Critical {r.reading_type} reading ({r.value_numeric} {r.unit_display}) unaddressed for {hours_ago:.0f}h",
                    "target_profile_id": r.profile_id,
                    "reading_id": r.id,
                    "created_at": r.created_at.isoformat(),
                    "hours_elapsed": hours_ago,
                })

    # 2. Doctors pending verification > 48h
    pending_doctors = db.query(models.DoctorProfile, models.User).join(
        models.User, models.DoctorProfile.user_id == models.User.id
    ).filter(
        models.DoctorProfile.is_verified == False,  # noqa: E712
    ).all()
    for dp, u in pending_doctors:
        if dp.created_at:
            hours_pending = (now - dp.created_at.replace(tzinfo=None)).total_seconds() / 3600
            severity = "MEDIUM" if hours_pending >= 48 else "INFO"
            alerts.append({
                "type": "DOCTOR_PENDING_VERIFICATION",
                "severity": severity,
                "message": f"Dr. {u.full_name} ({dp.nmc_number}) pending for {hours_pending:.0f}h",
                "target_user_id": u.id,
                "created_at": dp.created_at.isoformat(),
                "hours_pending": round(hours_pending, 1),
            })

    # 3. AI fallback spike (> 20% in last 24h)
    recent_ai = db.query(models.AiInsightLog).filter(
        models.AiInsightLog.created_at >= now - timedelta(hours=24),
    ).all()
    if len(recent_ai) >= 5:
        fallback_count = sum(1 for a in recent_ai if a.fallback_reason)
        fallback_rate = fallback_count / len(recent_ai) * 100
        if fallback_rate > 20:
            alerts.append({
                "type": "AI_FALLBACK_SPIKE",
                "severity": "HIGH",
                "message": f"AI fallback rate {fallback_rate:.0f}% in last 24h ({fallback_count}/{len(recent_ai)} calls)",
                "fallback_rate": round(fallback_rate, 1),
            })

    # 4. Patient inactivity — high-risk patients inactive 7+ days
    seven_days_ago = now - timedelta(days=7)
    all_profiles = db.query(models.Profile).all()
    for p in all_profiles:
        last_reading = db.query(func.max(models.HealthReading.created_at)).filter(
            models.HealthReading.profile_id == p.id,
        ).scalar()
        if last_reading is None:
            continue

        last_reading_naive = last_reading.replace(tzinfo=None) if last_reading.tzinfo else last_reading
        if last_reading_naive >= seven_days_ago:
            continue

        # Check if high-risk (had critical readings recently)
        had_critical = db.query(models.HealthReading).filter(
            models.HealthReading.profile_id == p.id,
            models.HealthReading.status_flag == "CRITICAL",
        ).first()

        days_inactive = (now - last_reading_naive).days
        if had_critical and days_inactive >= 7:
            alerts.append({
                "type": "PATIENT_INACTIVE_HIGH_RISK",
                "severity": "MEDIUM",
                "message": f"{p.name} (high-risk) inactive for {days_inactive} days",
                "target_profile_id": p.id,
                "days_inactive": days_inactive,
            })
        elif days_inactive >= 14:
            alerts.append({
                "type": "PATIENT_INACTIVE",
                "severity": "LOW",
                "message": f"{p.name} inactive for {days_inactive} days",
                "target_profile_id": p.id,
                "days_inactive": days_inactive,
            })

    # Sort by severity
    severity_order = {"HIGH": 0, "MEDIUM": 1, "INFO": 2, "LOW": 3}
    alerts.sort(key=lambda a: severity_order.get(a["severity"], 9))

    return {
        "alerts": alerts,
        "total": len(alerts),
        "high_count": sum(1 for a in alerts if a["severity"] == "HIGH"),
        "medium_count": sum(1 for a in alerts if a["severity"] == "MEDIUM"),
    }


# ---------------------------------------------------------------------------
# G3: Audit log viewer
# ---------------------------------------------------------------------------

@router.get("/admin/audit-log")
def get_audit_log(
    action_type: Optional[str] = None,
    target_user_id: Optional[int] = None,
    page: int = Query(1, ge=1),
    per_page: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    user: models.User = Depends(_require_admin),
):
    """View admin audit trail — CERT-In compliance."""
    q = db.query(models.AdminAuditLog).order_by(models.AdminAuditLog.created_at.desc())
    if action_type:
        q = q.filter(models.AdminAuditLog.action_type == action_type)
    if target_user_id:
        q = q.filter(models.AdminAuditLog.target_user_id == target_user_id)

    total = q.count()
    entries = q.offset((page - 1) * per_page).limit(per_page).all()

    # Resolve admin names
    admin_ids = {e.admin_user_id for e in entries}
    admin_map = {}
    if admin_ids:
        admins = db.query(models.User).filter(models.User.id.in_(admin_ids)).all()
        admin_map = {a.id: a.full_name for a in admins}

    result = []
    for e in entries:
        result.append({
            "id": e.id,
            "admin_name": admin_map.get(e.admin_user_id, "Unknown"),
            "admin_user_id": e.admin_user_id,
            "action_type": e.action_type,
            "target_user_id": e.target_user_id,
            "target_profile_id": e.target_profile_id,
            "details": json.loads(e.details) if e.details else None,
            "outcome": e.outcome,
            "created_at": e.created_at.isoformat() if e.created_at else None,
        })

    return {"entries": result, "total": total, "page": page, "per_page": per_page}
