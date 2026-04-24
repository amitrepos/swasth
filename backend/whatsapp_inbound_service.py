"""
WhatsApp Inbound Service — handles incoming photo messages via Twilio webhook.

Responsibilities:
  1. Normalize phone numbers from Twilio format ("whatsapp:+919876543210") to
     canonical (+91XXXXXXXXXX) for DB lookup.
  2. Look up the Swasth user by their phone number.
  3. Download image bytes from Twilio's media URL.
  4. Call Gemini Vision to detect the reading type and value.
  5. If the user has only one profile → save immediately.
  6. If the user has multiple profiles → create a WhatsAppSession and ask.
  7. On profile selection reply → load session, save reading, clear session.
  8. Persist an audit row in whatsapp_inbound_logs for every message.

This module is intentionally decoupled from:
  - twilio_service.py   (outbound only — weekly reports)
  - report_service.py   (scheduled delivery pipeline)
  - routes_health.py    (app-facing auth-protected API)

None of those files are modified by this feature.
"""

import json
import logging
import re
from datetime import datetime, timedelta, timezone
from typing import Optional

import requests
from sqlalchemy.orm import Session

import ai_service
import models
from config import settings
from encryption_service import encrypt, encrypt_float
from health_utils import classify_bp, classify_glucose
from twilio_service import whatsapp_service

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Gemini Vision prompt — health device OCR
# ---------------------------------------------------------------------------

DEVICE_SCAN_PROMPT = """You are a health data extractor for a medical app in India.

Analyze this image. It may be a photo of a glucometer, blood pressure monitor,
or weighing scale display. Read any numeric values clearly visible on the screen.

Detection priority: glucose > blood_pressure > weight > spo2.

For blood pressure, extract ALL values shown (systolic, diastolic, pulse).
For glucose, the value is in mg/dL (most Indian devices) or mmol/L.

Respond ONLY in this exact JSON format, nothing else:
{
  "reading_type": "glucose",
  "glucose_value": 126,
  "systolic": null,
  "diastolic": null,
  "pulse_rate": null,
  "weight_value": null,
  "spo2_value": null,
  "confidence": 0.92,
  "unit_detected": "mg/dL"
}

If reading_type is "blood_pressure", set systolic and diastolic (integers).
If reading_type is "weight", set weight_value (float in kg).
If reading_type is "spo2", set spo2_value (integer percentage).
If no clear health reading is visible, return:
{"reading_type": null, "confidence": 0}
"""

# ---------------------------------------------------------------------------
# Phone number normalization
# ---------------------------------------------------------------------------

def normalize_phone(raw: str) -> str:
    """Strip Twilio prefix and normalize to +91XXXXXXXXXX (or +<country><digits>).

    Examples:
        "whatsapp:+919876543210" → "+919876543210"
        "+919876543210"          → "+919876543210"
        "9876543210"             → "+919876543210"  (10-digit Indian number)
        "919876543210"           → "+919876543210"  (12-digit without +)
    """
    # Remove whatsapp: prefix
    phone = raw.strip()
    if phone.startswith("whatsapp:"):
        phone = phone[len("whatsapp:"):]

    # Remove spaces, dashes, parens
    phone = re.sub(r"[\s\-\(\)]", "", phone)

    # Already has + prefix — return as-is
    if phone.startswith("+"):
        return phone

    # 12-digit number starting with 91 (Indian country code without +)
    if phone.startswith("91") and len(phone) == 12:
        return f"+{phone}"

    # 10-digit number — assume Indian
    if len(phone) == 10 and phone.isdigit():
        return f"+91{phone}"

    # Fallback — just prepend + if missing
    return f"+{phone}"


# ---------------------------------------------------------------------------
# User lookup by phone number
# ---------------------------------------------------------------------------

