"""Extended chat tests — covers context summarization and multi-turn conversation."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from unittest.mock import patch, MagicMock
from datetime import datetime, date, timedelta
from tests.conftest import TEST_USER_EMAIL
import models
from config import settings


def _get_profile_id(db, user_id):
    access = db.query(models.ProfileAccess).filter(
        models.ProfileAccess.user_id == user_id,
        models.ProfileAccess.access_level == "owner",
    ).first()
    return access.profile_id


def _add_chat_messages(db, profile_id, user_id, count=3):
    for i in range(count):
        msg = models.ChatMessage(
            profile_id=profile_id,
            user_id=user_id,
            user_message=f"Question {i+1}",
            ai_response=f"Answer {i+1}",
            model_used="test",
            latency_ms=100,
        )
        db.add(msg)
    db.flush()


class TestChatContextSummarization:

    @patch("ai_service.generate_health_insight", return_value="Patient summary.")
    def test_context_profile_created_after_interval(self, mock_ai, client, test_user, auth_headers, db):
        """After CHAT_SUMMARY_INTERVAL messages, the context profile row must
        be written. Asserts the DB row directly so silent write failures can't
        slip past."""
        pid = _get_profile_id(db, test_user.id)
        interval = settings.CHAT_SUMMARY_INTERVAL

        # Pre-seed N-1 messages so the next POST is the Nth → trigger fires
        _add_chat_messages(db, pid, test_user.id, count=interval - 1)

        with patch("routes_chat.ai_service.generate_health_insight", return_value="Summary text."):
            resp = client.post("/api/chat/messages", json={
                "profile_id": pid,
                "message": "Trigger summary",
            }, headers=auth_headers)
        assert resp.status_code == 200

        ctx = db.query(models.ChatContextProfile).filter(
            models.ChatContextProfile.profile_id == pid,
        ).first()
        assert ctx is not None, "ChatContextProfile row missing — AI memory not written"
        assert ctx.summary == "Summary text."
        assert ctx.message_count >= interval

    @patch("ai_service.generate_health_insight", return_value="AI response.")
    def test_context_profile_logs_when_summary_fails(self, mock_ai, client, test_user, auth_headers, db, caplog):
        """If the summary update raises, the trigger site must log via
        logger.exception — must NOT swallow silently. The chat itself
        still succeeds because summary generation is a non-critical
        side-effect."""
        import logging
        pid = _get_profile_id(db, test_user.id)
        _add_chat_messages(db, pid, test_user.id, count=settings.CHAT_SUMMARY_INTERVAL - 1)

        with caplog.at_level(logging.ERROR, logger="routes_chat"):
            with patch("routes_chat._update_context_profile",
                       side_effect=RuntimeError("simulated summary outage")):
                resp = client.post("/api/chat/messages", json={
                    "profile_id": pid,
                    "message": "Trigger summary",
                }, headers=auth_headers)
        assert resp.status_code == 200, (
            "chat must still succeed even when summary fails (non-critical side-effect)"
        )
        assert any("ai_memory" in r.message and "_update_context_profile failed" in r.message
                   for r in caplog.records), (
            "expected logger.exception when summary update raises"
        )

    @patch("ai_service.generate_health_insight", return_value="AI response here.")
    def test_chat_with_health_data_context(self, mock_ai, client, test_user, auth_headers, db):
        """Chat should include health data in the AI prompt."""
        pid = _get_profile_id(db, test_user.id)

        # Add some health readings
        reading = models.HealthReading(
            profile_id=pid,
            logged_by=test_user.id,
            reading_type="glucose",
            glucose_value=200.0,
            value_numeric=200.0,
            unit_display="mg/dL",
            status_flag="HIGH",
            reading_timestamp=datetime.utcnow(),
        )
        db.add(reading)
        db.flush()

        resp = client.post("/api/chat/messages", json={
            "profile_id": pid,
            "message": "How is my glucose?",
        }, headers=auth_headers)
        assert resp.status_code == 200
        assert "ai_response" in resp.json()

    @patch("ai_service.generate_health_insight", return_value=None)
    def test_chat_ai_unavailable_returns_fallback(self, mock_ai, client, test_user, auth_headers, db):
        """When AI is unavailable, should return a friendly fallback message."""
        pid = _get_profile_id(db, test_user.id)
        resp = client.post("/api/chat/messages", json={
            "profile_id": pid,
            "message": "Hello",
        }, headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert "trouble connecting" in body["ai_response"].lower() or len(body["ai_response"]) > 0


class TestChatQuotaPeriods:

    def test_quota_resets_daily(self, db):
        from routes_chat import _period_start, _period_end
        start = _period_start()
        end = _period_end()
        assert start.date() == date.today()
        assert end.date() == date.today() + timedelta(days=1)


class TestChatHistory:

    @patch("ai_service.generate_health_insight", return_value="Test response.")
    def test_messages_returned_in_order(self, mock_ai, client, test_user, auth_headers, db):
        pid = _get_profile_id(db, test_user.id)

        # Send two messages
        client.post("/api/chat/messages", json={"profile_id": pid, "message": "First"}, headers=auth_headers)
        client.post("/api/chat/messages", json={"profile_id": pid, "message": "Second"}, headers=auth_headers)

        resp = client.get("/api/chat/messages", params={"profile_id": pid}, headers=auth_headers)
        assert resp.status_code == 200
        messages = resp.json()["messages"]
        assert len(messages) >= 2
        # Should be in ascending order
        assert messages[0]["user_message"] == "First"

    def test_messages_include_quota(self, client, test_user, auth_headers, db):
        pid = _get_profile_id(db, test_user.id)
        resp = client.get("/api/chat/messages", params={"profile_id": pid}, headers=auth_headers)
        assert resp.status_code == 200
        assert "quota" in resp.json()


class TestChatAccessControl:

    def test_viewer_cannot_send_message(self, client, test_user, auth_headers, db):
        """Viewers should not be able to send chat messages."""
        from auth import get_password_hash, create_access_token

        # Create viewer
        viewer = models.User(
            email="chatviewer@test.com",
            password_hash=get_password_hash("View@1234"),
            full_name="Chat Viewer",
            phone_number="9876500098",
        )
        db.add(viewer)
        db.flush()

        pid = _get_profile_id(db, test_user.id)
        db.add(models.ProfileAccess(user_id=viewer.id, profile_id=pid, access_level="viewer"))
        db.flush()

        viewer_headers = {"Authorization": f"Bearer {create_access_token(data={'sub': viewer.email})}"}
        resp = client.post("/api/chat/messages", json={
            "profile_id": pid,
            "message": "Should be blocked",
        }, headers=viewer_headers)
        assert resp.status_code == 403
