"""
ops_alerting.py — Tiered alert evaluation and deduplication for ops monitoring.

Alert tiers:
  P0 — Immediate email (enabled at launch)
  P1 — Within 15 min (disabled at launch, enable via config flag)
  P2 — Weekly digest, Sundays 08:00 IST (enabled at launch)

PHI invariant: alert bodies contain ONLY aggregate counts/rates/booleans.
"""

import json
import logging
from dataclasses import dataclass, field
from datetime import datetime, timezone, timedelta
from typing import Optional

from sqlalchemy.orm import Session
from sqlalchemy import func

from config import settings
from models import OpsAlertLog, SystemHealthSnapshot
import ops_metrics

logger = logging.getLogger("swasth.ops_alerting")


@dataclass
class AlertCandidate:
    alert_key: str       # stable dedup key e.g. "P0_db_down"
    tier: str            # "P0" | "P1" | "P2"
    title: str
    body: dict = field(default_factory=dict)
    should_fire: bool = True


# ---------------------------------------------------------------------------
# Deduplication
# ---------------------------------------------------------------------------

def _is_suppressed(alert_key: str, tier: str, db: Session) -> bool:
    """Returns True if this alert_key already fired within the cooldown window."""
    now = datetime.now(timezone.utc)
    if tier == "P0":
        cooldown = timedelta(minutes=settings.OPS_P0_COOLDOWN_MINUTES)
    elif tier == "P1":
        cooldown = timedelta(minutes=settings.OPS_P1_COOLDOWN_MINUTES)
    else:
        cooldown = timedelta(hours=settings.OPS_P2_COOLDOWN_HOURS)

    cutoff = now - cooldown
    existing = db.query(OpsAlertLog).filter(
        OpsAlertLog.alert_key == alert_key,
        OpsAlertLog.email_sent == True,  # noqa: E712
        OpsAlertLog.created_at >= cutoff,
    ).first()
    return existing is not None


# ---------------------------------------------------------------------------
# P0 evaluation — enabled at launch
# ---------------------------------------------------------------------------

def evaluate_p0(snapshot: SystemHealthSnapshot) -> list[AlertCandidate]:
    """Evaluate P0 conditions from a fresh SystemHealthSnapshot."""
    if not settings.OPS_ALERTS_ENABLED or not settings.OPS_P0_ALERTS_ENABLED:
        return []

    candidates = []

    if not snapshot.db_healthy:
        candidates.append(AlertCandidate(
            alert_key="P0_db_down",
            tier="P0",
            title="Database unreachable",
            body={"db_healthy": False},
        ))

    if snapshot.all_ai_keys_failed:
        candidates.append(AlertCandidate(
            alert_key="P0_all_ai_failed",
            tier="P0",
            title="All AI keys exhausted — falling back to rule-based only",
            body={"all_ai_keys_failed": True, "ai_fallback_rate_1h": snapshot.ai_fallback_rate_1h},
        ))

    if snapshot.memory_pct and snapshot.memory_pct >= settings.OPS_MEMORY_P0_THRESHOLD:
        candidates.append(AlertCandidate(
            alert_key="P0_memory_critical",
            tier="P0",
            title=f"Memory critical: {snapshot.memory_pct:.0%} used",
            body={
                "memory_pct": snapshot.memory_pct,
                "memory_rss_mb": snapshot.memory_rss_mb,
                "swap_active": snapshot.swap_active,
            },
        ))

    if snapshot.swap_active:
        candidates.append(AlertCandidate(
            alert_key="P0_swap_active",
            tier="P0",
            title="Swap memory active — OOM risk on t3.micro",
            body={"swap_active": True, "memory_pct": snapshot.memory_pct},
        ))

    if snapshot.concurrent_requests and snapshot.concurrent_requests >= settings.OPS_CONCURRENT_P0_THRESHOLD:
        candidates.append(AlertCandidate(
            alert_key="P0_concurrent_overload",
            tier="P0",
            title=f"Concurrent requests critical: {snapshot.concurrent_requests} active",
            body={
                "concurrent_requests": snapshot.concurrent_requests,
                "threshold": settings.OPS_CONCURRENT_P0_THRESHOLD,
            },
        ))

    # >50% critical health alerts failing
    sent = snapshot.critical_alerts_failed_today or 0
    # We need failed / (sent + failed) > threshold — use snapshot totals
    # Note: critical_alerts_failed_today is stored; compute ratio carefully
    if sent > 0:
        total_alerts = sent + (snapshot.critical_alerts_unacked_2h or 0)
        if total_alerts > 0:
            fail_rate = sent / total_alerts
            if fail_rate >= settings.OPS_CRITICAL_ALERT_FAIL_P0_THRESHOLD:
                candidates.append(AlertCandidate(
                    alert_key="P0_critical_alerts_failing",
                    tier="P0",
                    title=f"Critical health alerts failing: {fail_rate:.0%} failure rate",
                    body={"failed_today": sent, "fail_rate": round(fail_rate, 2)},
                ))

    return candidates