def lookup_user_by_phone(phone_canonical: str, db: Session) -> Optional[models.User]:
    """Find an active user whose phone number matches (via normalized hash)."""
    from encryption_service import hash_phone
    # Normalized hash already handles +91/10-digit/various format variants
    h = hash_phone(phone_canonical)
    if h is None:
        return None
    return db.query(models.User).filter(
        models.User.phone_hash == h,
        models.User.is_active == True,
    ).first()


# ---------------------------------------------------------------------------
# Download image from Twilio media URL
# ---------------------------------------------------------------------------

def download_twilio_media(media_url: str) -> Optional[bytes]:
    """Fetch image bytes from Twilio's media URL using Basic Auth.

    Twilio media URLs require HTTP Basic Auth with account SID / auth token.
    Returns None on any failure — caller handles gracefully.
    """
    if not media_url:
        return None

    if not settings.TWILIO_ACCOUNT_SID or not settings.TWILIO_AUTH_TOKEN:
        logger.warning("wa_inbound: Twilio credentials missing — cannot download media")
        return None

    try:
        response = requests.get(
            media_url,
            auth=(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN),
            timeout=15,
        )
        response.raise_for_status()
        return response.content
    except Exception:
        logger.error("wa_inbound: Failed to download Twilio media from %s", media_url, exc_info=True)
        return None


# ---------------------------------------------------------------------------
# Gemini Vision scan
# ---------------------------------------------------------------------------

def scan_device_image(image_bytes: bytes, db: Session) -> Optional[dict]:
    """Run Gemini Vision on the image. Returns parsed dict or None.

    Uses profile_id=0 for ai_insight_log (no specific profile at scan time).
    The reading hasn't been attributed to a profile yet.
    """
    try:
        raw = ai_service.generate_vision_insight(
            prompt=DEVICE_SCAN_PROMPT,
            image_bytes=image_bytes,
            profile_id=0,   # placeholder — attributed after profile selection
            db=db,
            prompt_summary="whatsapp-device-scan",
            mime_type="image/jpeg",
        )
        if not raw:
            return None

        # Extract JSON block from response
        match = re.search(r"\{.*?\}", raw, re.DOTALL)
        if not match:
            logger.warning("wa_inbound: Gemini returned no JSON block: %s", raw[:200])
            return None

        parsed = json.loads(match.group())

        reading_type = parsed.get("reading_type")
        if reading_type not in ("glucose", "blood_pressure", "weight", "spo2"):
            return None

        confidence = float(parsed.get("confidence", 0))
        if confidence < 0.5:
            logger.info("wa_inbound: Low confidence scan (%.2f) — rejecting", confidence)
            return None

        return parsed

    except (json.JSONDecodeError, ValueError):
        logger.warning("wa_inbound: Failed to parse Gemini JSON response", exc_info=True)
        return None
    except Exception:
        logger.error("wa_inbound: Unexpected error in scan_device_image", exc_info=True)
        return None


# ---------------------------------------------------------------------------
# Save health reading (mirrors routes_health.py save_reading logic)
# ---------------------------------------------------------------------------

