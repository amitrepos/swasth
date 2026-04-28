"""
ops_health.py — Health check functions and DB aggregate queries for ops monitoring.

All functions return aggregate counts/rates/booleans only. Zero PHI.
Called by ops_alerting.py (scheduler jobs) and routes_admin.py (API endpoint).
"""

import os
import shutil
import logging
from datetime import datetime, timezone, timedelta
from typing import Optional

from sqlalchemy import text, func
from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError

import ops_metrics
from models import (
    User, Profile, HealthReading, CriticalAlertLog, AiInsightLog,
    ChatMessage, DoctorProfile, DoctorAccessLog, DoctorPatientLink,
    WhatsAppMessageLog, WhatsAppSession, ReportGenerationLog,
    SystemHealthSnapshot,
)

logger = logging.getLogger("swasth.ops_health")


# ---------------------------------------------------------------------------
# System resource checks (no external deps — /proc + shutil)
# ---------------------------------------------------------------------------

def check_memory() -> dict:
    """Returns memory stats from /proc/meminfo (Linux only). Falls back gracefully."""
    try:
        meminfo = {}
        with open("/proc/meminfo") as f:
            for line in f:
                parts = line.split()
                if len(parts) >= 2:
                    meminfo[parts[0].rstrip(":")] = int(parts[1])
        total_kb = meminfo.get("MemTotal", 0)
        available_kb = meminfo.get("MemAvailable", 0)
        swap_total_kb = meminfo.get("SwapTotal", 0)
        swap_free_kb = meminfo.get("SwapFree", 0)
        used_kb = total_kb - available_kb
        memory_pct = used_kb / total_kb if total_kb > 0 else 0.0
        swap_active = (swap_total_kb - swap_free_kb) > 0
        return {
            "memory_pct": round(memory_pct, 3),
            "memory_rss_mb": round(used_kb / 1024, 1),
            "swap_active": swap_active,
        }
    except Exception:
        return {"memory_pct": 0.0, "memory_rss_mb": 0.0, "swap_active": False}


def check_disk() -> dict:
    """Returns disk usage for the root filesystem."""
    try:
        usage = shutil.disk_usage("/")
        disk_pct = usage.used / usage.total if usage.total > 0 else 0.0
        return {"disk_pct": round(disk_pct, 3)}
    except Exception:
        return {"disk_pct": 0.0}


def check_file_descriptors() -> int:
    """Returns open file descriptor count for this process (Linux only)."""
    try:
        pid = os.getpid()
        fd_dir = f"/proc/{pid}/fd"
        return len(os.listdir(fd_dir))
    except Exception:
        return 0


def check_cpu_burst_credits() -> bool:
    """
    Heuristic for t3.micro CPU burst credit depletion.
    Reads /proc/stat to check steal time — high steal % on t3 often signals
    credit exhaustion. Returns True if credits appear low.
    Falls back to False (unknown) if /proc/stat is unavailable.
    """
    try:
        with open("/proc/stat") as f:
            cpu_line = f.readline()
        parts = cpu_line.split()
        if len(parts) < 9:
            return False
        # fields: user nice system idle iowait irq softirq steal guest
        steal = int(parts[8])
        total = sum(int(p) for p in parts[1:])
        steal_pct = steal / total if total > 0 else 0.0
        return steal_pct > 0.10  # >10% steal = likely throttled
    except Exception:
        return False


# ---------------------------------------------------------------------------
# DB health checks
# ---------------------------------------------------------------------------

def check_db_health(db: Session) -> dict:
    """Ping DB and return pool stats."""
    try:
        db.execute(text("SELECT 1"))
        db_healthy = True
    except SQLAlchemyError:
        logger.error("db_health_check failed", exc_info=True)
        db_healthy = False

    pool_used, pool_size = 0, 0
    try:
        pool = db.bind.pool
        pool_used = pool.checkedout()
        pool_size = pool.size()
    except Exception:
        pass

    return {
        "db_healthy": db_healthy,
        "db_pool_used": pool_used,
        "db_pool_size": pool_size,
    }


