"""Tests for jira_ops — auto-ticketing from P0 ops alerts.

Network is always mocked. Invariants under test:
  - creates a new ticket when none open
  - comments (no duplicate) when an open ticket exists for the alert_key
  - respects the JIRA_OPS_ENABLED / missing-creds kill switch
  - NEVER raises on JIRA failure (alerting must survive JIRA down)
  - fire_alert opens a ticket for P0 only, not P1/P2
"""

import sys, os
from unittest.mock import MagicMock, patch

import pytest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import jira_ops
import ops_alerting
from config import settings


@pytest.fixture()
def jira_enabled(monkeypatch):
    monkeypatch.setattr(settings, "JIRA_OPS_ENABLED", True)
    monkeypatch.setattr(settings, "JIRA_URL", "https://example.atlassian.net")
    monkeypatch.setattr(settings, "JIRA_EMAIL", "ops@swasth.health")
    monkeypatch.setattr(settings, "JIRA_API_TOKEN", "token123")
    monkeypatch.setattr(settings, "JIRA_OPS_PROJECT_KEY", "SWAS")
    monkeypatch.setattr(settings, "JIRA_OPS_ISSUE_TYPE", "Bug")


class TestCreateOrUpdateTicket:
    def test_creates_new_ticket_when_none_open(self, jira_enabled):
        with patch.object(jira_ops, "_find_open_issue", return_value=None), \
             patch.object(jira_ops, "_create_issue", return_value="SWAS-1") as mk_create, \
             patch.object(jira_ops, "_comment") as mk_comment:
            key = jira_ops.create_or_update_ticket("P0_db_down", "P0", "Database unreachable", {"db_healthy": False})
        assert key == "SWAS-1"
        mk_create.assert_called_once()
        mk_comment.assert_not_called()

    def test_comments_when_open_ticket_exists(self, jira_enabled):
        with patch.object(jira_ops, "_find_open_issue", return_value="SWAS-7"), \
             patch.object(jira_ops, "_create_issue") as mk_create, \
             patch.object(jira_ops, "_comment") as mk_comment:
            key = jira_ops.create_or_update_ticket("P0_db_down", "P0", "Database unreachable", {})
        assert key == "SWAS-7"
        mk_comment.assert_called_once()
        mk_create.assert_not_called()  # no duplicate

    def test_disabled_returns_none_and_makes_no_calls(self, monkeypatch):
        monkeypatch.setattr(settings, "JIRA_OPS_ENABLED", False)
        with patch.object(jira_ops, "_find_open_issue") as mk_find:
            key = jira_ops.create_or_update_ticket("P0_db_down", "P0", "x", {})
        assert key is None
        mk_find.assert_not_called()

    def test_missing_creds_disables(self, monkeypatch):
        monkeypatch.setattr(settings, "JIRA_OPS_ENABLED", True)
        monkeypatch.setattr(settings, "JIRA_API_TOKEN", "")  # no token
        assert jira_ops.create_or_update_ticket("P0_db_down", "P0", "x", {}) is None

    def test_never_raises_on_jira_failure(self, jira_enabled):
        with patch.object(jira_ops, "_find_open_issue", side_effect=RuntimeError("JIRA 500")):
            # must swallow and return None, not propagate
            key = jira_ops.create_or_update_ticket("P0_db_down", "P0", "x", {})
        assert key is None