def save_health_reading(
    reading_data: dict,
    profile_id: int,
    user_id: int,
    db: Session,
) -> Optional[models.HealthReading]:
    """Insert a HealthReading row from WhatsApp-scanned data.

    Mirrors the encryption + status_flag computation from routes_health.py
    save_reading(), without duplicating the FastAPI route dependencies.
    """
    reading_type = reading_data.get("reading_type")
    now = datetime.now(timezone.utc)

    # --- Build value_numeric and unit_display ---
    if reading_type == "glucose":
        value = reading_data.get("glucose_value")
        if value is None:
            return None
        value_numeric = float(value)
        unit_display = reading_data.get("unit_detected") or "mg/dL"
        status_flag = classify_glucose(value_numeric)

    elif reading_type == "blood_pressure":
        systolic = reading_data.get("systolic")
        diastolic = reading_data.get("diastolic")
        if systolic is None or diastolic is None:
            return None
        value_numeric = float(systolic)
        unit_display = "mmHg"
        status_flag = classify_bp(float(systolic), float(diastolic))

    elif reading_type == "weight":
        value = reading_data.get("weight_value")
        if value is None:
            return None
        value_numeric = float(value)
        unit_display = "kg"
        status_flag = None  # no status classification for weight

    elif reading_type == "spo2":
        value = reading_data.get("spo2_value")
        if value is None:
            return None
        value_numeric = float(value)
        unit_display = "%"
        from health_utils import classify_spo2
        status_flag = classify_spo2(value_numeric)

    else:
        return None

    db_reading = models.HealthReading(
        profile_id=profile_id,
        logged_by=user_id,
        reading_type=reading_type,
        glucose_value=reading_data.get("glucose_value"),
        glucose_unit=reading_data.get("unit_detected") if reading_type == "glucose" else None,
        sample_type="random",  # WhatsApp submission — timing unknown
        systolic=reading_data.get("systolic"),
        diastolic=reading_data.get("diastolic"),
        pulse_rate=reading_data.get("pulse_rate"),
        bp_unit="mmHg" if reading_type == "blood_pressure" else None,
        bp_status=status_flag if reading_type == "blood_pressure" else None,
        spo2_value=reading_data.get("spo2_value"),
        spo2_unit="%" if reading_type == "spo2" else None,
        weight_value=reading_data.get("weight_value"),
        weight_unit="kg" if reading_type == "weight" else None,
        value_numeric=value_numeric,
        unit_display=unit_display,
        status_flag=status_flag,
        notes="Logged via WhatsApp photo",
        reading_timestamp=now,
    )

    # AES-256-GCM encrypted copies (SPDI compliance — mirrors routes_health.py)
    if db_reading.glucose_value is not None:
        db_reading.glucose_value_enc = encrypt_float(db_reading.glucose_value)
    if db_reading.systolic is not None:
        db_reading.systolic_enc = encrypt_float(db_reading.systolic)
    if db_reading.diastolic is not None:
        db_reading.diastolic_enc = encrypt_float(db_reading.diastolic)
    if db_reading.pulse_rate is not None:
        db_reading.pulse_rate_enc = encrypt_float(db_reading.pulse_rate)
    if db_reading.spo2_value is not None:
        db_reading.spo2_enc = encrypt_float(db_reading.spo2_value)
    if db_reading.weight_value is not None:
        db_reading.weight_value_enc = encrypt_float(db_reading.weight_value)
    db_reading.notes_enc = encrypt("Logged via WhatsApp photo")

    db.add(db_reading)
    db.commit()
    db.refresh(db_reading)

    # Dispatch critical alert if needed (same as app reading flow)
    if status_flag in ("CRITICAL", "HIGH - STAGE 2"):
        try:
            from alert_service import dispatch_critical_alert
            profile = db.query(models.Profile).filter(
                models.Profile.id == profile_id
            ).first()
            if profile:
                dispatch_critical_alert(
                    reading=db_reading,
                    profile=profile,
                    logger_user_id=user_id,
                    db=db,
                )
                db.commit()
        except Exception:
            db.rollback()
            logger.error("wa_inbound: Critical alert dispatch failed — reading already saved", exc_info=True)

    return db_reading


# ---------------------------------------------------------------------------
# Session management
# ---------------------------------------------------------------------------

def get_active_session(phone_canonical: str, db: Session) -> Optional[models.WhatsAppSession]:
    """Return the most recent non-expired session for this phone, or None."""
    now = datetime.now(timezone.utc)
    session = (
        db.query(models.WhatsAppSession)
        .filter(
            models.WhatsAppSession.phone_number == phone_canonical,
            models.WhatsAppSession.expires_at > now,
        )
        .order_by(models.WhatsAppSession.created_at.desc())
        .first()
    )
    return session


