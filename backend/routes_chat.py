"""AI Chat endpoints with rate limiting and conversation memory."""

import base64
from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import func
from sqlalchemy.orm import Session
from datetime import datetime, date, timedelta
from typing import Optional
from slowapi import Limiter
from slowapi.util import get_remote_address
import os

import models
import ai_service
from database import get_db
from dependencies import get_current_user, get_profile_access_or_403, get_profile_editor_or_403
from config import settings

router = APIRouter()
_enabled = os.environ.get("TESTING", "").lower() != "true"
limiter = Limiter(key_func=get_remote_address, enabled=_enabled)


# ---------------------------------------------------------------------------
# Rate limit helpers
# ---------------------------------------------------------------------------

def _period_start() -> datetime:
    """Return the start of the current quota period."""
    today = date.today()
    period = settings.CHAT_QUOTA_PERIOD.lower()
    if period == "weekly":
        # Monday 00:00
        monday = today - timedelta(days=today.weekday())
        return datetime.combine(monday, datetime.min.time())
    if period == "monthly":
        return datetime.combine(today.replace(day=1), datetime.min.time())
    # Default: daily
    return datetime.combine(today, datetime.min.time())


def _period_end() -> datetime:
    """Return the reset time for the current quota period."""
    today = date.today()
    period = settings.CHAT_QUOTA_PERIOD.lower()
    if period == "weekly":
        monday = today - timedelta(days=today.weekday())
        return datetime.combine(monday + timedelta(days=7), datetime.min.time())
    if period == "monthly":
        if today.month == 12:
            next_month = today.replace(year=today.year + 1, month=1, day=1)
        else:
            next_month = today.replace(month=today.month + 1, day=1)
        return datetime.combine(next_month, datetime.min.time())
    # Default: daily — midnight tonight
    return datetime.combine(today + timedelta(days=1), datetime.min.time())


def _get_quota_info(profile_id: int, db: Session) -> dict:
    """Return quota usage for the current period, per profile."""
    start = _period_start()
    used = db.query(func.count(models.ChatMessage.id)).filter(
        models.ChatMessage.profile_id == profile_id,
        models.ChatMessage.created_at >= start,
    ).scalar() or 0

    limit = settings.CHAT_QUOTA_LIMIT
    return {
        "limit": limit,
        "used": used,
        "remaining": max(0, limit - used),
        "period": settings.CHAT_QUOTA_PERIOD,
        "resets_at": _period_end().isoformat(),
    }


# ---------------------------------------------------------------------------
# Health data summary builder (reused from routes_health.py pattern)
# ---------------------------------------------------------------------------

def _build_health_summary(profile_id: int, db: Session) -> str:
    """Build a compact 30-day health data summary for AI context."""
    profile = db.query(models.Profile).filter(models.Profile.id == profile_id).first()
    if not profile:
        return ""

    thirty_days_ago = datetime.combine(date.today() - timedelta(days=29), datetime.min.time())
    recent = (
        db.query(models.HealthReading)
        .filter(
            models.HealthReading.profile_id == profile_id,
            models.HealthReading.reading_timestamp >= thirty_days_ago,
        )
        .order_by(models.HealthReading.reading_timestamp.asc())
        .all()
    )

    glucose_vals = [r.glucose_value for r in recent if r.reading_type == "glucose" and r.glucose_value]
    bp_readings = [(r.systolic, r.diastolic) for r in recent if r.reading_type == "blood_pressure" and r.systolic and r.diastolic]

    age_desc = f"{profile.age} years" if profile.age else "unknown age"
    gender = profile.gender or "Unknown"
    conditions = ", ".join(profile.medical_conditions) if profile.medical_conditions else "None reported"
    medications = profile.current_medications or "None reported"

    parts = [f"Patient: {age_desc}, {gender}. Conditions: {conditions}. Medications: {medications}."]

    if glucose_vals:
        avg_g = sum(glucose_vals) / len(glucose_vals)
        parts.append(
            f"Glucose (30d, {len(glucose_vals)} readings): avg {avg_g:.0f}, "
            f"range {min(glucose_vals):.0f}–{max(glucose_vals):.0f} mg/dL. "
            f"Latest: {glucose_vals[-1]:.0f} mg/dL."
        )

    if bp_readings:
        sys_vals = [s for s, _ in bp_readings]
        dia_vals = [d for _, d in bp_readings]
        parts.append(
            f"BP (30d, {len(bp_readings)} readings): avg {sum(sys_vals)/len(sys_vals):.0f}/{sum(dia_vals)/len(dia_vals):.0f} mmHg. "
            f"Latest: {sys_vals[-1]:.0f}/{dia_vals[-1]:.0f} mmHg."
        )

    return "\n".join(parts)


