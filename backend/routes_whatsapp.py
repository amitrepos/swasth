"""
WhatsApp Inbound Webhook — POST /api/whatsapp/inbound

Twilio calls this endpoint whenever a user sends a message (photo or text)
to your WhatsApp number. This router handles two sub-cases:

  Case A — Inbound PHOTO:
    1. Verify Twilio signature (if TWILIO_WEBHOOK_VALIDATE=True)
    2. Look up user by phone number
    3. Download image from Twilio media URL
    4. Scan with Gemini Vision → detect reading type + value
    5a. If user has 1 profile → save reading immediately, reply confirmation
    5b. If user has >1 profiles → save session, reply with profile selection menu

  Case B — Inbound TEXT (profile selection reply):
    1. Load pending session for this phone number
    2. Parse user's number reply ("1", "2", "3")
    3. Save reading to the chosen profile
    4. Clear session, reply confirmation

This route is PUBLIC (no JWT) — authenticated by Twilio HMAC signature.
Returns 200 OK with an empty TwiML body always, so Twilio considers delivery
successful regardless of internal errors.
"""

import logging
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, Request, Response
from sqlalchemy.orm import Session

import models
import whatsapp_inbound_service as svc
from config import settings
from database import get_db

logger = logging.getLogger(__name__)

router = APIRouter()


# ---------------------------------------------------------------------------
# Twilio signature verification helper
# ---------------------------------------------------------------------------

def _verify_twilio_signature(request_url: str, post_data: dict, signature: str) -> bool:
    """Validate Twilio HMAC-SHA1 webhook signature.

    Only called when TWILIO_WEBHOOK_VALIDATE=True. Returns True if valid,
    False if invalid or if credentials are missing.
    """
    try:
        from twilio.request_validator import RequestValidator
        validator = RequestValidator(settings.TWILIO_AUTH_TOKEN)
        return validator.validate(request_url, post_data, signature)
    except Exception:
        logger.error("wa_webhook: Signature validation error", exc_info=True)
        return False


# ---------------------------------------------------------------------------
# Main webhook endpoint
# ---------------------------------------------------------------------------

@router.post("/whatsapp/inbound")
async def whatsapp_inbound(
    request: Request,
    db: Session = Depends(get_db),
):
    """Receive and process inbound WhatsApp messages from Twilio.

    Always returns 200 with empty body — Twilio requires this to mark delivery
    successful. All errors are handled internally and replied to the user.
    """
    # Parse form data from Twilio
    try:
        form = await request.form()
        form_dict = dict(form)
    except Exception:
        logger.error("wa_webhook: Failed to parse form data", exc_info=True)
        return Response(content="", media_type="text/xml", status_code=200)

    from_number_raw = form_dict.get("From", "")
    body_text = (form_dict.get("Body") or "").strip()
    media_url = form_dict.get("MediaUrl0")
    num_media = int(form_dict.get("NumMedia", "0") or "0")
    message_sid = form_dict.get("MessageSid")

    # Normalize phone number for all lookups
    phone = svc.normalize_phone(from_number_raw)

    logger.info(
        "wa_webhook: inbound from=%s sid=%s media=%s body_preview=%s",
        phone, message_sid, bool(media_url), body_text[:30] if body_text else ""
    )

    # ── Optional: verify Twilio webhook signature ─────────────────────────
    if settings.TWILIO_WEBHOOK_VALIDATE:
        signature = request.headers.get("X-Twilio-Signature", "")
        # Reconstruct the full public URL for validation
        url = str(request.url)
        if not _verify_twilio_signature(url, form_dict, signature):
            logger.warning("wa_webhook: Invalid Twilio signature from %s", phone)
            # Still return 200 — don't reveal validation to external callers
            return Response(content="", media_type="text/xml", status_code=200)

    # ── Route to appropriate handler ──────────────────────────────────────
    if num_media > 0 and media_url:
        await _handle_photo(phone, media_url, message_sid, db)
    else:
        await _handle_text(phone, body_text, message_sid, db)

    # Always return 200 empty TwiML so Twilio marks it delivered
    return Response(content="<?xml version='1.0' encoding='UTF-8'?><Response></Response>",
                    media_type="text/xml", status_code=200)