# ---------------------------------------------------------------------------
# P1 evaluation — disabled at launch (OPS_P1_ALERTS_ENABLED=False)
# ---------------------------------------------------------------------------

def evaluate_p1(snapshot: SystemHealthSnapshot) -> list[AlertCandidate]:
    """Evaluate P1 conditions. Returns empty list if P1 alerts are disabled."""
    if not settings.OPS_ALERTS_ENABLED or not settings.OPS_P1_ALERTS_ENABLED:
        return []

    candidates = []

    if (snapshot.error_rate_5xx_5min or 0) >= settings.OPS_ERROR_RATE_P1_THRESHOLD:
        candidates.append(AlertCandidate(
            alert_key="P1_error_rate_spike",
            tier="P1",
            title=f"Error rate spike: {snapshot.error_rate_5xx_5min} 500s in 5 min",
            body={"errors_5xx_5min": snapshot.error_rate_5xx_5min, "threshold": settings.OPS_ERROR_RATE_P1_THRESHOLD},
        ))

    if (snapshot.ai_fallback_rate_1h or 0) >= settings.OPS_AI_FALLBACK_P1_THRESHOLD:
        candidates.append(AlertCandidate(
            alert_key="P1_ai_fallback_spike",
            tier="P1",
            title=f"AI fallback rate high: {snapshot.ai_fallback_rate_1h:.0%} past hour",
            body={"fallback_rate_1h": snapshot.ai_fallback_rate_1h, "threshold": settings.OPS_AI_FALLBACK_P1_THRESHOLD},
        ))

    if (snapshot.critical_alerts_unacked_2h or 0) > 0:
        candidates.append(AlertCandidate(
            alert_key="P1_critical_readings_unacked",
            tier="P1",
            title=f"Critical readings unacknowledged >2h: {snapshot.critical_alerts_unacked_2h}",
            body={"unacked_count": snapshot.critical_alerts_unacked_2h},
        ))

    if snapshot.cpu_burst_credits_low:
        candidates.append(AlertCandidate(
            alert_key="P1_cpu_credits_low",
            tier="P1",
            title="t3.micro CPU burst credits low — throttling risk",
            body={"cpu_burst_credits_low": True},
        ))

    if (snapshot.concurrent_requests or 0) >= settings.OPS_CONCURRENT_P1_THRESHOLD:
        candidates.append(AlertCandidate(
            alert_key="P1_concurrent_high",
            tier="P1",
            title=f"Concurrent requests high: {snapshot.concurrent_requests}",
            body={"concurrent_requests": snapshot.concurrent_requests, "threshold": settings.OPS_CONCURRENT_P1_THRESHOLD},
        ))

    if (snapshot.disk_pct or 0) >= settings.OPS_DISK_P1_THRESHOLD:
        candidates.append(AlertCandidate(
            alert_key="P1_disk_high",
            tier="P1",
            title=f"Disk usage high: {snapshot.disk_pct:.0%}",
            body={"disk_pct": snapshot.disk_pct, "threshold": settings.OPS_DISK_P1_THRESHOLD},
        ))

    # Check per-key AI quota
    for idx, stats in ops_metrics.get_ai_key_stats().items():
        daily_req = stats.get("requests_today", 0)
        # Gemini free tier: ~1500 req/day — warn at 80%
        gemini_daily_limit = 1500
        if "gemini" in stats.get("model", "").lower() and daily_req >= int(gemini_daily_limit * settings.OPS_AI_KEY_QUOTA_P1_THRESHOLD):
            candidates.append(AlertCandidate(
                alert_key=f"P1_ai_key_quota_{idx}",
                tier="P1",
                title=f"AI key #{idx} at {daily_req}/{gemini_daily_limit} requests today",
                body={"key_index": idx, "requests_today": daily_req, "daily_limit": gemini_daily_limit},
            ))

    return candidates