# ---------------------------------------------------------------------------
# Conversation summary generation
# ---------------------------------------------------------------------------

def _update_context_profile(profile_id: int, db: Session):
    """Regenerate the rolling conversation summary for a profile."""
    # Fetch recent messages (last 20 for summary context)
    recent_msgs = (
        db.query(models.ChatMessage)
        .filter(models.ChatMessage.profile_id == profile_id)
        .order_by(models.ChatMessage.created_at.desc())
        .limit(20)
        .all()
    )
    if not recent_msgs:
        return

    # Get existing context
    ctx = db.query(models.ChatContextProfile).filter(
        models.ChatContextProfile.profile_id == profile_id,
    ).first()
    existing_summary = ctx.summary if ctx else ""

    # Build conversation text for summarization
    conv_lines = []
    for msg in reversed(recent_msgs):
        conv_lines.append(f"Patient: {msg.user_message}")
        conv_lines.append(f"AI: {msg.ai_response}")
    conversation_text = "\n".join(conv_lines[-20:])  # Last 10 exchanges

    summary_prompt = f"""Summarize these patient-AI health conversations into a brief profile (max 200 words).
Focus on: patient concerns, advice given, action items, medication adherence issues, lifestyle factors mentioned, recurring topics.

Existing context to merge with:
{existing_summary}

Recent conversations:
{conversation_text}

Write a single cohesive summary. Keep only the most important and actionable information."""

    new_summary = ai_service.generate_health_insight(
        summary_prompt, profile_id, db,
        prompt_summary="chat context summary generation",
    )

    if not new_summary:
        return  # AI unavailable — skip this cycle

    total_count = db.query(func.count(models.ChatMessage.id)).filter(
        models.ChatMessage.profile_id == profile_id,
    ).scalar() or 0

    if ctx:
        ctx.summary = new_summary
        ctx.message_count = total_count
    else:
        ctx = models.ChatContextProfile(
            profile_id=profile_id,
            summary=new_summary,
            message_count=total_count,
        )
        db.add(ctx)
    db.commit()


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.post("/chat/send")
@limiter.limit("10/minute")
def send_chat_message(
    request: Request,
    data: dict,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """Send a chat message and get an AI response."""
    profile_id = data.get("profile_id")
    message = data.get("message", "").strip()

    if not profile_id or not message:
        raise HTTPException(status_code=400, detail="profile_id and message are required")

    # Viewers can read chat history but cannot send messages
    get_profile_editor_or_403(profile_id, user, db)

    # --- Rate limit check ---
    quota = _get_quota_info(profile_id, db)
    if quota["remaining"] <= 0:
        return {
            "error": "quota_exceeded",
            "remaining": 0,
            "resets_at": quota["resets_at"],
            "message": f"You've used all {quota['limit']} questions for this {quota['period']} period.",
        }

    # --- Build multi-turn prompt ---
    # 1. Conversation context profile
    ctx = db.query(models.ChatContextProfile).filter(
        models.ChatContextProfile.profile_id == profile_id,
    ).first()
    context_summary = ctx.summary if ctx else ""

    # 2. Health data summary
    health_summary = _build_health_summary(profile_id, db)

    # 3. Recent chat messages (last 10)
    recent_msgs = (
        db.query(models.ChatMessage)
        .filter(models.ChatMessage.profile_id == profile_id)
        .order_by(models.ChatMessage.created_at.desc())
        .limit(10)
        .all()
    )
    chat_history = ""
    if recent_msgs:
        lines = []
        for msg in reversed(recent_msgs):
            lines.append(f"Patient: {msg.user_message}")
            lines.append(f"AI: {msg.ai_response}")
        chat_history = "\n".join(lines)

    # 4. Assemble prompt
    prompt = f"""You are a caring, knowledgeable health assistant for this patient. Give helpful, personalised advice.

{health_summary}

{f"Conversation history (what you know about this patient from past chats):{chr(10)}{context_summary}" if context_summary else ""}

{f"Recent conversation:{chr(10)}{chat_history}" if chat_history else ""}

Patient: {message}

Rules:
- Be warm and conversational, not clinical.
- Give actionable advice when possible.
- If the question is about a critical reading, be urgent and recommend seeing a doctor.
- If you don't know something, say so honestly.
- Keep responses to 2-4 sentences.
- Speak directly to the patient."""

    # --- Check for image attachment ---
    image_b64 = data.get("image_base64")
    display_message = message

    # --- Call AI (with or without image) ---
    import time
    start = time.time()
    ai_response = None

    if image_b64:
        # Use vision pipeline: Gemini Vision → DeepSeek text fallback → None
        image_bytes = base64.b64decode(image_b64)
        vision_prompt = f"""{prompt}

The patient has uploaded a medical image/report. Please analyze what you see and provide helpful insights.
- If it's a medical report, summarize key findings.
- If it's an X-ray or scan, describe what you observe (with caveats that you're AI, not a radiologist).
- If it's a prescription, list the medications and their purposes.
- Always recommend consulting their doctor for definitive interpretation."""

        ai_response = ai_service.generate_vision_insight(
            vision_prompt, image_bytes, profile_id, db,
            prompt_summary=f"chat-image: {display_message[:80]}",
        )

    if not ai_response:
        ai_response = ai_service.generate_health_insight(
            prompt, profile_id, db,
            prompt_summary=f"chat: {display_message[:100]}",
        )
    latency = int((time.time() - start) * 1000)
    message = display_message  # Store clean message, not base64 blob

    if not ai_response:
        ai_response = "I'm sorry, I'm having trouble connecting right now. Please try again in a moment, or consult your doctor for urgent concerns."

    # --- Save message ---
    # Get the model used from the latest AI log
    latest_log = (
        db.query(models.AiInsightLog)
        .filter(models.AiInsightLog.profile_id == profile_id)
        .order_by(models.AiInsightLog.id.desc())
        .first()
    )

    chat_msg = models.ChatMessage(
        profile_id=profile_id,
        user_id=user.id,
        user_message=message,
        ai_response=ai_response,
        model_used=latest_log.model_used if latest_log else "unknown",
        tokens_used=latest_log.tokens_used if latest_log else None,
        latency_ms=latency,
    )
    db.add(chat_msg)
    db.commit()
    db.refresh(chat_msg)

    # --- Trigger summary if interval reached ---
    total_msgs = db.query(func.count(models.ChatMessage.id)).filter(
        models.ChatMessage.profile_id == profile_id,
    ).scalar() or 0

    if total_msgs > 0 and total_msgs % settings.CHAT_SUMMARY_INTERVAL == 0:
        try:
            _update_context_profile(profile_id, db)
        except Exception:
            pass  # Non-critical — don't fail the chat response

    # Updated quota
    new_quota = _get_quota_info(profile_id, db)

    return {
        "id": chat_msg.id,
        "user_message": chat_msg.user_message,
        "ai_response": chat_msg.ai_response,
        "model_used": chat_msg.model_used,
        "remaining_quota": new_quota["remaining"],
        "resets_at": new_quota["resets_at"],
        "created_at": chat_msg.created_at.isoformat() if chat_msg.created_at else None,
    }


@router.get("/chat/messages")
def get_chat_messages(
    profile_id: int,
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """Get chat history for a profile."""
    get_profile_access_or_403(profile_id, user, db)

    messages = (
        db.query(models.ChatMessage)
        .filter(models.ChatMessage.profile_id == profile_id)
        .order_by(models.ChatMessage.created_at.asc())
        .offset(offset)
        .limit(limit)
        .all()
    )

    quota = _get_quota_info(profile_id, db)

    return {
        "messages": [
            {
                "id": m.id,
                "user_message": m.user_message,
                "ai_response": m.ai_response,
                "created_at": m.created_at.isoformat() if m.created_at else None,
            }
            for m in messages
        ],
        "quota": quota,
    }


@router.get("/chat/quota")
def get_chat_quota(
    profile_id: int,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """Check remaining chat quota for a profile."""
    get_profile_access_or_403(profile_id, user, db)
    return _get_quota_info(profile_id, db)
