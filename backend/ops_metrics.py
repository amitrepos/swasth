"""
ops_metrics.py — In-memory telemetry ring-buffer for operational monitoring.

Imported by main.py BEFORE Base.metadata.create_all() so the middleware
attaches before any route fires. All structures are module-level singletons.
No DB writes, no external deps — pure Python collections.
"""

import threading
import time
from collections import deque
from datetime import datetime, timezone, timedelta
from typing import Optional

# ---------------------------------------------------------------------------
# Latency ring-buffer — stores (timestamp, endpoint, latency_ms, status_code)
# ---------------------------------------------------------------------------
_LATENCY_BUFFER_SIZE = 2000
_latency_lock = threading.Lock()
_latency_buffer: deque = deque(maxlen=_LATENCY_BUFFER_SIZE)

# ---------------------------------------------------------------------------
# Error rate — sliding 5-min window of (timestamp, status_code, endpoint)
# ---------------------------------------------------------------------------
_ERROR_WINDOW_SECONDS = 300  # 5 minutes
_error_lock = threading.Lock()
_error_window: deque = deque()

# ---------------------------------------------------------------------------
# Concurrent request gauge
# ---------------------------------------------------------------------------
_concurrent_lock = threading.Lock()
_concurrent_count: int = 0
_concurrent_peak: int = 0

# ---------------------------------------------------------------------------
# AI key stats — {key_index: {requests_today, last_429_at, last_success_at, fallbacks_today}}
# Updated by ai_service.py on every call.
# ---------------------------------------------------------------------------
_ai_lock = threading.Lock()
_ai_key_stats: dict = {}
_ai_fallback_events: deque = deque(maxlen=500)  # (timestamp, from_model, to_model)

# ---------------------------------------------------------------------------
# Scheduler last-run — {job_id: {last_run_at, success}}
# ---------------------------------------------------------------------------
_scheduler_lock = threading.Lock()
_scheduler_last_run: dict = {}

# ---------------------------------------------------------------------------
# Memory growth tracking — (timestamp, rss_bytes) samples for leak detection
# ---------------------------------------------------------------------------
_memory_samples: deque = deque(maxlen=120)  # 2 hours at 1-min intervals

# ---------------------------------------------------------------------------
# Public write API (called from middleware and services)
# ---------------------------------------------------------------------------

def record_request(endpoint: str, latency_ms: int, status_code: int) -> None:
    now = datetime.now(timezone.utc)
    with _latency_lock:
        _latency_buffer.append((now, endpoint, latency_ms, status_code))
    if status_code >= 400:
        with _error_lock:
            _error_window.append((now, status_code, endpoint))
            _purge_error_window(now)


def increment_concurrent() -> int:
    global _concurrent_count, _concurrent_peak
    with _concurrent_lock:
        _concurrent_count += 1
        if _concurrent_count > _concurrent_peak:
            _concurrent_peak = _concurrent_count
        return _concurrent_count


def decrement_concurrent() -> int:
    global _concurrent_count
    with _concurrent_lock:
        _concurrent_count = max(0, _concurrent_count - 1)
        return _concurrent_count


def record_ai_call(key_index: int, model: str, fallback: bool,
                   latency_ms: int, hit_429: bool = False) -> None:
    now = datetime.now(timezone.utc)
    today = now.date().isoformat()
    with _ai_lock:
        if key_index not in _ai_key_stats:
            _ai_key_stats[key_index] = {
                "model": model,
                "requests_today": 0,
                "requests_date": today,
                "last_429_at": None,
                "last_success_at": None,
                "fallbacks_today": 0,
            }
        stats = _ai_key_stats[key_index]
        # Reset daily counter on new day
        if stats["requests_date"] != today:
            stats["requests_today"] = 0
            stats["fallbacks_today"] = 0
            stats["requests_date"] = today
        stats["requests_today"] += 1
        if hit_429:
            stats["last_429_at"] = now.isoformat()
        else:
            stats["last_success_at"] = now.isoformat()
        if fallback:
            stats["fallbacks_today"] += 1
            _ai_fallback_events.append((now, model))


def record_scheduler_run(job_id: str, success: bool) -> None:
    with _scheduler_lock:
        _scheduler_last_run[job_id] = {
            "last_run_at": datetime.now(timezone.utc).isoformat(),
            "success": success,
        }


def record_memory_sample(rss_bytes: int) -> None:
    _memory_samples.append((datetime.now(timezone.utc), rss_bytes))


# ---------------------------------------------------------------------------
# Public read API (called by ops_health.py and routes_admin.py)
# ---------------------------------------------------------------------------

def get_concurrent_count() -> int:
    with _concurrent_lock:
        return _concurrent_count


def get_concurrent_peak() -> int:
    with _concurrent_lock:
        return _concurrent_peak


