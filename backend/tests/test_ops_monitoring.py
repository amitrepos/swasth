"""Tests for operational monitoring — ops_metrics, ops_health, ops_alerting, routes."""
import json
import pytest
from datetime import datetime, timezone, timedelta
from unittest.mock import MagicMock, patch
from fastapi.testclient import TestClient

import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import models
import ops_metrics
import ops_alerting
from auth import create_access_token, get_password_hash


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture()
def admin_user(db):
    user = models.User(
        email="ops_admin@swasth.app",
        password_hash=get_password_hash("Admin@1234"),
        full_name="Ops Admin",
        is_admin=True,
    )
    db.add(user)
    db.flush()
    return user


@pytest.fixture()
def admin_headers(admin_user):
    return {"Authorization": f"Bearer {create_access_token(data={'sub': admin_user.email})}"}


@pytest.fixture()
def regular_user(db):
    user = models.User(
        email="regular_ops@swasth.app",
        password_hash=get_password_hash("User@1234"),
        full_name="Regular User",
        is_admin=False,
    )
    db.add(user)
    db.flush()
    return user


@pytest.fixture()
def regular_headers(regular_user):
    return {"Authorization": f"Bearer {create_access_token(data={'sub': regular_user.email})}"}


# ---------------------------------------------------------------------------
# 1. ops-metrics route — admin gets 200
# ---------------------------------------------------------------------------