# ---------------------------------------------------------------------------
# Handler: inbound photo
# ---------------------------------------------------------------------------

async def _handle_photo(
    phone: str,
    media_url: str,
    message_sid: str,
    db: Session,
) -> None:
    """Process an inbound WhatsApp photo — scan for health reading."""

    # Step 1: Look up user
    user = svc.lookup_user_by_phone(phone, db)
    if not user:
        svc.send_reply(
            phone,
            "👋 Your phone number is not linked to any Swasth account.\n\n"
            "Please register in the Swasth app first, then send your photo again."
        )
        svc.log_inbound(phone, message_sid, "image", "user_not_found", db)
        return

    # Step 2: Download image
    image_bytes = svc.download_twilio_media(media_url)
    if not image_bytes:
        svc.send_reply(
            phone,
            "⚠️ Could not download your photo. Please try again or log the reading in the app."
        )
        svc.log_inbound(phone, message_sid, "image", "download_failed", db)
        return

    # Step 3: Scan with Gemini Vision
    svc.send_reply(phone, "🔍 Scanning your photo...")  # instant acknowledgement
    reading_data = svc.scan_device_image(image_bytes, db)

    if not reading_data:
        svc.send_reply(
            phone,
            "❌ Could not read any health value from your photo.\n\n"
            "Please make sure the device display is clearly visible and try again, "
            "or log the reading manually in the Swasth app."
        )
        svc.log_inbound(phone, message_sid, "image", "scan_failed", db)
        return

    reading_summary = svc.format_reading_summary(reading_data)

    # Step 4: Get user's profiles (owner access only)
    profiles = (
        db.query(models.Profile)
        .join(models.ProfileAccess)
        .filter(
            models.ProfileAccess.user_id == user.id,
            models.ProfileAccess.access_level == "owner",
        )
        .all()
    )

    if not profiles:
        svc.send_reply(
            phone,
            "⚠️ No health profiles found for your account.\n\n"
            "Please create a profile in the Swasth app first."
        )
        svc.log_inbound(phone, message_sid, "image", "no_profiles", db)
        return

    # Step 5a: Single profile — save immediately
    if len(profiles) == 1:
        profile = profiles[0]
        reading = svc.save_health_reading(reading_data, profile.id, user.id, db)

        if reading:
            tz_name = getattr(user, "timezone", None) or "Asia/Kolkata"
            if tz_name == "UTC":
                tz_name = "Asia/Kolkata"
            user_tz = ZoneInfo(tz_name)
            local_dt = reading.reading_timestamp.astimezone(user_tz)
            svc.send_reply(
                phone,
                f"✅ {reading_summary} saved for *{profile.name}*.\n\n"
                f"📅 {local_dt.strftime('%d %b %Y, %I:%M %p')}\n\n"
                "💚 Keep monitoring! — *Swasth*"
            )
            svc.log_inbound(
                phone, message_sid, "image", "reading_saved", db,
                ai_detected_type=reading_data.get("reading_type"),
                profile_id=profile.id,
                reading_id=reading.id,
            )
        else:
            svc.send_reply(
                phone,
                "⚠️ Reading detected but could not be saved. Please try again or use the app."
            )
            svc.log_inbound(phone, message_sid, "image", "save_failed", db,
                            ai_detected_type=reading_data.get("reading_type"))
        return

    # Step 5b: Multiple profiles — create session, ask user to choose
    profile_choices = [
        {"id": p.id, "name": p.name, "relationship": p.relationship}
        for p in profiles
    ]
    svc.create_session(phone, reading_data, profile_choices, db)

    menu = svc.build_profile_menu(profile_choices)
    svc.send_reply(
        phone,
        f"📸 {reading_summary}\n\n"
        f"Which profile is this reading for?\n\n"
        f"{menu}\n\n"
        f"Reply with just the number (e.g. *1*).\n"
        f"_(This will expire in {settings.WHATSAPP_SESSION_TTL_MINUTES} minutes)_"
    )
    svc.log_inbound(
        phone, message_sid, "image", "awaiting_profile", db,
        ai_detected_type=reading_data.get("reading_type"),
    )