def get_error_rate(window_seconds: int = 300) -> dict:
    """Returns count of 4xx and 5xx errors in the given window."""
    now = datetime.now(timezone.utc)
    cutoff = now - timedelta(seconds=window_seconds)
    with _error_lock:
        _purge_error_window(now)
        errors_5xx = sum(1 for ts, code, _ in _error_window if ts >= cutoff and code >= 500)
        errors_4xx = sum(1 for ts, code, _ in _error_window if ts >= cutoff and 400 <= code < 500)
        errors_401 = sum(1 for ts, code, _ in _error_window if ts >= cutoff and code == 401)
        errors_422 = sum(1 for ts, code, _ in _error_window if ts >= cutoff and code == 422)
    return {
        "window_seconds": window_seconds,
        "errors_5xx": errors_5xx,
        "errors_4xx": errors_4xx,
        "errors_401": errors_401,
        "errors_422": errors_422,
    }


def get_latency_percentiles(endpoint: Optional[str] = None) -> dict:
    """Returns P50 and P95 latency in ms. Filters by endpoint if given."""
    with _latency_lock:
        if endpoint:
            samples = [lat for _, ep, lat, _ in _latency_buffer if ep == endpoint]
        else:
            samples = [lat for _, _, lat, _ in _latency_buffer]
    if not samples:
        return {"p50_ms": 0, "p95_ms": 0, "sample_count": 0}
    samples.sort()
    n = len(samples)
    p50 = samples[int(n * 0.50)]
    p95 = samples[min(int(n * 0.95), n - 1)]
    return {"p50_ms": p50, "p95_ms": p95, "sample_count": n}


def get_ai_fallback_rate(window_hours: int = 1) -> float:
    """Returns fraction of AI calls that were fallbacks in the past N hours."""
    now = datetime.now(timezone.utc)
    cutoff = now - timedelta(hours=window_hours)
    with _latency_lock:
        total_ai = sum(
            1 for ts, ep, _, _ in _latency_buffer
            if ts >= cutoff and "ai" in ep.lower()
        )
    with _ai_lock:
        fallbacks = sum(1 for ts, _ in _ai_fallback_events if ts >= cutoff)
    if total_ai == 0:
        # Fall back to raw fallback event count vs estimate
        all_events = sum(1 for ts, _ in _ai_fallback_events if ts >= cutoff)
        return 0.0 if all_events == 0 else min(1.0, all_events / max(all_events, 1))
    return min(1.0, fallbacks / total_ai)


def get_ai_key_stats() -> dict:
    with _ai_lock:
        return dict(_ai_key_stats)


def get_all_ai_keys_failed() -> bool:
    """True if every known key has a recent 429 (within last 10 minutes)."""
    now = datetime.now(timezone.utc)
    cutoff = (now - timedelta(minutes=10)).isoformat()
    with _ai_lock:
        if not _ai_key_stats:
            return False
        return all(
            stats.get("last_429_at") and stats["last_429_at"] >= cutoff
            and (stats.get("last_success_at") is None or stats["last_success_at"] < cutoff)
            for stats in _ai_key_stats.values()
        )


def get_scheduler_health() -> dict:
    with _scheduler_lock:
        return dict(_scheduler_last_run)


def get_memory_growth_trend() -> dict:
    """Returns memory growth in MB over the last hour."""
    samples = list(_memory_samples)
    if len(samples) < 2:
        return {"trend_mb_per_hour": 0.0, "current_rss_mb": 0}
    one_hour_ago = datetime.now(timezone.utc) - timedelta(hours=1)
    recent = [(ts, rss) for ts, rss in samples if ts >= one_hour_ago]
    if len(recent) < 2:
        return {"trend_mb_per_hour": 0.0, "current_rss_mb": samples[-1][1] / 1_048_576}
    start_rss = recent[0][1]
    end_rss = recent[-1][1]
    trend = (end_rss - start_rss) / 1_048_576  # MB
    return {
        "trend_mb_per_hour": round(trend, 2),
        "current_rss_mb": round(end_rss / 1_048_576, 1),
    }


def get_top_slow_endpoints(top_n: int = 5) -> list:
    """Returns the slowest endpoints by P95 latency."""
    with _latency_lock:
        endpoints: dict = {}
        for _, ep, lat, _ in _latency_buffer:
            endpoints.setdefault(ep, []).append(lat)
    result = []
    for ep, lats in endpoints.items():
        lats.sort()
        n = len(lats)
        p95 = lats[min(int(n * 0.95), n - 1)]
        result.append({"endpoint": ep, "p95_ms": p95, "count": n})
    result.sort(key=lambda x: x["p95_ms"], reverse=True)
    return result[:top_n]


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _purge_error_window(now: datetime) -> None:
    """Remove entries older than ERROR_WINDOW_SECONDS. Must be called with _error_lock held."""
    cutoff = now - timedelta(seconds=_ERROR_WINDOW_SECONDS)
    while _error_window and _error_window[0][0] < cutoff:
        _error_window.popleft()
