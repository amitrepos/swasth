"""
Manual test script for D7 critical-value alert dispatch.

Hits the REAL Twilio WhatsApp + Brevo SMTP (not mocked) so you can verify
end-to-end delivery for a CRITICAL reading. Runs alert_service.dispatch_critical_alert
directly — no HTTP server or JWT token needed.

Usage:
    cd backend && source venv/bin/activate
    python test_critical_alerts.py <family_email> <family_phone>

Example:
    python test_critical_alerts.py you@gmail.com +919876543210

Prerequisites:
- backend/.env has TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_WHATSAPP_NUMBER set
- backend/.env has BREVO_SMTP_LOGIN and BREVO_SMTP_PASSWORD set
- family_phone has opted into the Twilio WhatsApp sandbox (send "join <code>"
  to the sandbox number from that phone first). Sandbox session lasts 24h.
- PostgreSQL is running and DATABASE_URL in .env is correct

Safety:
- Creates a dedicated test patient profile + family viewer user
- Cleans up all rows it created on exit (reading, alert logs, links, users, profile)
- Asks for confirmation before dispatching

What it verifies:
- Email arrives at <family_email>
- WhatsApp arrives at <family_phone>
- critical_alert_logs has the expected rows with status='sent'
- The bilingual EN+HI body is included
"""
import os
import sys
import time
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from database import SessionLocal
import models
from auth import get_password_hash
from alert_service import dispatch_critical_alert
from config import settings


RESET = "\033[0m"
GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
BLUE = "\033[94m"
BOLD = "\033[1m"


def section(title: str):
    print(f"\n{BOLD}{BLUE}=== {title} ==={RESET}")


def ok(msg: str):
    print(f"{GREEN}✓{RESET} {msg}")


def fail(msg: str):
    print(f"{RED}✗{RESET} {msg}")


def warn(msg: str):
    print(f"{YELLOW}⚠{RESET}  {msg}")


