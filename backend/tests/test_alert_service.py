"""Tests for backend/alert_service.py — critical health alert dispatch (D7)."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from datetime import datetime, timedelta, timezone
from unittest.mock import patch

import pytest

import models
from auth import get_password_hash


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_counter = {"n": 0}

def _uniq(prefix: str) -> str:
    _counter["n"] += 1
    return f"{prefix}{_counter['n']}"


def _make_user(db, email: str | None = None, phone: str | None = "+919876500001") -> models.User:
    u = models.User(
        email=email or f"{_uniq('u')}@t.com",
        password_hash=get_password_hash("Test@1234"),
        full_name=f"User {_uniq('n')}",
        phone_number=phone,
    )
    db.add(u); db.flush()
    return u


def _make_profile(db, name: str = "Ramesh") -> models.Profile:
    p = models.Profile(name=name, age=60, gender="Male", phone_number="9876543210")
    db.add(p); db.flush()
    return p


def _make_reading(
    db,
    profile_id: int,
    *,
    reading_type: str = "glucose",
    glucose: float | None = 400.0,
    systolic: float | None = None,
    diastolic: float | None = None,
    spo2: float | None = None,
    status: str = "CRITICAL",
) -> models.HealthReading:
    r = models.HealthReading(
        profile_id=profile_id,
        reading_type=reading_type,
        glucose_value=glucose,
        glucose_unit="mg/dL" if glucose else None,
        systolic=systolic,
        diastolic=diastolic,
        spo2_value=spo2,
        value_numeric=(glucose or systolic or spo2 or 0),
        unit_display="mg/dL" if glucose else ("mmHg" if systolic else "%"),
        status_flag=status,
        reading_timestamp=datetime.now(timezone.utc),
    )
    db.add(r); db.flush()
    return r


def _grant_access(db, *, user_id: int, profile_id: int, level: str = "viewer"):
    a = models.ProfileAccess(user_id=user_id, profile_id=profile_id, access_level=level)
    db.add(a); db.flush()
    return a


def _setup_single_family(db):
    """Owner + one family viewer. Returns (owner, viewer, profile)."""
    owner = _make_user(db)
    p = _make_profile(db)
    _grant_access(db, user_id=owner.id, profile_id=p.id, level="owner")
    viewer = _make_user(db)
    _grant_access(db, user_id=viewer.id, profile_id=p.id, level="viewer")
    return owner, viewer, p


# ---------------------------------------------------------------------------
# _build_alert_messages — pure function, no DB
# ---------------------------------------------------------------------------


class TestBuildAlertMessages:

    def test_glucose_message(self, db):
        from alert_service import _build_alert_messages
        p = _make_profile(db, name="Ramesh")
        r = _make_reading(db, p.id, glucose=400.0, status="CRITICAL")
        en, hi = _build_alert_messages(r, p.name)
        assert "Ramesh" in en and "400" in en and "CRITICAL" in en
        assert "Ramesh" in hi and "400" in hi and "ग्लूकोज" in hi

    def test_bp_message(self, db):
        from alert_service import _build_alert_messages
        p = _make_profile(db, name="Sunita")
        r = _make_reading(db, p.id, reading_type="blood_pressure",
                          glucose=None, systolic=190.0, diastolic=115.0,
                          status="HIGH - STAGE 2")
        en, hi = _build_alert_messages(r, p.name)
        assert "190" in en and "115" in en
        assert "रक्तचाप" in hi

    def test_spo2_message(self, db):
        from alert_service import _build_alert_messages
        p = _make_profile(db, name="Arjun")
        r = _make_reading(db, p.id, reading_type="spo2",
                          glucose=None, spo2=82.0, status="CRITICAL")
        en, hi = _build_alert_messages(r, p.name)
        assert "82" in en and "SpO2" in en

    def test_unknown_reading_type_fallback(self, db):
        from alert_service import _build_alert_messages
        p = _make_profile(db, name="Test")
        r = _make_reading(db, p.id, reading_type="weight",
                          glucose=None, status="CRITICAL")
        en, hi = _build_alert_messages(r, p.name)
        assert "Test" in en and "CRITICAL" in en
        assert "Test" in hi


# ---------------------------------------------------------------------------
# dispatch_critical_alert — full fanout
# ---------------------------------------------------------------------------


class TestDispatchFanout:

    def test_email_and_whatsapp_both_sent(self, db):
        from alert_service import dispatch_critical_alert
        owner, viewer, p = _setup_single_family(db)
        r = _make_reading(db, p.id)

        with patch("email_service.email_service.send_critical_alert_email", return_value=True) as mock_email, \
             patch("twilio_service.whatsapp_service.send_critical_alert_whatsapp", return_value=(True, "SMxxx", None)) as mock_wa, \
             patch("alert_service.sms_service") as mock_sms:
            mock_sms.is_enabled = False
            result = dispatch_critical_alert(reading=r, profile=p, logger_user_id=owner.id, db=db)

        assert result.total_recipients == 1
        assert result.email_sent == 1
        assert result.whatsapp_sent == 1
        assert result.failures == 0
        assert mock_email.called
        assert mock_wa.called

        logs = db.query(models.CriticalAlertLog).filter_by(profile_id=p.id).all()
        assert len(logs) == 2
        assert {l.channel for l in logs} == {"email", "whatsapp"}
        assert all(l.status == "sent" for l in logs)

    def test_email_fails_whatsapp_succeeds(self, db):
        from alert_service import dispatch_critical_alert
        owner, viewer, p = _setup_single_family(db)
        r = _make_reading(db, p.id)

        with patch("email_service.email_service.send_critical_alert_email", return_value=False), \
             patch("twilio_service.whatsapp_service.send_critical_alert_whatsapp", return_value=(True, "SMxxx", None)), \
             patch("alert_service.sms_service") as mock_sms:
            mock_sms.is_enabled = False
            result = dispatch_critical_alert(reading=r, profile=p, logger_user_id=owner.id, db=db)

        assert result.email_sent == 0
        assert result.whatsapp_sent == 1
        assert result.failures == 1

        email_log = db.query(models.CriticalAlertLog).filter_by(profile_id=p.id, channel="email").first()
        assert email_log.status == "failed"
        assert "returned False" in email_log.error

    def test_whatsapp_raises_exception(self, db):
        from alert_service import dispatch_critical_alert
        owner, viewer, p = _setup_single_family(db)
        r = _make_reading(db, p.id)

        with patch("email_service.email_service.send_critical_alert_email", return_value=True), \
             patch("twilio_service.whatsapp_service.send_critical_alert_whatsapp",
                   side_effect=RuntimeError("Twilio down")), \
             patch("alert_service.sms_service") as mock_sms:
            mock_sms.is_enabled = False
            result = dispatch_critical_alert(reading=r, profile=p, logger_user_id=owner.id, db=db)

        assert result.email_sent == 1
        assert result.whatsapp_sent == 0
        assert result.failures == 1

        wa_log = db.query(models.CriticalAlertLog).filter_by(profile_id=p.id, channel="whatsapp").first()
        assert wa_log.status == "failed"
        assert "Twilio down" in wa_log.error

    def test_both_channels_fail(self, db):
        from alert_service import dispatch_critical_alert
        owner, viewer, p = _setup_single_family(db)
        r = _make_reading(db, p.id)

        with patch("email_service.email_service.send_critical_alert_email", return_value=False), \
             patch("twilio_service.whatsapp_service.send_critical_alert_whatsapp", return_value=(False, None, "Twilio error")), \
             patch("alert_service.sms_service") as mock_sms:
            mock_sms.is_enabled = False
            result = dispatch_critical_alert(reading=r, profile=p, logger_user_id=owner.id, db=db)

        assert result.email_sent == 0
        assert result.whatsapp_sent == 0
        assert result.failures == 2
        logs = db.query(models.CriticalAlertLog).filter_by(profile_id=p.id, status="failed").all()
        assert len(logs) == 2

    def test_no_family_members_noop(self, db):
        from alert_service import dispatch_critical_alert
        owner = _make_user(db)
        p = _make_profile(db)
        _grant_access(db, user_id=owner.id, profile_id=p.id, level="owner")
        r = _make_reading(db, p.id)

        result = dispatch_critical_alert(reading=r, profile=p, logger_user_id=owner.id, db=db)

        assert result.total_recipients == 0
        assert result.email_sent == 0
        logs = db.query(models.CriticalAlertLog).filter_by(profile_id=p.id).all()
        assert len(logs) == 0

    def test_family_without_phone_only_emails(self, db):
        from alert_service import dispatch_critical_alert
        owner = _make_user(db)
        p = _make_profile(db)
        _grant_access(db, user_id=owner.id, profile_id=p.id, level="owner")
        viewer = _make_user(db)
        viewer.phone_number = ""  # simulate no-phone user (NOT NULL constraint disallows real None)
        db.flush()
        _grant_access(db, user_id=viewer.id, profile_id=p.id)
        r = _make_reading(db, p.id)

        with patch("email_service.email_service.send_critical_alert_email", return_value=True) as mock_e, \
             patch("twilio_service.whatsapp_service.send_critical_alert_whatsapp", return_value=(True, "SMxxx", None)) as mock_wa:
            result = dispatch_critical_alert(reading=r, profile=p, logger_user_id=owner.id, db=db)

        assert result.email_sent == 1
        assert result.whatsapp_sent == 0  # phone_number None → skipped
        assert mock_wa.called is False

    def test_family_without_email_only_whatsapp(self, db):
        from alert_service import dispatch_critical_alert
        owner = _make_user(db)
        p = _make_profile(db)
        _grant_access(db, user_id=owner.id, profile_id=p.id, level="owner")
        viewer = _make_user(db)
        viewer.email = ""
        db.flush()
        _grant_access(db, user_id=viewer.id, profile_id=p.id)
        r = _make_reading(db, p.id)

        with patch("email_service.email_service.send_critical_alert_email", return_value=True) as mock_e, \
             patch("twilio_service.whatsapp_service.send_critical_alert_whatsapp", return_value=(True, "SMxxx", None)) as mock_wa:
            result = dispatch_critical_alert(reading=r, profile=p, logger_user_id=owner.id, db=db)

        assert result.email_sent == 0
        assert result.whatsapp_sent == 1
        assert mock_e.called is False

    def test_logger_excluded_from_recipients(self, db):
        """The user who logged the reading should NOT receive the alert themselves."""
        from alert_service import dispatch_critical_alert
        owner = _make_user(db)
        p = _make_profile(db)
        _grant_access(db, user_id=owner.id, profile_id=p.id, level="owner")
        r = _make_reading(db, p.id)

        with patch("email_service.email_service.send_critical_alert_email", return_value=True) as mock_e:
            result = dispatch_critical_alert(reading=r, profile=p, logger_user_id=owner.id, db=db)

        assert result.total_recipients == 0
        assert mock_e.called is False


# ---------------------------------------------------------------------------
# Dedupe window
# ---------------------------------------------------------------------------


class TestDedupeWindow:

    def test_recent_alert_skips_dispatch(self, db):
        from alert_service import dispatch_critical_alert
        owner, viewer, p = _setup_single_family(db)

        db.add(models.CriticalAlertLog(
            profile_id=p.id, reading_id=None, recipient_user_id=viewer.id,
            channel="email", status="sent", severity="CRITICAL",
            created_at=datetime.now(timezone.utc) - timedelta(minutes=5),
        ))
        db.flush()

        r = _make_reading(db, p.id)
        with patch("email_service.email_service.send_critical_alert_email", return_value=True) as mock_e:
            result = dispatch_critical_alert(reading=r, profile=p, logger_user_id=owner.id, db=db)

        assert result.skipped_dedupe is True
        assert result.email_sent == 0
        assert mock_e.called is False

        skip_log = db.query(models.CriticalAlertLog).filter_by(
            profile_id=p.id, channel="dedupe"
        ).first()
        assert skip_log is not None
        assert skip_log.status == "skipped"

    def test_old_alert_does_not_block(self, db):
        from alert_service import dispatch_critical_alert
        owner, viewer, p = _setup_single_family(db)

        db.add(models.CriticalAlertLog(
            profile_id=p.id, reading_id=None, recipient_user_id=viewer.id,
            channel="email", status="sent", severity="CRITICAL",
            created_at=datetime.now(timezone.utc) - timedelta(hours=2),
        ))
        db.flush()

        r = _make_reading(db, p.id)
        with patch("email_service.email_service.send_critical_alert_email", return_value=True), \
             patch("twilio_service.whatsapp_service.send_critical_alert_whatsapp", return_value=(True, "SMxxx", None)):
            result = dispatch_critical_alert(reading=r, profile=p, logger_user_id=owner.id, db=db)

        assert result.skipped_dedupe is False
        assert result.email_sent == 1

    def test_failed_attempts_do_not_block_retry(self, db):
        """A previous failed dispatch should NOT suppress a retry."""
        from alert_service import dispatch_critical_alert
        owner, viewer, p = _setup_single_family(db)

        db.add(models.CriticalAlertLog(
            profile_id=p.id, reading_id=None, recipient_user_id=viewer.id,
            channel="email", status="failed", severity="CRITICAL",
            created_at=datetime.now(timezone.utc) - timedelta(minutes=5),
        ))
        db.flush()

        r = _make_reading(db, p.id)
        with patch("email_service.email_service.send_critical_alert_email", return_value=True), \
             patch("twilio_service.whatsapp_service.send_critical_alert_whatsapp", return_value=(True, "SMxxx", None)):
            result = dispatch_critical_alert(reading=r, profile=p, logger_user_id=owner.id, db=db)

        assert result.skipped_dedupe is False
        assert result.email_sent == 1


# ---------------------------------------------------------------------------
# Feature-flag kill switch
# ---------------------------------------------------------------------------


class TestKillSwitch:

    def test_alerts_disabled_returns_empty(self, db):
        from alert_service import dispatch_critical_alert
        owner, viewer, p = _setup_single_family(db)
        r = _make_reading(db, p.id)

        with patch("alert_service.settings") as mock_settings:
            mock_settings.CRITICAL_ALERTS_ENABLED = False
            mock_settings.CRITICAL_ALERT_DEDUPE_MINUTES = 30
            with patch("email_service.email_service.send_critical_alert_email", return_value=True) as mock_e:
                result = dispatch_critical_alert(reading=r, profile=p, logger_user_id=owner.id, db=db)

        assert result.total_recipients == 0
        assert mock_e.called is False
        logs = db.query(models.CriticalAlertLog).filter_by(profile_id=p.id).all()
        assert len(logs) == 0


# ---------------------------------------------------------------------------
# SMS provisioning (currently disabled — validates the stub)
# ---------------------------------------------------------------------------


class TestSmsStub:

    def test_sms_not_dispatched_when_disabled(self, db):
        """SMS disabled via missing TWILIO_SMS_NUMBER → no SMS attempts, no log rows."""
        from alert_service import dispatch_critical_alert
        owner, viewer, p = _setup_single_family(db)
        r = _make_reading(db, p.id)

        with patch("email_service.email_service.send_critical_alert_email", return_value=True), \
             patch("twilio_service.whatsapp_service.send_critical_alert_whatsapp", return_value=(True, "SMxxx", None)), \
             patch("alert_service.sms_service") as mock_sms:
            mock_sms.is_enabled = False
            result = dispatch_critical_alert(reading=r, profile=p, logger_user_id=owner.id, db=db)

        assert result.sms_sent == 0
        mock_sms.send_critical_alert_sms.assert_not_called()
        sms_logs = db.query(models.CriticalAlertLog).filter_by(profile_id=p.id, channel="sms").all()
        assert len(sms_logs) == 0

    def test_sms_dispatched_when_enabled(self, db):
        """When TWILIO_SMS_NUMBER is set, SMS joins the fanout."""
        from alert_service import dispatch_critical_alert
        owner, viewer, p = _setup_single_family(db)
        r = _make_reading(db, p.id)

        with patch("email_service.email_service.send_critical_alert_email", return_value=True), \
             patch("twilio_service.whatsapp_service.send_critical_alert_whatsapp", return_value=(True, "SMxxx", None)), \
             patch("alert_service.sms_service") as mock_sms:
            mock_sms.is_enabled = True
            mock_sms.send_critical_alert_sms.return_value = True
            result = dispatch_critical_alert(reading=r, profile=p, logger_user_id=owner.id, db=db)

        assert result.sms_sent == 1
        mock_sms.send_critical_alert_sms.assert_called_once()
        sms_log = db.query(models.CriticalAlertLog).filter_by(profile_id=p.id, channel="sms").first()
        assert sms_log is not None
        assert sms_log.status == "sent"