def check_db_slow_queries(db: Session) -> int:
    """
    Count slow queries in the last hour using pg_stat_statements if available.
    Returns 0 if the extension is not installed.
    """
    try:
        result = db.execute(text("""
            SELECT COUNT(*) FROM pg_stat_statements
            WHERE mean_exec_time > 500
              AND calls > 0
        """))
        return result.scalar() or 0
    except Exception:
        db.rollback()  # pg_stat_statements not installed — reset aborted txn
        return 0


# ---------------------------------------------------------------------------
# AI health (reads in-memory stats — no live API calls)
# ---------------------------------------------------------------------------

def check_ai_health() -> dict:
    key_stats = ops_metrics.get_ai_key_stats()
    all_failed = ops_metrics.get_all_ai_keys_failed()

    gemini_healthy = True
    deepseek_healthy = True
    now = datetime.now(timezone.utc)
    cutoff = (now - timedelta(minutes=10)).isoformat()

    for idx, stats in key_stats.items():
        model = stats.get("model", "")
        last_429 = stats.get("last_429_at")
        last_ok = stats.get("last_success_at")
        failed = last_429 and last_429 >= cutoff and (not last_ok or last_ok < cutoff)
        if "gemini" in model.lower() and failed:
            gemini_healthy = False
        if "deepseek" in model.lower() and failed:
            deepseek_healthy = False

    return {
        "gemini_healthy": gemini_healthy,
        "deepseek_healthy": deepseek_healthy,
        "all_ai_keys_failed": all_failed,
        "ai_fallback_rate_1h": round(ops_metrics.get_ai_fallback_rate(1), 3),
    }


# ---------------------------------------------------------------------------
# Scheduler health
# ---------------------------------------------------------------------------

def check_scheduler_health() -> bool:
    runs = ops_metrics.get_scheduler_health()
    if not runs:
        return True  # no jobs have run yet — not an error on fresh startup
    now = datetime.now(timezone.utc)
    # If any job hasn't run successfully in 2× its expected interval, flag it
    for job_id, info in runs.items():
        if not info.get("success"):
            return False
        last_run_str = info.get("last_run_at")
        if last_run_str:
            try:
                last_run = datetime.fromisoformat(last_run_str)
                # p0_check should run every minute — stale if >5 min
                if "p0" in job_id and (now - last_run) > timedelta(minutes=5):
                    return False
                # weekly jobs — stale if >8 days
                if "weekly" in job_id and (now - last_run) > timedelta(days=8):
                    return False
            except Exception:
                pass
    return True


# ---------------------------------------------------------------------------
# DB aggregate queries — clinical, user, doctor, whatsapp ops
# All return aggregate counts/rates ONLY. No PHI.
# ---------------------------------------------------------------------------

def get_user_ops_metrics(db: Session) -> dict:
    now = datetime.now(timezone.utc)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    yesterday_start = today_start - timedelta(days=1)
    seven_days_ago = now - timedelta(days=7)

    # New registrations today vs yesterday
    new_today = db.query(func.count(User.id)).filter(User.created_at >= today_start).scalar() or 0
    new_yesterday = db.query(func.count(User.id)).filter(
        User.created_at >= yesterday_start, User.created_at < today_start
    ).scalar() or 0

    # Stuck sessions: users who haven't logged in for >7 days
    stuck_sessions = db.query(func.count(User.id)).filter(
        User.last_login_at < seven_days_ago,
        User.is_active == True,  # noqa: E712
    ).scalar() or 0

    # Patients with zero readings >7 days
    # Profile IDs that had at least one reading in the last 7 days
    from models import ProfileAccess
    profiles_with_recent_reading = db.query(HealthReading.profile_id).filter(
        HealthReading.reading_timestamp >= seven_days_ago
    ).distinct().subquery()
    total_active_profiles = db.query(func.count(Profile.id)).scalar() or 0
    profiles_with_reading_count = db.query(func.count()).select_from(
        profiles_with_recent_reading
    ).scalar() or 0
    patients_no_reading_7d = max(0, total_active_profiles - profiles_with_reading_count)

    return {
        "new_registrations_today": new_today,
        "new_registrations_yesterday": new_yesterday,
        "stuck_sessions_count": stuck_sessions,
        "patients_no_reading_7d": patients_no_reading_7d,
    }