def create_session(
    phone_canonical: str,
    reading_data: dict,
    profile_choices: list,
    db: Session,
) -> models.WhatsAppSession:
    """Store pending reading and profile options while awaiting user reply."""
    # Delete any existing session for this phone first (prevents duplicates)
    db.query(models.WhatsAppSession).filter(
        models.WhatsAppSession.phone_number == phone_canonical,
    ).delete()

    ttl = settings.WHATSAPP_SESSION_TTL_MINUTES
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=ttl)

    session = models.WhatsAppSession(
        phone_number=phone_canonical,
        state="awaiting_profile",
        pending_reading_json=reading_data,
        profile_choices_json=profile_choices,
        expires_at=expires_at,
    )
    db.add(session)
    db.commit()
    db.refresh(session)
    return session


def clear_session(phone_canonical: str, db: Session) -> None:
    """Delete all sessions for this phone (after successful profile selection)."""
    db.query(models.WhatsAppSession).filter(
        models.WhatsAppSession.phone_number == phone_canonical,
    ).delete()
    db.commit()


# ---------------------------------------------------------------------------
# Audit logging
# ---------------------------------------------------------------------------

def log_inbound(
    phone: str,
    message_sid: Optional[str],
    message_type: str,
    outcome: str,
    db: Session,
    ai_detected_type: Optional[str] = None,
    profile_id: Optional[int] = None,
    reading_id: Optional[int] = None,
) -> None:
    """Write one audit row to whatsapp_inbound_logs. Never raises."""
    try:
        row = models.WhatsAppInboundLog(
            phone_number=phone,
            message_sid=message_sid,
            message_type=message_type,
            ai_detected_type=ai_detected_type,
            profile_id_saved=profile_id,
            reading_id_saved=reading_id,
            outcome=outcome,
        )
        db.add(row)
        db.commit()
    except Exception:
        db.rollback()
        logger.error("wa_inbound: Failed to write inbound audit log", exc_info=True)


# ---------------------------------------------------------------------------
# Reply helpers
# ---------------------------------------------------------------------------

def send_reply(to_number: str, body: str) -> None:
    """Send a WhatsApp reply via the existing Twilio singleton. Never raises."""
    try:
        whatsapp_service.send_whatsapp(to_number, body)
    except Exception:
        logger.error("wa_inbound: Failed to send reply to %s", to_number, exc_info=True)


def build_profile_menu(profiles: list) -> str:
    """Format numbered profile selection menu.

    profiles: list of dicts with keys 'id', 'name', 'relationship'
    """
    NUMBER_EMOJIS = ["1️⃣", "2️⃣", "3️⃣", "4️⃣", "5️⃣", "6️⃣", "7️⃣", "8️⃣", "9️⃣"]
    lines = []
    for i, p in enumerate(profiles):
        emoji = NUMBER_EMOJIS[i] if i < len(NUMBER_EMOJIS) else f"{i+1}."
        rel = p.get("relationship") or ""
        rel_suffix = f" ({rel.title()})" if rel and rel != "myself" else ""
        lines.append(f"{emoji} {p['name']}{rel_suffix}")
    return "\n".join(lines)


def format_reading_summary(reading_data: dict) -> str:
    """Return a short human-readable summary of the detected reading."""
    rt = reading_data.get("reading_type")
    if rt == "glucose":
        val = reading_data.get("glucose_value")
        unit = reading_data.get("unit_detected") or "mg/dL"
        return f"🩸 Glucose: *{val} {unit}*"
    elif rt == "blood_pressure":
        sys = reading_data.get("systolic")
        dia = reading_data.get("diastolic")
        pulse = reading_data.get("pulse_rate")
        pulse_str = f", Pulse: {pulse} bpm" if pulse else ""
        return f"💓 Blood Pressure: *{sys}/{dia} mmHg*{pulse_str}"
    elif rt == "weight":
        val = reading_data.get("weight_value")
        return f"⚖️ Weight: *{val} kg*"
    elif rt == "spo2":
        val = reading_data.get("spo2_value")
        return f"🫁 SpO₂: *{val}%*"
    return "📊 Unknown reading"
