from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
from report_service import send_weekly_reports
from models import ReportTriggerType
import logging
from datetime import datetime

# Setup basic logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("swasth-scheduler")

scheduler = BackgroundScheduler()

def weekly_reports_job():
    """Wrapper to log the trigger event and call the service."""
    logger.info(f"[SCHEDULER] Weekly report job fired at {datetime.now()}")
    send_weekly_reports(trigger_type=ReportTriggerType.SCHEDULED)

def start_scheduler():
    """
    Initialize and start the background scheduler.
    Now schedules:
    - Weekly Health Reports: Sunday 09:00 AM IST
    """
    if not scheduler.running:
        # Task: Weekly Reports
        # Sent every Sunday morning as a comprehensive family summary.
        scheduler.add_job(
            weekly_reports_job,
            #trigger=CronTrigger(minute='*'),
            trigger=CronTrigger(day_of_week='sun', hour=9, minute=0),
            id="weekly_whatsapp_reports",
            name="Generate and send weekly health reports to all users",
            replace_existing=True
        )
        
        scheduler.start()
        logger.info("✅ Background scheduler initialized.")
        logger.info("📅 Weekly reports scheduled for Sundays at 09:00 AM local time.")

def stop_scheduler():
    """Shutdown the scheduler gracefully."""
    if scheduler.running:
        scheduler.shutdown()
        logger.info("🛑 Background scheduler stopped.")
