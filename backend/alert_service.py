"""Critical health alert dispatch service (Feature D7).

Fans out CRITICAL / HIGH-STAGE-2 alerts to every family member with
ProfileAccess to the patient's profile. Each recipient is notified via
every enabled channel (email, WhatsApp, SMS). Every attempt is logged
to `critical_alert_logs` for audit trail.

The dispatcher applies a dedupe window (see config.CRITICAL_ALERT_DEDUPE_MINUTES)
to prevent spamming family when a patient has repeat critical readings
during a single clinical event.

See `docs/LEGAL_COMPLIANCE_DOCTOR_PORTAL.md` section 11 for the legal
analysis of this feature (consent model, cross-border transfer, data
minimization, rate limiting tradeoffs).
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Optional

from sqlalchemy.orm import Session

import models
from config import settings
from email_service import email_service
from sms_service import sms_service
from twilio_service import whatsapp_service


@dataclass
class DispatchResult:
    """Aggregated outcome of a single dispatch_critical_alert() call."""
    total_recipients: int
    email_sent: int
    whatsapp_sent: int
    sms_sent: int
    failures: int
    skipped_dedupe: bool


def _build_alert_messages(reading: models.HealthReading, patient_name: str) -> tuple[str, str]:
    """Return (english, hindi) alert body strings for the given reading.

    Kept deliberately short and actionable — recipients may be reading
    these on a notification preview without opening the full message.
    """
    severity = reading.status_flag or "CRITICAL"

    if reading.reading_type == "glucose" and reading.glucose_value is not None:
        value = f"{reading.glucose_value:.0f} mg/dL"
        en = f"{patient_name}'s glucose is {value} ({severity}). Please check on them immediately."
        hi = f"{patient_name} का ग्लूकोज {value} है ({severity})। कृपया तुरंत उनसे संपर्क करें।"
    elif reading.reading_type == "blood_pressure" and reading.systolic and reading.diastolic:
        value = f"{reading.systolic:.0f}/{reading.diastolic:.0f} mmHg"
        en = f"{patient_name}'s BP is {value} ({severity}). Please check on them immediately."
        hi = f"{patient_name} का रक्तचाप {value} है ({severity})। कृपया तुरंत उनसे संपर्क करें।"
    elif reading.reading_type == "spo2" and reading.spo2_value is not None:
        value = f"{reading.spo2_value:.0f}%"
        en = f"{patient_name}'s SpO2 is {value} ({severity}). Please check on them immediately."
        hi = f"{patient_name} का SpO2 {value} है ({severity})। कृपया तुरंत उनसे संपर्क करें।"
    else:
        en = f"{patient_name} has a {severity} health reading. Please check on them."
        hi = f"{patient_name} की एक {severity} स्वास्थ्य रीडिंग है। कृपया उनसे संपर्क करें।"

    return en, hi


def _was_recently_alerted(profile_id: int, db: Session) -> bool:
    """Return True if a successful alert was dispatched for this profile
    within the configured dedupe window.

    Only counts successful ("sent") dispatches — failed attempts don't
    suppress retries.
    """
    if settings.CRITICAL_ALERT_DEDUPE_MINUTES <= 0:
        return False

    cutoff = datetime.now(timezone.utc) - timedelta(
        minutes=settings.CRITICAL_ALERT_DEDUPE_MINUTES
    )
    recent = (
        db.query(models.CriticalAlertLog)
        .filter(
            models.CriticalAlertLog.profile_id == profile_id,
            models.CriticalAlertLog.status == "sent",
            models.CriticalAlertLog.created_at >= cutoff,
        )
        .first()
    )
    return recent is not None


def _log_attempt(
    db: Session,
    *,
    profile_id: int,
    reading_id: Optional[int],
    recipient_user_id: Optional[int],
    channel: str,
    status: str,
    severity: str,
    error: Optional[str] = None,
) -> None:
    log = models.CriticalAlertLog(
        profile_id=profile_id,
        reading_id=reading_id,
        recipient_user_id=recipient_user_id,
        channel=channel,
        status=status,
        severity=severity,
        error=error,
    )
    db.add(log)


def _dispatch_one_channel(
    db: Session,
    *,
    profile_id: int,
    reading_id: Optional[int],
    recipient_user_id: int,
    channel: str,
    severity: str,
    sender,  # callable taking no args, returns bool
) -> tuple[bool, bool]:
    """Invoke one channel's sender, log the outcome.

    Returns (sent_ok, counted_failure) where sent_ok=True means the sender
    returned True (success), and counted_failure=True means the attempt
    should contribute to result.failures.
    """
    try:
        sent = sender()
        if sent:
            _log_attempt(
                db,
                profile_id=profile_id,
                reading_id=reading_id,
                recipient_user_id=recipient_user_id,
                channel=channel,
                status="sent",
                severity=severity,
            )
            return True, False
        else:
            _log_attempt(
                db,
                profile_id=profile_id,
                reading_id=reading_id,
                recipient_user_id=recipient_user_id,
                channel=channel,
                status="failed",
                severity=severity,
                error=f"{channel} service returned False",
            )
            return False, True
    except Exception as e:
        _log_attempt(
            db,
            profile_id=profile_id,
            reading_id=reading_id,
            recipient_user_id=recipient_user_id,
            channel=channel,
            status="failed",
            severity=severity,
            error=str(e),
        )
        return False, True


def dispatch_critical_alert(
    reading: models.HealthReading,
    profile: models.Profile,
    logger_user_id: int,
    db: Session,
) -> DispatchResult:
    """Fan out a critical alert to every family member of the profile.

    Arguments:
        reading: the CRITICAL / HIGH-STAGE-2 HealthReading that triggered this
        profile: the patient's Profile (for name in the alert body)
        logger_user_id: the user who recorded the reading — excluded from recipients
        db: SQLAlchemy session. Caller is responsible for committing.
    """
    result = DispatchResult(0, 0, 0, 0, 0, False)

    if not settings.CRITICAL_ALERTS_ENABLED:
        return result

    # Dedupe — log the skip for audit trail
    if _was_recently_alerted(profile.id, db):
        _log_attempt(
            db,
            profile_id=profile.id,
            reading_id=reading.id,
            recipient_user_id=None,
            channel="dedupe",
            status="skipped",
            severity=reading.status_flag or "CRITICAL",
            error=f"Within {settings.CRITICAL_ALERT_DEDUPE_MINUTES}-minute dedupe window",
        )
        db.flush()
        result.skipped_dedupe = True
        return result

    family_accesses = (
        db.query(models.ProfileAccess)
        .filter(
            models.ProfileAccess.profile_id == profile.id,
            models.ProfileAccess.user_id != logger_user_id,
        )
        .all()
    )

    if not family_accesses:
        return result

    patient_name = profile.name or "Someone"
    alert_en, alert_hi = _build_alert_messages(reading, patient_name)
    severity = reading.status_flag or "CRITICAL"

    for access in family_accesses:
        family_user = (
            db.query(models.User)
            .filter(models.User.id == access.user_id)
            .first()
        )
        if not family_user:
            continue

        result.total_recipients += 1
        recipient_name = family_user.full_name or "Family member"

        if family_user.email:
            ok, failed = _dispatch_one_channel(
                db,
                profile_id=profile.id,
                reading_id=reading.id,
                recipient_user_id=family_user.id,
                channel="email",
                severity=severity,
                sender=lambda: email_service.send_critical_alert_email(
                    recipient_email=family_user.email,
                    recipient_name=recipient_name,
                    patient_name=patient_name,
                    alert_text_en=alert_en,
                    alert_text_hi=alert_hi,
                ),
            )
            if ok:
                result.email_sent += 1
            if failed:
                result.failures += 1

        if family_user.phone_number:
            ok, failed = _dispatch_one_channel(
                db,
                profile_id=profile.id,
                reading_id=reading.id,
                recipient_user_id=family_user.id,
                channel="whatsapp",
                severity=severity,
                sender=lambda: whatsapp_service.send_critical_alert_whatsapp(
                    to_number=family_user.phone_number,
                    patient_name=patient_name,
                    alert_text_en=alert_en,
                    alert_text_hi=alert_hi,
                ),
            )
            if ok:
                result.whatsapp_sent += 1
            if failed:
                result.failures += 1

        # SMS is provisioned — only dispatches when TWILIO_SMS_NUMBER is set
        if family_user.phone_number and sms_service.is_enabled:
            ok, failed = _dispatch_one_channel(
                db,
                profile_id=profile.id,
                reading_id=reading.id,
                recipient_user_id=family_user.id,
                channel="sms",
                severity=severity,
                sender=lambda: sms_service.send_critical_alert_sms(
                    to_number=family_user.phone_number,
                    patient_name=patient_name,
                    alert_text_en=alert_en,
                    alert_text_hi=alert_hi,
                ),
            )
            if ok:
                result.sms_sent += 1
            if failed:
                result.failures += 1

    # Flush so CriticalAlertLog rows are visible to same-session queries
    # (tests + audit reads right after dispatch). Caller commits.
    db.flush()
    return result
