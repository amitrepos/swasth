"""Backend tests for the meal_context field on glucose readings (NUO-127).

Covers the API contract added by migration 0010 + the schema validator:
  - happy path: each allowed enum value persists + roundtrips
  - rejected on invalid enum
  - last_glucose_meal_context surfaces on the dashboard endpoint
  - meal_context only persisted for glucose readings, not BP/weight
"""

from datetime import datetime

import models


URL = "/api/readings"
DASHBOARD_URL = "/api/readings/health-score"


def _owner_profile(db, user):
    return db.query(models.ProfileAccess).filter(
        models.ProfileAccess.user_id == user.id,
        models.ProfileAccess.access_level == "owner",
    ).first()


def _glucose_payload(profile_id, *, meal_context, value=110.0):
    return {
        "profile_id": profile_id,
        "reading_type": "glucose",
        "glucose_value": value,
        "glucose_unit": "mg/dL",
        "value_numeric": value,
        "unit_display": "mg/dL",
        "status_flag": "NORMAL",
        "meal_context": meal_context,
        "reading_timestamp": datetime.utcnow().isoformat(),
    }


class TestMealContextRoundtrip:
    """Each of the allowed enum values must persist and round-trip cleanly."""

    def test_fasting_roundtrip(self, client, test_user, auth_headers, db):
        profile = _owner_profile(db, test_user)
        resp = client.post(
            URL,
            json=_glucose_payload(profile.profile_id, meal_context="fasting"),
            headers=auth_headers,
        )
        assert resp.status_code == 201
        assert resp.json()["meal_context"] == "fasting"

    def test_post_meal_roundtrip(self, client, test_user, auth_headers, db):
        profile = _owner_profile(db, test_user)
        resp = client.post(
            URL,
            json=_glucose_payload(profile.profile_id, meal_context="post_meal"),
            headers=auth_headers,
        )
        assert resp.status_code == 201
        assert resp.json()["meal_context"] == "post_meal"

    def test_before_meal_random_unknown(self, client, test_user, auth_headers, db):
        profile = _owner_profile(db, test_user)
        for ctx in ("before_meal", "random", "unknown"):
            resp = client.post(
                URL,
                json=_glucose_payload(profile.profile_id, meal_context=ctx),
                headers=auth_headers,
            )
            assert resp.status_code == 201, f"{ctx} should be accepted"
            assert resp.json()["meal_context"] == ctx


class TestMealContextValidation:

    def test_rejects_unknown_enum_value(self, client, test_user, auth_headers, db):
        profile = _owner_profile(db, test_user)
        resp = client.post(
            URL,
            json=_glucose_payload(profile.profile_id, meal_context="lunchtime"),
            headers=auth_headers,
        )
        assert resp.status_code == 422
        # The validator message should mention the field.
        assert "meal_context" in resp.text.lower()

    def test_missing_meal_context_allowed(self, client, test_user, auth_headers, db):
        """meal_context is optional — old clients shouldn't break."""
        profile = _owner_profile(db, test_user)
        payload = _glucose_payload(profile.profile_id, meal_context="fasting")
        payload.pop("meal_context")
        resp = client.post(URL, json=payload, headers=auth_headers)
        assert resp.status_code == 201
        # Optional → not present is fine, but if returned should be null.
        assert resp.json().get("meal_context") in (None, "")


class TestMealContextBpReading:

    def test_bp_reading_does_not_persist_meal_context(
        self, client, test_user, auth_headers, db,
    ):
        """meal_context is glucose-only; BP/weight reading payloads with the
        field set should NOT persist it (defensive)."""
        profile = _owner_profile(db, test_user)
        resp = client.post(
            URL,
            json={
                "profile_id": profile.profile_id,
                "reading_type": "blood_pressure",
                "systolic": 120.0,
                "diastolic": 80.0,
                "bp_unit": "mmHg",
                "bp_status": "NORMAL",
                "value_numeric": 120.0,
                "unit_display": "mmHg",
                "status_flag": "NORMAL",
                "meal_context": "fasting",  # should be ignored
                "reading_timestamp": datetime.utcnow().isoformat(),
            },
            headers=auth_headers,
        )
        assert resp.status_code == 201
        # Server-side route strips meal_context for non-glucose readings.
        assert resp.json().get("meal_context") in (None, "")


class TestDashboardSurfacesMealContext:

    def test_health_score_returns_last_glucose_meal_context(
        self, client, test_user, auth_headers, db,
    ):
        profile = _owner_profile(db, test_user)
        client.post(
            URL,
            json=_glucose_payload(profile.profile_id, meal_context="post_meal"),
            headers=auth_headers,
        )
        resp = client.get(
            DASHBOARD_URL,
            params={"profile_id": profile.profile_id},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        assert resp.json()["last_glucose_meal_context"] == "post_meal"