# ---------------------------------------------------------------------------
# Handler: inbound text (profile selection or unknown)
# ---------------------------------------------------------------------------

async def _handle_text(
    phone: str,
    body_text: str,
    message_sid: str,
    db: Session,
) -> None:
    """Handle a text message — either a profile number reply or unknown input."""

    # Check for an active pending session first
    session = svc.get_active_session(phone, db)

    if not session:
        # No active session — unknown message
        # Check if there WAS an expired session (friendly nudge vs. generic help)
        expired = (
            db.query(models.WhatsAppSession)
            .filter(models.WhatsAppSession.phone_number == phone)
            .first()
        )
        svc.log_inbound(phone, message_sid, "text",
                        "expired_session" if expired else "no_session", db)

        if expired:
            # Clean up stale row
            db.query(models.WhatsAppSession).filter(
                models.WhatsAppSession.phone_number == phone
            ).delete()
            db.commit()
            svc.send_reply(
                phone,
                "⏰ Your previous photo session has expired.\n\n"
                "Please send your device photo again and reply quickly with the profile number."
            )
        else:
            svc.send_reply(
                phone,
                "👋 Hi! Send a photo of your glucometer, blood pressure monitor, "
                "or weighing scale and I'll log the reading for you.\n\n"
                "You can also open the *Swasth* app to log readings manually."
            )
        return

    # We have an active session — parse the profile number
    profile_choices = session.profile_choices_json  # list of {id, name, relationship}
    num_profiles = len(profile_choices)

    # Accept "1", "2", "3", etc.
    chosen_index = None
    stripped = body_text.strip()
    if stripped.isdigit():
        idx = int(stripped) - 1
        if 0 <= idx < num_profiles:
            chosen_index = idx

    if chosen_index is None:
        # Re-send the menu
        menu = svc.build_profile_menu(profile_choices)
        reading_summary = svc.format_reading_summary(session.pending_reading_json)
        svc.send_reply(
            phone,
            f"Please reply with a number between 1 and {num_profiles}.\n\n"
            f"{reading_summary}\n\n{menu}"
        )
        svc.log_inbound(phone, message_sid, "text", "invalid_reply", db)
        return

    # Valid choice — look up user and save
    user = svc.lookup_user_by_phone(phone, db)
    if not user:
        svc.send_reply(phone, "⚠️ Could not find your account. Please re-register in the app.")
        svc.log_inbound(phone, message_sid, "text", "user_not_found", db)
        svc.clear_session(phone, db)
        return

    profile_choice = profile_choices[chosen_index]
    profile_id = profile_choice["id"]
    profile_name = profile_choice["name"]

    reading = svc.save_health_reading(
        session.pending_reading_json, profile_id, user.id, db
    )
    if not reading:
        svc.send_reply(
            phone,
            "⚠️ Could not save the reading. Please try again or use the Swasth app."
        )
        svc.log_inbound(phone, message_sid, "text", "save_failed", db)
        return

    reading_summary = svc.format_reading_summary(session.pending_reading_json)
    tz_name = getattr(user, "timezone", None) or "Asia/Kolkata"
    if tz_name == "UTC":
        tz_name = "Asia/Kolkata"
    user_tz = ZoneInfo(tz_name)
    local_dt = reading.reading_timestamp.astimezone(user_tz)
    svc.send_reply(
        phone,
        f"✅ {reading_summary} saved for *{profile_name}*.\n\n"
        f"📅 {local_dt.strftime('%d %b %Y, %I:%M %p')}\n\n"
        "💚 Keep monitoring! — *Swasth*"
    )
    svc.log_inbound(
        phone, message_sid, "text", "reading_saved", db,
        ai_detected_type=session.pending_reading_json.get("reading_type"),
        profile_id=profile_id,
        reading_id=reading.id,
    )

    svc.clear_session(phone, db)
