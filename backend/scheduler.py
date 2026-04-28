from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
from apscheduler.triggers.interval import IntervalTrigger
from report_service import send_weekly_reports
from models import ReportTriggerType
import logging
from datetime import datetime

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("swasth-scheduler")

scheduler = BackgroundScheduler()


def weekly_reports_job():
    logger.info(f"[SCHEDULER] Weekly report job fired at {datetime.now()}")
    send_weekly_reports(trigger_type=ReportTriggerType.SCHEDULED)


# ---------------------------------------------------------------------------
# Ops monitoring jobs — P0 (1 min), P1 (5 min), P2 digest (weekly Sunday)
# ---------------------------------------------------------------------------

def _ops_p0_check():
    """Take a health snapshot and fire any P0 alerts."""
    import ops_metrics
    from database import SessionLocal
    from ops_health import take_health_snapshot
    from ops_alerting import evaluate_p0, fire_alert
    from email_service import email_service

    db = SessionLocal()
    try:
        snap = take_health_snapshot(db)
        for candidate in evaluate_p0(snap):
            fire_alert(candidate, db, email_service)
        ops_metrics.record_scheduler_run("ops_p0_check", success=True)
    except Exception:
        logger.error("[SCHEDULER] ops_p0_check failed", exc_info=True)
        ops_metrics.record_scheduler_run("ops_p0_check", success=False)
        db.rollback()
    finally:
        db.close()


def _ops_p1_check():
    """Fire P1 alerts if enabled."""
    import ops_metrics
    from config import settings
    if not settings.OPS_P1_ALERTS_ENABLED:
        return
    from database import SessionLocal
    from ops_health import take_health_snapshot
    from ops_alerting import evaluate_p1, fire_alert
    from email_service import email_service

    db = SessionLocal()
    try:
        snap = take_health_snapshot(db)
        for candidate in evaluate_p1(snap):
            fire_alert(candidate, db, email_service)
        ops_metrics.record_scheduler_run("ops_p1_check", success=True)
    except Exception:
        logger.error("[SCHEDULER] ops_p1_check failed", exc_info=True)
        ops_metrics.record_scheduler_run("ops_p1_check", success=False)
        db.rollback()
    finally:
        db.close()


def _ops_p2_digest():
    """Send the weekly ops digest (Sundays 08:00 IST)."""
    import ops_metrics
    from database import SessionLocal
    from ops_health import take_health_snapshot
    from ops_alerting import evaluate_p2, fire_p2_digest
    from email_service import email_service

    db = SessionLocal()
    try:
        snap = take_health_snapshot(db)
        candidates = evaluate_p2(snap, db)
        fire_p2_digest(candidates, db, email_service)
        ops_metrics.record_scheduler_run("ops_p2_digest", success=True)
    except Exception:
        logger.error("[SCHEDULER] ops_p2_digest failed", exc_info=True)
        ops_metrics.record_scheduler_run("ops_p2_digest", success=False)
        db.rollback()
    finally:
        db.close()


def start_scheduler():
    if not scheduler.running:
        # Weekly health reports — Sunday 09:00 IST
        scheduler.add_job(
            weekly_reports_job,
            trigger=CronTrigger(day_of_week='sun', hour=9, minute=0),
            id="weekly_whatsapp_reports",
            name="Generate and send weekly health reports to all users",
            replace_existing=True,
        )

        # P0 ops check — every 1 minute
        scheduler.add_job(
            _ops_p0_check,
            trigger=IntervalTrigger(minutes=1),
            id="ops_p0_check",
            name="Ops P0 health snapshot + immediate alerts",
            replace_existing=True,
        )

        # P1 ops check — every 5 minutes (sends only if OPS_P1_ALERTS_ENABLED=True)
        scheduler.add_job(
            _ops_p1_check,
            trigger=IntervalTrigger(minutes=5),
            id="ops_p1_check",
            name="Ops P1 warning alerts (disabled at launch)",
            replace_existing=True,
        )

        # P2 weekly digest — Sundays 08:00 IST (before weekly reports at 09:00)
        scheduler.add_job(
            _ops_p2_digest,
            trigger=CronTrigger(day_of_week='sun', hour=2, minute=30),  # 02:30 UTC = 08:00 IST
            id="ops_p2_digest",
            name="Ops P2 weekly digest email",
            replace_existing=True,
        )

        scheduler.start()
        logger.info("Background scheduler started — weekly reports + ops P0/P1/P2 checks registered.")


def stop_scheduler():
    if scheduler.running:
        scheduler.shutdown()
        logger.info("Background scheduler stopped.")