class TestOpsMetricsRoute:
    def test_admin_gets_200(self, client, admin_user, admin_headers, db):
        resp = client.get("/api/admin/ops-metrics", headers=admin_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert "system" in body
        assert "clinical_ops" in body
        assert "doctor_ops" in body
        assert "recent_alerts" in body

    def test_non_admin_gets_403(self, client, regular_user, regular_headers, db):
        resp = client.get("/api/admin/ops-metrics", headers=regular_headers)
        assert resp.status_code == 403

    def test_unauthenticated_gets_401(self, client):
        resp = client.get("/api/admin/ops-metrics")
        assert resp.status_code == 401


# ---------------------------------------------------------------------------
# 2. ops-health route
# ---------------------------------------------------------------------------

class TestOpsHealthRoute:
    def test_returns_snapshot_or_no_snapshot_yet(self, client, admin_user, admin_headers, db):
        resp = client.get("/api/admin/ops-health", headers=admin_headers)
        assert resp.status_code == 200

    def test_returns_latest_snapshot_when_exists(self, client, admin_user, admin_headers, db):
        snap = models.SystemHealthSnapshot(
            api_healthy=True,
            db_healthy=True,
            memory_pct=0.45,
        )
        db.add(snap)
        db.commit()
        resp = client.get("/api/admin/ops-health", headers=admin_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert body["api_healthy"] is True
        assert body["db_healthy"] is True


# ---------------------------------------------------------------------------
# 3. In-memory error rate counter
# ---------------------------------------------------------------------------

class TestOpsMetricsInMemory:
    def setup_method(self):
        # Clear error window before each test
        with ops_metrics._error_lock:
            ops_metrics._error_window.clear()

    def test_error_rate_increments_on_500(self):
        for _ in range(5):
            ops_metrics.record_request("/api/test", 0, 500)
        result = ops_metrics.get_error_rate(300)
        assert result["errors_5xx"] == 5

    def test_4xx_tracked_separately(self):
        ops_metrics.record_request("/api/login", 10, 401)
        ops_metrics.record_request("/api/login", 10, 401)
        ops_metrics.record_request("/api/data", 10, 422)
        result = ops_metrics.get_error_rate(300)
        assert result["errors_401"] == 2
        assert result["errors_422"] == 1

    def test_concurrent_gauge_increments_and_decrements(self):
        ops_metrics._concurrent_count = 0
        ops_metrics.increment_concurrent()
        ops_metrics.increment_concurrent()
        assert ops_metrics.get_concurrent_count() == 2
        ops_metrics.decrement_concurrent()
        assert ops_metrics.get_concurrent_count() == 1
        ops_metrics._concurrent_count = 0  # cleanup


# ---------------------------------------------------------------------------
# 4. Alert deduplication
# ---------------------------------------------------------------------------

class TestOpsAlertDeduplication:
    def test_same_key_within_cooldown_suppressed(self, db):
        from config import settings
        # Insert a fired alert
        log = models.OpsAlertLog(
            alert_key="P0_db_down",
            tier="P0",
            title="DB down",
            email_sent=True,
            email_sent_at=datetime.now(timezone.utc),
        )
        db.add(log)
        db.commit()

        suppressed = ops_alerting._is_suppressed("P0_db_down", "P0", db)
        assert suppressed is True

    def test_different_key_not_suppressed(self, db):
        log = models.OpsAlertLog(
            alert_key="P0_db_down",
            tier="P0",
            title="DB down",
            email_sent=True,
            email_sent_at=datetime.now(timezone.utc),
        )
        db.add(log)
        db.commit()

        suppressed = ops_alerting._is_suppressed("P0_memory_critical", "P0", db)
        assert suppressed is False

    def test_expired_cooldown_not_suppressed(self, db):
        from config import settings
        old_time = datetime.now(timezone.utc) - timedelta(minutes=settings.OPS_P0_COOLDOWN_MINUTES + 5)
        log = models.OpsAlertLog(
            alert_key="P0_db_down",
            tier="P0",
            title="DB down",
            email_sent=True,
            email_sent_at=old_time,
            created_at=old_time,
        )
        db.add(log)
        db.commit()

        suppressed = ops_alerting._is_suppressed("P0_db_down", "P0", db)
        assert suppressed is False


# ---------------------------------------------------------------------------
# 5. P0 evaluation — DB down
# ---------------------------------------------------------------------------

class TestP0Evaluation:
    def _make_snap(self, **kwargs):
        defaults = dict(
            api_healthy=True, db_healthy=True, all_ai_keys_failed=False,
            memory_pct=0.5, swap_active=False, concurrent_requests=10,
            critical_alerts_failed_today=0, critical_alerts_unacked_2h=0,
            ai_fallback_rate_1h=0.0,
        )
        defaults.update(kwargs)
        snap = models.SystemHealthSnapshot(**defaults)
        return snap

    def test_db_down_fires_p0(self):
        snap = self._make_snap(db_healthy=False)
        candidates = ops_alerting.evaluate_p0(snap)
        keys = [c.alert_key for c in candidates]
        assert "P0_db_down" in keys

    def test_all_ai_failed_fires_p0(self):
        snap = self._make_snap(all_ai_keys_failed=True)
        candidates = ops_alerting.evaluate_p0(snap)
        keys = [c.alert_key for c in candidates]
        assert "P0_all_ai_failed" in keys

    def test_memory_critical_fires_p0(self):
        snap = self._make_snap(memory_pct=0.95)
        candidates = ops_alerting.evaluate_p0(snap)
        keys = [c.alert_key for c in candidates]
        assert "P0_memory_critical" in keys

    def test_swap_active_fires_p0(self):
        snap = self._make_snap(swap_active=True)
        candidates = ops_alerting.evaluate_p0(snap)
        keys = [c.alert_key for c in candidates]
        assert "P0_swap_active" in keys

    def test_healthy_system_no_p0(self):
        snap = self._make_snap()
        candidates = ops_alerting.evaluate_p0(snap)
        assert candidates == []


# ---------------------------------------------------------------------------
# 6. P2 evaluation — pending doctors
# ---------------------------------------------------------------------------

class TestP2Evaluation:
    def _make_snap(self, **kwargs):
        defaults = dict(
            api_healthy=True, db_healthy=True, all_ai_keys_failed=False,
            memory_pct=0.5, swap_active=False, concurrent_requests=10,
            pending_doctor_verifications=0, patients_no_reading_7d=0,
        )
        defaults.update(kwargs)
        return models.SystemHealthSnapshot(**defaults)

    def test_pending_doctors_above_threshold_fires_p2(self, db):
        snap = self._make_snap(pending_doctor_verifications=6)
        candidates = ops_alerting.evaluate_p2(snap, db)
        keys = [c.alert_key for c in candidates]
        assert "P2_pending_doctors" in keys

    def test_pending_doctors_below_threshold_no_p2(self, db):
        snap = self._make_snap(pending_doctor_verifications=3)
        candidates = ops_alerting.evaluate_p2(snap, db)
        keys = [c.alert_key for c in candidates]
        assert "P2_pending_doctors" not in keys


# ---------------------------------------------------------------------------
# 7. send_ops_alert_email — P0 subject line
# ---------------------------------------------------------------------------

class TestOpsAlertEmail:
    def test_p0_subject_prefix(self):
        from email_service import BrevoEmailService
        svc = BrevoEmailService()
        svc.smtp_login = "test@example.com"
        svc.sender_password = "password"

        sent_messages = []

        class FakeSMTP:
            def __init__(self, *a, **kw): pass
            def __enter__(self): return self
            def __exit__(self, *a): pass
            def starttls(self): pass
            def login(self, *a): pass
            def send_message(self, msg): sent_messages.append(msg)

        import smtplib
        with patch("smtplib.SMTP", FakeSMTP):
            result = svc.send_ops_alert_email(
                recipient_email="support@swasth.health",
                tier="P0",
                title="Database down",
                metrics={"db_healthy": False},
                timestamp="2026-04-27 12:00 UTC",
            )

        assert result is True
        assert len(sent_messages) == 1
        subject = sent_messages[0]["Subject"]
        assert "[P0 CRITICAL]" in subject

    def test_p1_subject_prefix(self):
        from email_service import BrevoEmailService
        svc = BrevoEmailService()
        svc.smtp_login = "test@example.com"
        svc.sender_password = "password"

        sent_messages = []

        class FakeSMTP:
            def __init__(self, *a, **kw): pass
            def __enter__(self): return self
            def __exit__(self, *a): pass
            def starttls(self): pass
            def login(self, *a): pass
            def send_message(self, msg): sent_messages.append(msg)

        with patch("smtplib.SMTP", FakeSMTP):
            result = svc.send_ops_alert_email(
                recipient_email="support@swasth.health",
                tier="P1",
                title="High fallback rate",
                metrics={"fallback_rate_1h": 0.45},
                timestamp="2026-04-27 12:00 UTC",
            )

        assert result is True
        assert "[P1 WARNING]" in sent_messages[0]["Subject"]

    def test_no_credentials_returns_false(self):
        from email_service import BrevoEmailService
        svc = BrevoEmailService()
        svc.smtp_login = ""
        svc.sender_password = ""
        result = svc.send_ops_alert_email(
            recipient_email="support@swasth.health",
            tier="P0",
            title="Test",
            metrics={},
            timestamp="now",
        )
        assert result is False


# ---------------------------------------------------------------------------
# 8. SystemHealthSnapshot model persists correctly
# ---------------------------------------------------------------------------

class TestSystemHealthSnapshotModel:
    def test_snapshot_persists(self, db):
        snap = models.SystemHealthSnapshot(
            api_healthy=True,
            db_healthy=True,
            gemini_healthy=True,
            deepseek_healthy=False,
            memory_pct=0.72,
            memory_rss_mb=739.5,
            swap_active=False,
            disk_pct=0.41,
            concurrent_requests=12,
            error_rate_5xx_5min=0,
            p50_latency_ms=85,
            p95_latency_ms=320,
        )
        db.add(snap)
        db.commit()

        loaded = db.query(models.SystemHealthSnapshot).order_by(
            models.SystemHealthSnapshot.id.desc()
        ).first()
        assert loaded.api_healthy is True
        assert loaded.db_healthy is True
        assert loaded.deepseek_healthy is False
        assert abs(loaded.memory_pct - 0.72) < 0.001
        assert loaded.p95_latency_ms == 320


# ---------------------------------------------------------------------------
# 9. OpsAlertLog model persists correctly
# ---------------------------------------------------------------------------

class TestOpsAlertLogModel:
    def test_alert_log_persists(self, db):
        log = models.OpsAlertLog(
            alert_key="P0_test",
            tier="P0",
            title="Test alert",
            body_json=json.dumps({"error_count": 15}),
            email_sent=True,
        )
        db.add(log)
        db.commit()

        loaded = db.query(models.OpsAlertLog).filter_by(alert_key="P0_test").first()
        assert loaded is not None
        assert loaded.tier == "P0"
        assert loaded.email_sent is True
        body = json.loads(loaded.body_json)
        assert body["error_count"] == 15


# ---------------------------------------------------------------------------
# 10. ops_metrics — AI call recording
# ---------------------------------------------------------------------------

class TestOpsMetricsAiRecording:
    def setup_method(self):
        with ops_metrics._ai_lock:
            ops_metrics._ai_key_stats.clear()
        with ops_metrics._ai_lock:
            ops_metrics._ai_fallback_events.clear()

    def test_record_ai_call_increments_requests(self):
        ops_metrics.record_ai_call(key_index=0, model="gemini-pro", fallback=False, latency_ms=200)
        ops_metrics.record_ai_call(key_index=0, model="gemini-pro", fallback=False, latency_ms=150)
        stats = ops_metrics.get_ai_key_stats()
        assert stats[0]["requests_today"] == 2

    def test_record_ai_call_tracks_fallback(self):
        ops_metrics.record_ai_call(key_index=1, model="deepseek-chat", fallback=True, latency_ms=300)
        stats = ops_metrics.get_ai_key_stats()
        assert stats[1]["fallbacks_today"] == 1

    def test_record_ai_call_tracks_429(self):
        ops_metrics.record_ai_call(key_index=0, model="gemini-pro", fallback=False, latency_ms=50, hit_429=True)
        stats = ops_metrics.get_ai_key_stats()
        assert stats[0]["last_429_at"] is not None

    def test_get_ai_fallback_rate_returns_zero_when_empty(self):
        rate = ops_metrics.get_ai_fallback_rate(1)
        assert rate == 0.0

    def test_record_scheduler_run_tracks_job(self):
        ops_metrics.record_scheduler_run("ops_p0_check", success=True)
        health = ops_metrics.get_scheduler_health()
        assert "ops_p0_check" in health
        assert health["ops_p0_check"]["success"] is True

    def test_record_memory_sample_stored(self):
        initial_len = len(ops_metrics._memory_samples)
        ops_metrics.record_memory_sample(512 * 1024 * 1024)
        assert len(ops_metrics._memory_samples) == initial_len + 1


# ---------------------------------------------------------------------------
# 11. ops_health — system resource checks (macOS-safe: fallback paths)
# ---------------------------------------------------------------------------

class TestOpsHealthSystemChecks:
    def test_check_memory_returns_dict_with_keys(self):
        import ops_health
        result = ops_health.check_memory()
        assert "memory_pct" in result
        assert "memory_rss_mb" in result
        assert "swap_active" in result
        assert isinstance(result["memory_pct"], float)

    def test_check_disk_returns_dict(self):
        import ops_health
        result = ops_health.check_disk()
        assert "disk_pct" in result
        assert 0.0 <= result["disk_pct"] <= 1.0

    def test_check_file_descriptors_returns_int(self):
        import ops_health
        result = ops_health.check_file_descriptors()
        assert isinstance(result, int)
        assert result >= 0

    def test_check_cpu_burst_credits_returns_bool(self):
        import ops_health
        result = ops_health.check_cpu_burst_credits()
        assert isinstance(result, bool)

    def test_check_db_health_returns_healthy(self, db):
        import ops_health
        result = ops_health.check_db_health(db)
        assert result["db_healthy"] is True
        assert "db_pool_used" in result
        assert "db_pool_size" in result

    def test_check_ai_health_returns_dict(self):
        import ops_health
        result = ops_health.check_ai_health()
        assert "gemini_healthy" in result
        assert "all_ai_keys_failed" in result
        assert "ai_fallback_rate_1h" in result

    def test_check_scheduler_health_true_when_no_jobs(self):
        import ops_health
        with patch.object(ops_metrics, "get_scheduler_health", return_value={}):
            result = ops_health.check_scheduler_health()
        assert result is True

    def test_check_db_slow_queries_returns_zero_when_extension_missing(self, db):
        import ops_health
        # pg_stat_statements not installed in test DB — should rollback and return 0
        result = ops_health.check_db_slow_queries(db)
        assert result == 0

    def test_check_db_slow_queries_returns_count_when_available(self, db):
        import ops_health
        from unittest.mock import MagicMock
        mock_result = MagicMock()
        mock_result.scalar.return_value = 3
        with patch.object(db, "execute", return_value=mock_result):
            result = ops_health.check_db_slow_queries(db)
        assert result == 3


# ---------------------------------------------------------------------------
# 12. fire_alert — full path (email sent + OpsAlertLog written)
# ---------------------------------------------------------------------------

class TestFireAlert:
    def _make_candidate(self, key="P0_test_fire", tier="P0"):
        return ops_alerting.AlertCandidate(
            alert_key=key, tier=tier, title="Test alert", body={"test": True}
        )

    def test_fire_alert_sends_email_and_logs(self, db):
        mock_svc = MagicMock()
        mock_svc.send_ops_alert_email.return_value = True

        candidate = self._make_candidate()
        result = ops_alerting.fire_alert(candidate, db, mock_svc)

        assert result is True
        mock_svc.send_ops_alert_email.assert_called_once()
        log = db.query(models.OpsAlertLog).filter_by(alert_key="P0_test_fire").first()
        assert log is not None
        assert log.email_sent is True

    def test_fire_alert_suppressed_does_not_send_email(self, db):
        # Pre-insert a recent alert to trigger suppression
        existing = models.OpsAlertLog(
            alert_key="P0_suppressed_key",
            tier="P0",
            title="Already fired",
            email_sent=True,
            email_sent_at=datetime.now(timezone.utc),
        )
        db.add(existing)
        db.commit()

        mock_svc = MagicMock()
        candidate = self._make_candidate(key="P0_suppressed_key")
        result = ops_alerting.fire_alert(candidate, db, mock_svc)

        assert result is False
        mock_svc.send_ops_alert_email.assert_not_called()

    def test_fire_p2_digest_sends_combined_email(self, db):
        mock_svc = MagicMock()
        mock_svc.send_ops_alert_email.return_value = True

        candidates = [
            ops_alerting.AlertCandidate("P2_a", "P2", "Issue A", {"count": 3}),
            ops_alerting.AlertCandidate("P2_b", "P2", "Issue B", {"count": 7}),
        ]
        result = ops_alerting.fire_p2_digest(candidates, db, mock_svc)
        assert result is True
        mock_svc.send_ops_alert_email.assert_called_once()

    def test_fire_p2_digest_empty_candidates_returns_false(self, db):
        mock_svc = MagicMock()
        result = ops_alerting.fire_p2_digest([], db, mock_svc)
        assert result is False
        mock_svc.send_ops_alert_email.assert_not_called()


# ---------------------------------------------------------------------------
# 13. evaluate_p1 — with flag enabled
# ---------------------------------------------------------------------------

class TestP1Evaluation:
    def _make_snap(self, **kwargs):
        defaults = dict(
            api_healthy=True, db_healthy=True, all_ai_keys_failed=False,
            memory_pct=0.5, swap_active=False, concurrent_requests=10,
            error_rate_5xx_5min=0, ai_fallback_rate_1h=0.0,
            critical_alerts_unacked_2h=0, cpu_burst_credits_low=False, disk_pct=0.5,
        )
        defaults.update(kwargs)
        return models.SystemHealthSnapshot(**defaults)

    def test_p1_disabled_by_default_returns_empty(self):
        snap = self._make_snap(error_rate_5xx_5min=20)
        candidates = ops_alerting.evaluate_p1(snap)
        assert candidates == []

    def test_p1_error_rate_fires_when_enabled(self):
        from config import settings
        snap = self._make_snap(error_rate_5xx_5min=20)
        with patch.object(settings, "OPS_P1_ALERTS_ENABLED", True):
            candidates = ops_alerting.evaluate_p1(snap)
        keys = [c.alert_key for c in candidates]
        assert "P1_error_rate_spike" in keys

    def test_p1_ai_fallback_fires_when_enabled(self):
        from config import settings
        snap = self._make_snap(ai_fallback_rate_1h=0.5)
        with patch.object(settings, "OPS_P1_ALERTS_ENABLED", True):
            candidates = ops_alerting.evaluate_p1(snap)
        keys = [c.alert_key for c in candidates]
        assert "P1_ai_fallback_spike" in keys