class TestRequestShape:
    """MEDIUM-1: the HTTP helpers are patched out elsewhere, so assert the
    actual request URL/JQL/payload shape against mocked `requests` here."""

    def test_create_issue_builds_correct_payload(self, jira_enabled):
        captured = {}

        def fake_post(url, json=None, auth=None, timeout=None):
            captured["url"] = url
            captured["json"] = json
            r = MagicMock(); r.raise_for_status = MagicMock(); r.json = lambda: {"key": "SWAS-42"}
            return r

        with patch.object(jira_ops, "_find_open_issue", return_value=None), \
             patch("jira_ops.requests.post", side_effect=fake_post):
            key = jira_ops.create_or_update_ticket("P0_db_down", "P0", "Database unreachable", {"db_healthy": False})

        assert key == "SWAS-42"
        assert captured["url"].endswith("/rest/api/3/issue")
        fields = captured["json"]["fields"]
        assert fields["project"]["key"] == "SWAS"
        assert fields["issuetype"]["name"] == "Bug"
        assert "ops-alert" in fields["labels"]
        assert "ops-alert-P0_db_down" in fields["labels"]
        assert fields["summary"].startswith("[P0]")

    def test_create_returns_none_on_malformed_200(self, jira_enabled):
        """Priya MEDIUM: a 200 with no 'key' must not crash — swallow → None."""
        def fake_post(url, json=None, auth=None, timeout=None):
            r = MagicMock(); r.raise_for_status = MagicMock(); r.json = lambda: {}  # no "key"
            return r
        with patch.object(jira_ops, "_find_open_issue", return_value=None), \
             patch("jira_ops.requests.post", side_effect=fake_post):
            key = jira_ops.create_or_update_ticket("P0_db_down", "P0", "x", {})
        assert key is None

    def test_find_open_issue_jql_targets_project_and_label(self, jira_enabled):
        captured = {}

        def fake_get(url, params=None, auth=None, timeout=None):
            captured["url"] = url
            captured["params"] = params
            r = MagicMock(); r.raise_for_status = MagicMock(); r.json = lambda: {"issues": []}
            return r

        with patch("jira_ops.requests.get", side_effect=fake_get):
            res = jira_ops._find_open_issue("ops-alert-P0_db_down")

        assert res is None
        assert captured["url"].endswith("/rest/api/3/search/jql")
        jql = captured["params"]["jql"]
        assert 'project = "SWAS"' in jql
        assert 'labels = "ops-alert-P0_db_down"' in jql
        assert "statusCategory != Done" in jql

    def test_label_sanitizes_unsafe_chars(self):
        # A hostile/typo alert_key must not leak quotes/spaces into JQL.
        assert jira_ops._label('P0"; DROP') == "ops-alert-P0___DROP"
        assert '"' not in jira_ops._label('P0"; DROP')
        assert " " not in jira_ops._label("P0 spaced key")
        assert jira_ops._label("P0_db_down") == "ops-alert-P0_db_down"  # normal unchanged


class TestFireAlertTriggersJira:
    def _candidate(self, tier, key):
        return ops_alerting.AlertCandidate(alert_key=key, tier=tier, title="t", body={})

    def test_p0_opens_ticket(self, db, jira_enabled):
        svc = MagicMock(); svc.send_ops_alert_email.return_value = True
        with patch.object(jira_ops, "create_or_update_ticket", return_value="SWAS-9") as mk:
            ops_alerting.fire_alert(self._candidate("P0", "P0_db_down"), db, svc)
        mk.assert_called_once()

    def test_p1_does_not_open_ticket(self, db, jira_enabled):
        svc = MagicMock(); svc.send_ops_alert_email.return_value = True
        with patch.object(jira_ops, "create_or_update_ticket") as mk:
            ops_alerting.fire_alert(self._candidate("P1", "P1_disk_high"), db, svc)
        mk.assert_not_called()

    def test_email_and_log_survive_jira_raising(self, db, jira_enabled):
        """Priya CRITICAL: jira_ops is *supposed* to never raise, but fire_alert
        wraps it in a second try/except as the net. If that net ever matters,
        the email must still send and the OpsAlertLog row must still commit.
        Force create_or_update_ticket to RAISE and assert the alert path holds."""
        import models
        svc = MagicMock(); svc.send_ops_alert_email.return_value = True
        with patch.object(jira_ops, "create_or_update_ticket", side_effect=RuntimeError("JIRA exploded")):
            email_sent = ops_alerting.fire_alert(self._candidate("P0", "P0_db_down"), db, svc)
        assert email_sent is True, "email must still send when JIRA raises"
        row = db.query(models.OpsAlertLog).filter_by(alert_key="P0_db_down").first()
        assert row is not None and row.email_sent is True, "log must still commit"
