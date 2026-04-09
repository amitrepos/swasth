"""Tests for chat endpoints — send, history, quota, rate limiting."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from unittest.mock import patch
from datetime import datetime, timedelta
import models


def _get_profile_id(db, user_id):
    access = db.query(models.ProfileAccess).filter_by(
        user_id=user_id, access_level="owner"
    ).first()
    return access.profile_id


class TestChatSend:
    """POST /api/chat/messages — send message, get AI response."""

    @patch("routes_chat.ai_service")
    def test_send_message_success(self, mock_ai, client, test_user, auth_headers, db):
        mock_ai.generate_health_insight.return_value = "Drink more water!"
        pid = _get_profile_id(db, test_user.id)

        resp = client.post("/api/chat/messages", json={
            "profile_id": pid,
            "message": "What should I eat for breakfast?",
        }, headers=auth_headers)

        assert resp.status_code == 200
        body = resp.json()
        assert body["ai_response"] == "Drink more water!"
        assert body["remaining_quota"] >= 0
        assert "created_at" in body

    @patch("routes_chat.ai_service")
    def test_message_stored_in_db(self, mock_ai, client, test_user, auth_headers, db):
        mock_ai.generate_health_insight.return_value = "Stay hydrated."
        pid = _get_profile_id(db, test_user.id)

        client.post("/api/chat/messages", json={
            "profile_id": pid,
            "message": "How much water?",
        }, headers=auth_headers)

        msg = db.query(models.ChatMessage).filter_by(profile_id=pid).first()
        assert msg is not None
        assert msg.user_message == "How much water?"
        assert msg.ai_response == "Stay hydrated."

    def test_empty_message_rejected(self, client, test_user, auth_headers, db):
        pid = _get_profile_id(db, test_user.id)
        resp = client.post("/api/chat/messages", json={
            "profile_id": pid,
            "message": "",
        }, headers=auth_headers)
        assert resp.status_code == 400

    def test_unauthenticated_rejected(self, client):
        resp = client.post("/api/chat/messages", json={
            "profile_id": 1,
            "message": "Hello",
        })
        assert resp.status_code in (401, 403)



class TestChatMessages:
    """GET /api/chat/messages — chat history."""

    @patch("routes_chat.ai_service")
    def test_get_messages(self, mock_ai, client, test_user, auth_headers, db):
        mock_ai.generate_health_insight.return_value = "Advice here."
        pid = _get_profile_id(db, test_user.id)

        # Send a message first
        client.post("/api/chat/messages", json={
            "profile_id": pid,
            "message": "My sugar is high",
        }, headers=auth_headers)

        # Get messages
        resp = client.get(f"/api/chat/messages?profile_id={pid}", headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert len(body["messages"]) >= 1
        assert body["messages"][0]["user_message"] == "My sugar is high"
        assert "quota" in body

    def test_get_messages_empty(self, client, test_user, auth_headers, db):
        pid = _get_profile_id(db, test_user.id)
        resp = client.get(f"/api/chat/messages?profile_id={pid}", headers=auth_headers)
        assert resp.status_code == 200
        assert resp.json()["messages"] == []

    def test_unauthenticated_rejected(self, client):
        resp = client.get("/api/chat/messages?profile_id=1")
        assert resp.status_code in (401, 403)


