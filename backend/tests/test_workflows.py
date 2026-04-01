"""End-to-end workflow tests — multi-step flows that simulate real user journeys.

These tests catch regressions in flows that span multiple endpoints,
like: register → save reading → check health score → view trend summary.
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from datetime import datetime, timedelta
from unittest.mock import patch
from tests.conftest import TEST_USER_EMAIL, TEST_USER_PASSWORD
import models


class TestNewUserOnboarding:
    """Register → first reading → health score → AI insight."""

    def test_full_onboarding_flow(self, client, db):
        # 1. Register
        reg = client.post("/api/auth/register", json={
            "email": "newflow@test.com",
            "password": "Flow@1234",
            "confirm_password": "Flow@1234",
            "full_name": "Flow User",
            "phone_number": "9876500088",
        })
        assert reg.status_code == 201

        # 2. Login
        login = client.post("/api/auth/login", json={
            "email": "newflow@test.com",
            "password": "Flow@1234",
        })
        assert login.status_code == 200
        token = login.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        # 3. Get profiles (should have default "My Health")
        profiles = client.get("/api/profiles", headers=headers)
        assert profiles.status_code == 200
        assert len(profiles.json()) >= 1
        profile_id = profiles.json()[0]["id"]

        # 4. Save first glucose reading
        reading = client.post("/api/readings", json={
            "profile_id": profile_id,
            "reading_type": "glucose",
            "glucose_value": 120.0,
            "glucose_unit": "mg/dL",
            "value_numeric": 120.0,
            "unit_display": "mg/dL",
            "status_flag": "NORMAL",
            "reading_timestamp": datetime.utcnow().isoformat(),
        }, headers=headers)
        assert reading.status_code == 201

        # 5. Health score should reflect the new reading
        score = client.get(f"/api/readings/health-score?profile_id={profile_id}", headers=headers)
        assert score.status_code == 200
        assert score.json()["score"] >= 50
        assert score.json()["today_glucose_status"] == "NORMAL"

        # 6. AI insight should work
        insight = client.get(f"/api/readings/ai-insight?profile_id={profile_id}", headers=headers)
        assert insight.status_code == 200
        assert "insight" in insight.json()
        assert len(insight.json()["insight"]) > 0

        # 7. Trend summary should work
        trend = client.get(f"/api/readings/trend-summary?profile_id={profile_id}&period=7", headers=headers)
        assert trend.status_code == 200
        assert "summary" in trend.json()

        # 8. Family streaks should include this profile
        streaks = client.get("/api/readings/family-streaks", headers=headers)
        assert streaks.status_code == 200
        profile_ids = [e["profile_id"] for e in streaks.json()["leaderboard"]]
        assert profile_id in profile_ids


class TestCriticalReadingAlertFlow:
    """Save critical reading → verify alert returned → verify reading in history."""

    def test_critical_glucose_triggers_alert(self, client, test_user, auth_headers, db):
        profile_id = db.query(models.ProfileAccess).filter(
            models.ProfileAccess.user_id == test_user.id,
            models.ProfileAccess.access_level == "owner",
        ).first().profile_id

        # Save critical reading
        resp = client.post("/api/readings", json={
            "profile_id": profile_id,
            "reading_type": "glucose",
            "glucose_value": 350.0,
            "glucose_unit": "mg/dL",
            "value_numeric": 350.0,
            "unit_display": "mg/dL",
            "status_flag": "CRITICAL",
            "reading_timestamp": datetime.utcnow().isoformat(),
        }, headers=auth_headers)
        assert resp.status_code == 201
        body = resp.json()

        # Alert should be present
        assert "alert" in body
        assert body["alert"]["level"] == "CRITICAL"
        assert "350" in body["alert"]["message"]

        # Reading should appear in history
        readings = client.get(f"/api/readings?profile_id={profile_id}", headers=auth_headers)
        assert readings.status_code == 200
        assert any(r["glucose_value"] == 350.0 for r in readings.json())

    def test_normal_reading_no_alert(self, client, test_user, auth_headers, db):
        profile_id = db.query(models.ProfileAccess).filter(
            models.ProfileAccess.user_id == test_user.id,
            models.ProfileAccess.access_level == "owner",
        ).first().profile_id

        resp = client.post("/api/readings", json={
            "profile_id": profile_id,
            "reading_type": "glucose",
            "glucose_value": 100.0,
            "glucose_unit": "mg/dL",
            "value_numeric": 100.0,
            "unit_display": "mg/dL",
            "status_flag": "NORMAL",
            "reading_timestamp": datetime.utcnow().isoformat(),
        }, headers=auth_headers)
        assert resp.status_code == 201
        assert "alert" not in resp.json() or resp.json().get("alert") is None


class TestProfileSharingFlow:
    """Create profile → invite family → accept → viewer sees data."""

    @patch("routes_profiles.email_service.send_profile_invite_email")
    def test_share_and_view_flow(self, mock_email, client, db):
        from auth import get_password_hash, create_access_token

        # 1. Owner registers and creates profile
        owner = models.User(
            email="owner_flow@test.com",
            password_hash=get_password_hash("Own@1234"),
            full_name="Owner",
            phone_number="9876500077",
        )
        db.add(owner)
        db.flush()
        owner_token = create_access_token(data={"sub": owner.email})
        owner_headers = {"Authorization": f"Bearer {owner_token}"}

        # Create profile
        profile = client.post("/api/profiles", json={
            "name": "Dad Health",
            "age": 65,
        }, headers=owner_headers)
        assert profile.status_code == 201
        profile_id = profile.json()["id"]

        # Add reading
        client.post("/api/readings", json={
            "profile_id": profile_id,
            "reading_type": "glucose",
            "glucose_value": 180.0,
            "value_numeric": 180.0,
            "unit_display": "mg/dL",
            "status_flag": "HIGH",
            "reading_timestamp": datetime.utcnow().isoformat(),
        }, headers=owner_headers)

        # 2. Viewer registers
        viewer = models.User(
            email="viewer_flow@test.com",
            password_hash=get_password_hash("View@1234"),
            full_name="Viewer",
            phone_number="9876500078",
        )
        db.add(viewer)
        db.flush()
        viewer_token = create_access_token(data={"sub": viewer.email})
        viewer_headers = {"Authorization": f"Bearer {viewer_token}"}

        # 3. Owner invites viewer
        invite = client.post(f"/api/profiles/{profile_id}/invite", json={
            "email": "viewer_flow@test.com",
            "relationship": "son",
            "access_level": "viewer",
        }, headers=owner_headers)
        assert invite.status_code == 201
        invite_id = invite.json()["invite_id"]

        # 4. Viewer accepts invite
        accept = client.post(f"/api/invites/{invite_id}/respond", json={
            "action": "accept",
        }, headers=viewer_headers)
        assert accept.status_code == 200

        # 5. Viewer can see the profile
        profiles = client.get("/api/profiles", headers=viewer_headers)
        profile_ids = [p["id"] for p in profiles.json()]
        assert profile_id in profile_ids

        # 6. Viewer can see readings
        readings = client.get(f"/api/readings?profile_id={profile_id}", headers=viewer_headers)
        assert readings.status_code == 200
        assert len(readings.json()) >= 1

        # 7. Viewer can see health score
        score = client.get(f"/api/readings/health-score?profile_id={profile_id}", headers=viewer_headers)
        assert score.status_code == 200

        # 8. Viewer can see trend summary
        trend = client.get(f"/api/readings/trend-summary?profile_id={profile_id}&period=7", headers=viewer_headers)
        assert trend.status_code == 200

        # 9. Viewer can see family streaks (should include shared profile)
        streaks = client.get("/api/readings/family-streaks", headers=viewer_headers)
        assert profile_id in [e["profile_id"] for e in streaks.json()["leaderboard"]]

        # 10. Viewer CANNOT save readings (viewer, not editor)
        save_attempt = client.post("/api/readings", json={
            "profile_id": profile_id,
            "reading_type": "glucose",
            "glucose_value": 100.0,
            "value_numeric": 100.0,
            "unit_display": "mg/dL",
            "status_flag": "NORMAL",
            "reading_timestamp": datetime.utcnow().isoformat(),
        }, headers=viewer_headers)
        assert save_attempt.status_code == 403


class TestStreakAndPointsFlow:
    """Log readings over multiple days → verify streak + points."""

    def test_streak_builds_over_days(self, client, test_user, auth_headers, db):
        profile_id = db.query(models.ProfileAccess).filter(
            models.ProfileAccess.user_id == test_user.id,
            models.ProfileAccess.access_level == "owner",
        ).first().profile_id

        # Log readings for 3 consecutive days
        for days_ago in range(2, -1, -1):
            ts = (datetime.utcnow() - timedelta(days=days_ago)).isoformat()
            client.post("/api/readings", json={
                "profile_id": profile_id,
                "reading_type": "glucose",
                "glucose_value": 110.0,
                "value_numeric": 110.0,
                "unit_display": "mg/dL",
                "status_flag": "NORMAL",
                "reading_timestamp": ts,
            }, headers=auth_headers)

        # Check streak
        streaks = client.get("/api/readings/family-streaks", headers=auth_headers)
        my_entry = next(e for e in streaks.json()["leaderboard"] if e["profile_id"] == profile_id)
        assert my_entry["streak_days"] >= 3
        assert my_entry["points"] >= 30  # at least 3 readings × 10 pts
        assert my_entry["total_readings"] >= 3

        # Weekly activity should show readings
        logged_days = sum(1 for d in my_entry["week_activity"] if d["has_reading"])
        assert logged_days >= 1


class TestChatFlow:
    """Send message → get AI response → check history."""

    @patch("ai_service.generate_health_insight", return_value="Stay hydrated.")
    def test_chat_roundtrip(self, mock_ai, client, test_user, auth_headers, db):
        profile_id = db.query(models.ProfileAccess).filter(
            models.ProfileAccess.user_id == test_user.id,
            models.ProfileAccess.access_level == "owner",
        ).first().profile_id

        # 1. Check quota first
        quota = client.get(f"/api/chat/quota?profile_id={profile_id}", headers=auth_headers)
        assert quota.status_code == 200
        remaining = quota.json()["remaining"]
        assert remaining > 0

        # 2. Send message
        send = client.post("/api/chat/send", json={
            "profile_id": profile_id,
            "message": "How is my health?",
        }, headers=auth_headers)
        assert send.status_code == 200
        assert "ai_response" in send.json()
        assert len(send.json()["ai_response"]) > 0

        # 3. Message appears in history
        history = client.get(f"/api/chat/messages?profile_id={profile_id}", headers=auth_headers)
        assert history.status_code == 200
        messages = history.json()["messages"]
        assert any(m["user_message"] == "How is my health?" for m in messages)

        # 4. Quota decreased
        quota2 = client.get(f"/api/chat/quota?profile_id={profile_id}", headers=auth_headers)
        assert quota2.json()["remaining"] == remaining - 1