def get_clinical_ops_metrics(db: Session) -> dict:
    now = datetime.now(timezone.utc)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    two_hours_ago = now - timedelta(hours=2)

    # Critical alerts today
    alert_sent = db.query(func.count(CriticalAlertLog.id)).filter(
        CriticalAlertLog.created_at >= today_start,
        CriticalAlertLog.status == "sent",
    ).scalar() or 0
    alert_failed = db.query(func.count(CriticalAlertLog.id)).filter(
        CriticalAlertLog.created_at >= today_start,
        CriticalAlertLog.status == "failed",
    ).scalar() or 0
    alert_skipped = db.query(func.count(CriticalAlertLog.id)).filter(
        CriticalAlertLog.created_at >= today_start,
        CriticalAlertLog.status == "skipped",
    ).scalar() or 0

    # Critical readings unacknowledged >2h (CRITICAL flag, no sent alert within window)
    critical_readings = db.query(HealthReading).filter(
        HealthReading.status_flag == "CRITICAL",
        HealthReading.reading_timestamp < two_hours_ago,
    ).all()
    unacked_count = 0
    for reading in critical_readings:
        sent = db.query(func.count(CriticalAlertLog.id)).filter(
            CriticalAlertLog.profile_id == reading.profile_id,
            CriticalAlertLog.status == "sent",
            CriticalAlertLog.created_at >= reading.reading_timestamp,
        ).scalar() or 0
        if sent == 0:
            unacked_count += 1

    # Chat quota exhaustions today
    chat_quota_exhaustions = db.query(func.count(ChatMessage.id)).filter(
        ChatMessage.created_at >= today_start,
        ChatMessage.tokens_used == 0,  # quota hit returns empty response
    ).scalar() or 0

    # AI average latency (from in-memory)
    latency = ops_metrics.get_latency_percentiles()

    return {
        "critical_alerts_sent_today": alert_sent,
        "critical_alerts_failed_today": alert_failed,
        "critical_alerts_skipped_today": alert_skipped,
        "critical_alerts_unacked_2h": unacked_count,
        "chat_quota_exhaustions_today": chat_quota_exhaustions,
        "avg_ai_latency_p95_ms": latency["p95_ms"],
    }


def get_doctor_ops_metrics(db: Session) -> dict:
    now = datetime.now(timezone.utc)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)

    pending_verifications = db.query(func.count(DoctorProfile.id)).filter(
        DoctorProfile.is_verified == False  # noqa: E712
    ).scalar() or 0

    doctor_logins_today = db.query(func.count(func.distinct(DoctorAccessLog.doctor_id))).filter(
        DoctorAccessLog.created_at >= today_start,
    ).scalar() or 0

    active_links = db.query(func.count(DoctorPatientLink.id)).filter(
        DoctorPatientLink.status == "active"
    ).scalar() or 0

    return {
        "pending_doctor_verifications": pending_verifications,
        "doctor_logins_today": doctor_logins_today,
        "active_doctor_patient_links": active_links,
    }