# ---------------------------------------------------------------------------
# P2 evaluation — weekly digest
# ---------------------------------------------------------------------------

def evaluate_p2(snapshot: SystemHealthSnapshot, db: Session) -> list[AlertCandidate]:
    """Evaluate P2 conditions for the weekly digest."""
    if not settings.OPS_ALERTS_ENABLED or not settings.OPS_P2_ALERTS_ENABLED:
        return []

    candidates = []

    if (snapshot.pending_doctor_verifications or 0) > settings.OPS_PENDING_DOCTORS_P2_THRESHOLD:
        candidates.append(AlertCandidate(
            alert_key="P2_pending_doctors",
            tier="P2",
            title=f"Doctor verification queue: {snapshot.pending_doctor_verifications} pending",
            body={"pending_count": snapshot.pending_doctor_verifications},
        ))

    if (snapshot.patients_no_reading_7d or 0) > 0:
        candidates.append(AlertCandidate(
            alert_key="P2_patients_no_reading",
            tier="P2",
            title=f"Patients inactive >7 days: {snapshot.patients_no_reading_7d}",
            body={"count": snapshot.patients_no_reading_7d},
        ))

    return candidates


# ---------------------------------------------------------------------------
# Fire — deduplicate, send email, log
# ---------------------------------------------------------------------------

def fire_alert(candidate: AlertCandidate, db: Session, email_service) -> bool:
    """
    Fire an alert: check dedup window → send email → write OpsAlertLog.
    Returns True if email was sent.
    """
    if not candidate.should_fire:
        return False

    suppressed = _is_suppressed(candidate.alert_key, candidate.tier, db)

    log_entry = OpsAlertLog(
        alert_key=candidate.alert_key,
        tier=candidate.tier,
        title=candidate.title,
        body_json=json.dumps(candidate.body),
        email_sent=False,
    )

    email_sent = False
    if not suppressed:
        try:
            sent = email_service.send_ops_alert_email(
                recipient_email=settings.OPS_ALERT_EMAIL,
                tier=candidate.tier,
                title=candidate.title,
                metrics=candidate.body,
                timestamp=datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
            )
            if sent:
                log_entry.email_sent = True
                log_entry.email_sent_at = datetime.now(timezone.utc)
                email_sent = True
        except Exception:
            logger.error("Failed to send ops alert email key=%s", candidate.alert_key, exc_info=True)
    else:
        logger.debug("ops_alert suppressed key=%s tier=%s", candidate.alert_key, candidate.tier)

    db.add(log_entry)
    db.commit()
    return email_sent


def fire_p2_digest(candidates: list[AlertCandidate], db: Session, email_service) -> bool:
    """
    Bundle all P2 candidates into a single digest email.
    Uses a single dedup key for the whole digest.
    """
    if not candidates:
        return False

    digest_key = "P2_weekly_digest"
    if _is_suppressed(digest_key, "P2", db):
        return False

    combined_body = {c.alert_key: c.body for c in candidates}
    combined_title = f"Weekly Ops Digest — {len(candidates)} item(s)"

    sent = False
    try:
        sent = email_service.send_ops_alert_email(
            recipient_email=settings.OPS_ALERT_EMAIL,
            tier="P2",
            title=combined_title,
            metrics=combined_body,
            timestamp=datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
        )
    except Exception:
        logger.error("Failed to send P2 digest email", exc_info=True)

    log_entry = OpsAlertLog(
        alert_key=digest_key,
        tier="P2",
        title=combined_title,
        body_json=json.dumps(combined_body),
        email_sent=sent,
        email_sent_at=datetime.now(timezone.utc) if sent else None,
    )
    db.add(log_entry)
    db.commit()
    return sent
