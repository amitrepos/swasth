from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
from report_service import send_daily_reports
from models import ReportTriggerType
import logging
from datetime import datetime

# Setup basic logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("swasth-scheduler")

scheduler = BackgroundScheduler()

def daily_reports_job():
    """Wrapper to log the trigger event and call the service."""
    logger.info(f"[SCHEDULER] Daily report job fired at {datetime.now()}")
    send_daily_reports(trigger_type=ReportTriggerType.SCHEDULED)

def start_scheduler():
    """
    Initialize and start the background scheduler.
    Currently schedules:
    - Daily Health Reports: 09:00 AM IST
    """
    if not scheduler.running:
        # Task: Daily Reports
        # For an Indian healthcare app, 9:00 AM is a standard summary time.
        scheduler.add_job(
            daily_reports_job,
            trigger=CronTrigger(hour=9, minute=0),
            id="daily_whatsapp_reports",
            name="Generate and send daily health reports to all users",
            replace_existing=True
        )
        
        # We can add a shorter interval test job here if needed for debugging
        # scheduler.add_job(send_daily_reports, 'interval', minutes=60)
        
        scheduler.start()
        logger.info("✅ Background scheduler initialized.")
        logger.info("📅 Daily reports scheduled for 09:00 AM local time.")

def stop_scheduler():
    """Shutdown the scheduler gracefully."""
    if scheduler.running:
        scheduler.shutdown()
        logger.info("🛑 Background scheduler stopped.")