def check_prereqs() -> bool:
    section("Prerequisite check")
    issues = []

    if not settings.TWILIO_ACCOUNT_SID or not settings.TWILIO_AUTH_TOKEN:
        issues.append("TWILIO_ACCOUNT_SID / TWILIO_AUTH_TOKEN missing from .env")
    else:
        ok("Twilio account credentials loaded")

    if not settings.TWILIO_WHATSAPP_NUMBER:
        issues.append("TWILIO_WHATSAPP_NUMBER missing from .env")
    else:
        ok(f"Twilio WhatsApp from: {settings.TWILIO_WHATSAPP_NUMBER}")

    if not settings.BREVO_SMTP_LOGIN or not settings.BREVO_SMTP_PASSWORD:
        issues.append("BREVO_SMTP_LOGIN / BREVO_SMTP_PASSWORD missing from .env")
    else:
        ok(f"Brevo SMTP configured ({settings.BREVO_SENDER_EMAIL})")

    if settings.TWILIO_SMS_NUMBER:
        ok(f"SMS enabled: from {settings.TWILIO_SMS_NUMBER}")
    else:
        warn("SMS disabled (TWILIO_SMS_NUMBER not set) — only email + WhatsApp will fire")

    if not settings.CRITICAL_ALERTS_ENABLED:
        issues.append("CRITICAL_ALERTS_ENABLED=False — feature kill switch is OFF")

    if issues:
        print()
        for i in issues:
            fail(i)
        return False
    return True


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)

    family_email = sys.argv[1].strip()
    family_phone = sys.argv[2].strip()
    if not family_phone.startswith("+"):
        fail("family_phone must start with '+' and include country code, e.g. +919876543210")
        sys.exit(2)

    if not check_prereqs():
        print()
        fail("Prerequisites not met. Fix the issues above and retry.")
        sys.exit(3)

    section("Test setup")
    print(f"  Family email:    {family_email}")
    print(f"  Family phone:    {family_phone}")
    print(f"  Dedupe window:   {settings.CRITICAL_ALERT_DEDUPE_MINUTES} minutes")
    print()
    print(f"{YELLOW}This will send a REAL WhatsApp + email to the addresses above.{RESET}")
    print(f"{YELLOW}The family phone must have opted into the Twilio WhatsApp sandbox.{RESET}")
    print()
    confirm = input("Proceed? [y/N]: ").strip().lower()
    if confirm != "y":
        print("Aborted.")
        sys.exit(0)

    db = SessionLocal()
    created_ids = {
        "reading": None,
        "alert_logs": [],
        "access_owner": None,
        "access_viewer": None,
        "profile": None,
        "owner_user": None,
        "viewer_user": None,
    }

    try:
        section("Creating test patient + family viewer")
        ts = int(time.time())

        owner = models.User(
            email=f"d7test_owner_{ts}@swasth.test",
            password_hash=get_password_hash("unused"),
            full_name="D7 Test Patient",
            phone_number="+911111111111",
        )
        db.add(owner); db.flush()
        created_ids["owner_user"] = owner.id
        ok(f"Created patient user id={owner.id}")

        viewer = models.User(
            email=family_email,
            password_hash=get_password_hash("unused"),
            full_name="D7 Test Family",
            phone_number=family_phone,
        )
        db.add(viewer); db.flush()
        created_ids["viewer_user"] = viewer.id
        ok(f"Created family viewer user id={viewer.id} ({family_email})")

        profile = models.Profile(name="D7 Test Ramesh", age=60, gender="Male")
        db.add(profile); db.flush()
        created_ids["profile"] = profile.id
        ok(f"Created profile id={profile.id}")

        access_owner = models.ProfileAccess(
            user_id=owner.id, profile_id=profile.id, access_level="owner",
        )
        db.add(access_owner); db.flush()
        created_ids["access_owner"] = access_owner.id

        access_viewer = models.ProfileAccess(
            user_id=viewer.id, profile_id=profile.id, access_level="viewer",
        )
        db.add(access_viewer); db.flush()
        created_ids["access_viewer"] = access_viewer.id
        ok("Granted viewer access to family")

        reading = models.HealthReading(
            profile_id=profile.id,
            reading_type="glucose",
            glucose_value=420.0,
            glucose_unit="mg/dL",
            value_numeric=420.0,
            unit_display="mg/dL",
            status_flag="CRITICAL",
            reading_timestamp=datetime.now(timezone.utc),
        )
        db.add(reading); db.flush()
        created_ids["reading"] = reading.id
        ok(f"Created CRITICAL reading id={reading.id} (glucose 420 mg/dL)")

        db.commit()

        section("Dispatching critical alert")
        print("(Calling alert_service.dispatch_critical_alert with real Twilio + Brevo)")
        print()

        start = time.time()
        result = dispatch_critical_alert(
            reading=reading,
            profile=profile,
            logger_user_id=owner.id,
            db=db,
        )
        db.commit()
        elapsed = time.time() - start

        section(f"Dispatch result ({elapsed:.1f}s)")
        print(f"  Total recipients:  {result.total_recipients}")
        print(f"  Email sent:        {result.email_sent}")
        print(f"  WhatsApp sent:     {result.whatsapp_sent}")
        print(f"  SMS sent:          {result.sms_sent}")
        print(f"  Failures:          {result.failures}")
        print(f"  Skipped (dedupe):  {result.skipped_dedupe}")

        section("Audit log rows")
        logs = (
            db.query(models.CriticalAlertLog)
            .filter_by(profile_id=profile.id)
            .order_by(models.CriticalAlertLog.created_at)
            .all()
        )
        created_ids["alert_logs"] = [l.id for l in logs]
        if not logs:
            fail("No rows in critical_alert_logs — something is wrong")
        for log in logs:
            color = GREEN if log.status == "sent" else (YELLOW if log.status == "skipped" else RED)
            err_txt = f" — {log.error}" if log.error else ""
            print(f"  {color}[{log.status:7s}]{RESET} {log.channel:10s} {log.severity:20s}{err_txt}")

        section("Verdict")
        if result.failures == 0 and result.email_sent >= 1 and result.whatsapp_sent >= 1:
            ok("END-TO-END DISPATCH SUCCEEDED")
            print()
            print(f"  {BOLD}Now check:{RESET}")
            print(f"  1. Inbox at {family_email} for the 🚨 Health Alert email")
            print(f"  2. WhatsApp on {family_phone} for the bilingual alert")
            print(f"  3. Twilio console (https://console.twilio.com/us1/monitor/logs/sms) for the WhatsApp message log")
            print()
            verdict_ok = True
        else:
            fail("Some channels failed — see audit log above")
            verdict_ok = False

    except Exception as e:
        fail(f"Exception during test: {e}")
        import traceback
        traceback.print_exc()
        verdict_ok = False

    finally:
        section("Cleanup")
        try:
            if created_ids["alert_logs"]:
                db.query(models.CriticalAlertLog).filter(
                    models.CriticalAlertLog.id.in_(created_ids["alert_logs"])
                ).delete(synchronize_session=False)
                ok(f"Deleted {len(created_ids['alert_logs'])} alert log rows")

            if created_ids["reading"]:
                db.query(models.HealthReading).filter_by(id=created_ids["reading"]).delete()
                ok("Deleted test reading")

            for key in ("access_viewer", "access_owner"):
                aid = created_ids[key]
                if aid:
                    db.query(models.ProfileAccess).filter_by(id=aid).delete()
            ok("Deleted profile access rows")

            if created_ids["profile"]:
                db.query(models.Profile).filter_by(id=created_ids["profile"]).delete()
                ok("Deleted test profile")

            for key in ("viewer_user", "owner_user"):
                uid = created_ids[key]
                if uid:
                    db.query(models.User).filter_by(id=uid).delete()
            ok("Deleted test users")

            db.commit()
        except Exception as cleanup_error:
            fail(f"Cleanup partially failed: {cleanup_error}")
            db.rollback()
            print(f"{YELLOW}Manual cleanup may be needed for ids: {created_ids}{RESET}")
        finally:
            db.close()

    sys.exit(0 if verdict_ok else 1)


if __name__ == "__main__":
    main()
