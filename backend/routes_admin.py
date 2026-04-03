"""Admin dashboard endpoints — metrics, user management, operational stats.

All endpoints require is_admin=True on the authenticated user.
"""
import os
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import HTMLResponse
from sqlalchemy import func, distinct, case
from sqlalchemy.orm import Session
from datetime import datetime, date, timedelta

import models
from database import get_db
from dependencies import get_current_user

router = APIRouter()

_DASHBOARD_HTML = os.path.join(os.path.dirname(__file__), "admin_dashboard.html")


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

    return {
        "user": {
            "id": target.id,
            "email": target.email,
            "full_name": target.full_name,
            "phone_number": target.phone_number,
            "is_admin": target.is_admin,
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
    db.commit()
    return {"message": "AI memory updated", "profile_id": profile_id}


@router.delete("/admin/profiles/{profile_id}/ai-memory")
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
        db.commit()
    return {"message": "AI memory reset", "profile_id": profile_id}


@router.post("/admin/users/{user_id}/make-admin")
def make_admin(
    user_id: int,
    db: Session = Depends(get_db),
    user: models.User = Depends(_require_admin),
):
    """Grant admin access to a user."""
    target = db.query(models.User).filter(models.User.id == user_id).first()
    if not target:
        raise HTTPException(status_code=404, detail="User not found")
    target.is_admin = True
    db.commit()
    return {"message": f"{target.email} is now an admin"}


@router.post("/admin/users/{user_id}/remove-admin")
def remove_admin(
    user_id: int,
    db: Session = Depends(get_db),
    user: models.User = Depends(_require_admin),
):
    """Remove admin access from a user."""
    if user_id == user.id:
        raise HTTPException(status_code=400, detail="Cannot remove your own admin access")
    target = db.query(models.User).filter(models.User.id == user_id).first()
    if not target:
        raise HTTPException(status_code=404, detail="User not found")
    target.is_admin = False
    db.commit()
    return {"message": f"{target.email} is no longer an admin"}