def get_whatsapp_ops_metrics(db: Session) -> dict:
    now = datetime.now(timezone.utc)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)

    from models import WhatsAppMessageStatus, ReportGenerationStatus
    wa_sent = db.query(func.count(WhatsAppMessageLog.id)).filter(
        WhatsAppMessageLog.sent_at >= today_start,
        WhatsAppMessageLog.status.in_([WhatsAppMessageStatus.SENT, WhatsAppMessageStatus.DELIVERED]),
    ).scalar() or 0
    wa_failed = db.query(func.count(WhatsAppMessageLog.id)).filter(
        WhatsAppMessageLog.sent_at >= today_start,
        WhatsAppMessageLog.status == WhatsAppMessageStatus.FAILED,
    ).scalar() or 0
    wa_total = wa_sent + wa_failed
    wa_fail_rate = (wa_failed / wa_total) if wa_total > 0 else 0.0

    active_sessions = db.query(func.count(WhatsAppSession.id)).filter(
        WhatsAppSession.expires_at > now
    ).scalar() or 0

    report_success = db.query(func.count(ReportGenerationLog.id)).filter(
        ReportGenerationLog.generated_at >= today_start,
        ReportGenerationLog.status == ReportGenerationStatus.SUCCESS,
    ).scalar() or 0
    report_total = db.query(func.count(ReportGenerationLog.id)).filter(
        ReportGenerationLog.generated_at >= today_start
    ).scalar() or 0
    report_success_rate = (report_success / report_total) if report_total > 0 else 1.0

    return {
        "wa_sent_today": wa_sent,
        "wa_failed_today": wa_failed,
        "wa_fail_rate_today": round(wa_fail_rate, 3),
        "inbound_sessions_active": active_sessions,
        "report_success_rate_today": round(report_success_rate, 3),
    }


# ---------------------------------------------------------------------------
# Master snapshot builder — writes SystemHealthSnapshot row
# ---------------------------------------------------------------------------

def take_health_snapshot(db: Session) -> SystemHealthSnapshot:
    """Collect all metrics and persist a SystemHealthSnapshot row."""
    db_info = check_db_health(db)
    ai_info = check_ai_health()
    mem_info = check_memory()
    disk_info = check_disk()
    errors = ops_metrics.get_error_rate(300)
    latency = ops_metrics.get_latency_percentiles()
    mem_trend = ops_metrics.get_memory_growth_trend()
    slow_q = check_db_slow_queries(db)

    doctor_info = get_doctor_ops_metrics(db)
    clinical_info = get_clinical_ops_metrics(db)
    wa_info = get_whatsapp_ops_metrics(db)

    snap = SystemHealthSnapshot(
        api_healthy=True,  # if we're here, the API is alive
        db_healthy=db_info["db_healthy"],
        db_pool_used=db_info["db_pool_used"],
        db_pool_size=db_info["db_pool_size"],
        db_slow_queries_1h=slow_q,
        gemini_healthy=ai_info["gemini_healthy"],
        deepseek_healthy=ai_info["deepseek_healthy"],
        all_ai_keys_failed=ai_info["all_ai_keys_failed"],
        scheduler_healthy=check_scheduler_health(),
        error_rate_5xx_5min=errors["errors_5xx"],
        error_rate_4xx_5min=errors["errors_4xx"],
        error_rate_401_5min=errors["errors_401"],
        error_rate_422_5min=errors["errors_422"],
        p50_latency_ms=latency["p50_ms"],
        p95_latency_ms=latency["p95_ms"],
        concurrent_requests=ops_metrics.get_concurrent_count(),
        concurrent_peak=ops_metrics.get_concurrent_peak(),
        memory_pct=mem_info["memory_pct"],
        memory_rss_mb=mem_info["memory_rss_mb"],
        swap_active=mem_info["swap_active"],
        disk_pct=disk_info["disk_pct"],
        cpu_burst_credits_low=check_cpu_burst_credits(),
        file_descriptors=check_file_descriptors(),
        memory_growth_mb_per_hour=mem_trend["trend_mb_per_hour"],
        ai_fallback_rate_1h=ai_info["ai_fallback_rate_1h"],
        pending_doctor_verifications=doctor_info["pending_doctor_verifications"],
        critical_alerts_unacked_2h=clinical_info["critical_alerts_unacked_2h"],
        critical_alerts_failed_today=clinical_info["critical_alerts_failed_today"],
        patients_no_reading_7d=0,  # computed separately in user_ops
        whatsapp_fail_rate_today=wa_info["wa_fail_rate_today"],
    )
    db.add(snap)
    db.commit()
    db.refresh(snap)
    return snap
