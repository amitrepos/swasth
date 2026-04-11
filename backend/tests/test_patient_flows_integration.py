"""End-to-end integration tests for patient-side workflows.

Each test drives the app through a complete logical flow as a real
user would — composing multiple endpoints so that schema/shape/permission
mismatches that pass their own unit test still fail here.

Covers the gaps identified in the 2026-04-11 coverage audit:
  1. Meal logging — create → list → history → filter by day range
  2. Health score — seed readings → compute → vital summary + trend
  3. Multi-profile scoping — 3 profiles, readings stay per-profile
  4. Account deletion cascade — DPDPA right-to-erasure fully purges data
  5. History pagination + filtering — large list, limit/offset/type
"""
from datetime import datetime, timezone, timedelta

import pytest

import models
from auth import get_password_hash, create_access_token


# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------


def _make_user(db, email, name="Test Patient"):
    user = models.User(
        email=email,
        password_hash=get_password_hash("Strong@123"),
        full_name=name,
        phone_number="9" + str(abs(hash(email)))[:9],
    )
    db.add(user)
    db.flush()
    return user


def _make_profile(db, user, name):
    profile = models.Profile(name=name, age=40, gender="Male", height=170, weight=72)
    db.add(profile)
    db.flush()
    db.add(models.ProfileAccess(user_id=user.id, profile_id=profile.id, access_level="owner"))
    db.flush()
    return profile


def _headers(user):
    return {"Authorization": f"Bearer {create_access_token(data={'sub': user.email})}"}


def _reading_payload(profile_id, *, kind="glucose", value=110, ts=None, status="NORMAL"):
    ts = ts or datetime.now(timezone.utc)
    base = {
        "profile_id": profile_id,
        "reading_type": kind,
        "value_numeric": float(value),
        "unit_display": "mg/dL" if kind == "glucose" else "mmHg",
        "status_flag": status,
        "reading_timestamp": ts.isoformat(),
    }
    if kind == "glucose":
        base.update({"glucose_value": float(value), "glucose_unit": "mg/dL", "sample_type": "fasting"})
    elif kind == "blood_pressure":
        sys_v, dia = (int(value), 85)
        base.update({
            "systolic": float(sys_v),
            "diastolic": float(dia),
            "bp_unit": "mmHg",
            "unit_display": "mmHg",
            "value_numeric": float(sys_v),
        })
    return base


# ---------------------------------------------------------------------------
# 1. Meal logging workflow
# ---------------------------------------------------------------------------


class TestMealLoggingFlow:
    def test_log_list_and_delete_roundtrip(self, client, db):
        user = _make_user(db, "meal@test.com")
        profile = _make_profile(db, user, "Meal Profile")
        headers = _headers(user)

        now = datetime.now(timezone.utc)

        # Log breakfast (quick select)
        resp = client.post(
            "/api/meals",
            headers=headers,
            json={
                "profile_id": profile.id,
                "category": "HIGH_CARB",
                "glucose_impact": "HIGH",
                "meal_type": "BREAKFAST",
                "input_method": "QUICK_SELECT",
                "timestamp": now.isoformat(),
                "tip_en": "Try pairing rice with more veg.",
                "tip_hi": "चावल के साथ ज़्यादा सब्ज़ियाँ खाएँ।",
                "user_confirmed": True,
            },
        )
        assert resp.status_code == 201, resp.text
        meal_id = resp.json()["id"]
        assert resp.json()["category"] == "HIGH_CARB"

        # Log a second meal (lunch) from "photo" path
        resp2 = client.post(
            "/api/meals",
            headers=headers,
            json={
                "profile_id": profile.id,
                "category": "LOW_CARB",
                "glucose_impact": "LOW",
                "meal_type": "LUNCH",
                "input_method": "PHOTO_GEMINI",
                "timestamp": now.isoformat(),
                "confidence": 0.82,
                "user_confirmed": True,
            },
        )
        assert resp2.status_code == 201, resp2.text

        # List all meals — both visible
        listing = client.get(
            f"/api/meals?profile_id={profile.id}&days=7", headers=headers
        )
        assert listing.status_code == 200
        body = listing.json()
        assert len(body) == 2
        categories = sorted(m["category"] for m in body)
        assert categories == ["HIGH_CARB", "LOW_CARB"]

        # Delete one, confirm list shrinks
        delete = client.delete(f"/api/meals/{meal_id}", headers=headers)
        assert delete.status_code == 204
        after = client.get(
            f"/api/meals?profile_id={profile.id}&days=7", headers=headers
        )
        assert len(after.json()) == 1
        assert after.json()[0]["category"] == "LOW_CARB"

    def test_meal_invalid_category_rejected(self, client, db):
        user = _make_user(db, "mealinv@test.com")
        profile = _make_profile(db, user, "P")
        resp = client.post(
            "/api/meals",
            headers=_headers(user),
            json={
                "profile_id": profile.id,
                "category": "JUNK",  # not in enum
                "glucose_impact": "LOW",
                "meal_type": "SNACK",
                "input_method": "QUICK_SELECT",
                "timestamp": datetime.now(timezone.utc).isoformat(),
            },
        )
        assert resp.status_code == 422

    def test_meal_on_other_users_profile_denied(self, client, db):
        owner = _make_user(db, "owner@test.com")
        profile = _make_profile(db, owner, "Owner's")
        attacker = _make_user(db, "attacker@test.com")

        resp = client.post(
            "/api/meals",
            headers=_headers(attacker),
            json={
                "profile_id": profile.id,
                "category": "LOW_CARB",
                "glucose_impact": "LOW",
                "meal_type": "DINNER",
                "input_method": "QUICK_SELECT",
                "timestamp": datetime.now(timezone.utc).isoformat(),
            },
        )
        assert resp.status_code == 403


# ---------------------------------------------------------------------------
# 2. Health score workflow
# ---------------------------------------------------------------------------


class TestHealthScoreFlow:
    def test_health_score_with_seeded_readings(self, client, db):
        """Seed 7 days of glucose + BP → health-score endpoint returns
        a valid score, computes streak + averages + today's values."""
        user = _make_user(db, "score@test.com")
        profile = _make_profile(db, user, "Score Profile")
        headers = _headers(user)

        now = datetime.now(timezone.utc)

        # Log one glucose + one BP per day for 7 days (today-inclusive)
        for days_back in range(7):
            ts = now - timedelta(days=days_back)
            r = client.post(
                "/api/readings",
                headers=headers,
                json=_reading_payload(
                    profile.id, kind="glucose", value=100 + days_back, ts=ts, status="NORMAL"
                ),
            )
            assert r.status_code == 201, r.text
            r = client.post(
                "/api/readings",
                headers=headers,
                json=_reading_payload(
                    profile.id, kind="blood_pressure", value=120 + days_back, ts=ts, status="NORMAL"
                ),
            )
            assert r.status_code == 201, r.text

        # Fetch health score
        resp = client.get(
            f"/api/readings/health-score?profile_id={profile.id}", headers=headers
        )
        assert resp.status_code == 200, resp.text
        body = resp.json()

        # Basic score shape
        assert 0 <= body["score"] <= 100
        assert body["color"] in ("green", "orange", "red")
        assert body["streak_days"] >= 1
        assert body["profile_name"] == "Score Profile"

        # Today's values should be populated (we logged one today)
        assert body["today_glucose_value"] == 100.0
        assert body["today_bp_systolic"] == 120.0

        # 90-day averages should exist with 7 data-days counted
        assert body["avg_glucose_90d"] is not None
        assert body["glucose_data_days"] == 7
        assert body["bp_data_days"] == 7

    def test_health_score_empty_profile(self, client, db):
        """A brand new profile with zero readings must still return
        a usable HealthScoreResponse (not 500)."""
        user = _make_user(db, "empty@test.com")
        profile = _make_profile(db, user, "Empty")

        resp = client.get(
            f"/api/readings/health-score?profile_id={profile.id}",
            headers=_headers(user),
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["streak_days"] == 0
        assert body["today_glucose_value"] is None
        assert body["today_bp_systolic"] is None


# ---------------------------------------------------------------------------
# 3. Multi-profile scoping
# ---------------------------------------------------------------------------


class TestMultiProfileScoping:
    def test_readings_stay_scoped_per_profile(self, client, db):
        """One user with 3 profiles logs different data on each —
        listings, health-score, and family-streaks must stay scoped."""
        user = _make_user(db, "multi@test.com")
        p1 = _make_profile(db, user, "Self")
        p2 = _make_profile(db, user, "Mother")
        p3 = _make_profile(db, user, "Father")
        headers = _headers(user)

        now = datetime.now(timezone.utc)

        # 3 glucose readings on p1, 1 on p2, 5 on p3
        for i in range(3):
            client.post(
                "/api/readings",
                headers=headers,
                json=_reading_payload(p1.id, value=110 + i, ts=now - timedelta(hours=i)),
            )
        client.post(
            "/api/readings",
            headers=headers,
            json=_reading_payload(p2.id, value=130, ts=now),
        )
        for i in range(5):
            client.post(
                "/api/readings",
                headers=headers,
                json=_reading_payload(p3.id, value=90 + i, ts=now - timedelta(hours=i)),
            )

        r1 = client.get(f"/api/readings?profile_id={p1.id}", headers=headers).json()
        r2 = client.get(f"/api/readings?profile_id={p2.id}", headers=headers).json()
        r3 = client.get(f"/api/readings?profile_id={p3.id}", headers=headers).json()

        assert len(r1) == 3
        assert len(r2) == 1
        assert len(r3) == 5

        # Cross-contamination check — every reading belongs to its profile
        assert all(r["profile_id"] == p1.id for r in r1)
        assert all(r["profile_id"] == p2.id for r in r2)
        assert all(r["profile_id"] == p3.id for r in r3)

        # Health scores isolated
        s1 = client.get(
            f"/api/readings/health-score?profile_id={p1.id}", headers=headers
        ).json()
        s3 = client.get(
            f"/api/readings/health-score?profile_id={p3.id}", headers=headers
        ).json()
        assert s1["profile_name"] == "Self"
        assert s3["profile_name"] == "Father"
        assert s1["today_glucose_value"] == 110.0
        assert s3["today_glucose_value"] == 90.0

    def test_other_users_profile_is_invisible(self, client, db):
        owner = _make_user(db, "own@test.com")
        _ = _make_profile(db, owner, "Mine")
        stranger = _make_user(db, "stranger@test.com")

        # Stranger's /profiles listing must not include owner's profile
        resp = client.get("/api/profiles", headers=_headers(stranger))
        assert resp.status_code == 200
        assert resp.json() == []


# ---------------------------------------------------------------------------
# 4. Account deletion cascade (DPDPA)
# ---------------------------------------------------------------------------


class TestAccountDeletionCascade:
    def test_delete_user_purges_owned_data(self, client, db):
        user = _make_user(db, "todelete@test.com")
        profile = _make_profile(db, user, "ToPurge")
        headers = _headers(user)

        # Log reading + meal so there is data to purge
        client.post(
            "/api/readings",
            headers=headers,
            json=_reading_payload(profile.id, value=115),
        )
        client.post(
            "/api/meals",
            headers=headers,
            json={
                "profile_id": profile.id,
                "category": "LOW_CARB",
                "glucose_impact": "LOW",
                "meal_type": "LUNCH",
                "input_method": "QUICK_SELECT",
                "timestamp": datetime.now(timezone.utc).isoformat(),
            },
        )

        pid = profile.id
        uid = user.id

        # DELETE /api/auth/account
        resp = client.delete("/api/auth/account", headers=headers)
        assert resp.status_code == 204

        # DB must be cleaned
        db.expire_all()
        assert db.query(models.User).filter(models.User.id == uid).first() is None
        assert db.query(models.Profile).filter(models.Profile.id == pid).first() is None
        assert (
            db.query(models.HealthReading)
            .filter(models.HealthReading.profile_id == pid)
            .count()
            == 0
        )
        assert (
            db.query(models.ProfileAccess)
            .filter(models.ProfileAccess.profile_id == pid)
            .count()
            == 0
        )

    def test_delete_user_preserves_shared_profile_owned_by_someone_else(
        self, client, db
    ):
        """If user B has viewer access to user A's profile, B deleting
        their account must NOT delete A's profile or readings."""
        owner = _make_user(db, "a@test.com")
        profile = _make_profile(db, owner, "A's profile")
        viewer = _make_user(db, "b@test.com")
        db.add(
            models.ProfileAccess(
                user_id=viewer.id, profile_id=profile.id, access_level="viewer"
            )
        )
        db.flush()

        # Owner logs a reading
        client.post(
            "/api/readings",
            headers=_headers(owner),
            json=_reading_payload(profile.id, value=120),
        )

        # Viewer deletes their account
        resp = client.delete("/api/auth/account", headers=_headers(viewer))
        assert resp.status_code == 204

        # Owner's profile + reading survive
        db.expire_all()
        assert db.query(models.Profile).filter(models.Profile.id == profile.id).first() is not None
        readings = (
            db.query(models.HealthReading)
            .filter(models.HealthReading.profile_id == profile.id)
            .all()
        )
        assert len(readings) == 1

        # Viewer access row for B is gone
        remaining = (
            db.query(models.ProfileAccess)
            .filter(models.ProfileAccess.user_id == viewer.id)
            .count()
        )
        assert remaining == 0


# ---------------------------------------------------------------------------
# 5. History pagination + filtering
# ---------------------------------------------------------------------------


class TestHistoryPaginationFiltering:
    def test_pagination_limit_and_offset(self, client, db):
        user = _make_user(db, "hist@test.com")
        profile = _make_profile(db, user, "HistProfile")
        headers = _headers(user)
        now = datetime.now(timezone.utc)

        # Seed 25 glucose + 10 BP readings with distinct timestamps
        for i in range(25):
            client.post(
                "/api/readings",
                headers=headers,
                json=_reading_payload(
                    profile.id, kind="glucose", value=100 + i, ts=now - timedelta(minutes=i)
                ),
            )
        for i in range(10):
            client.post(
                "/api/readings",
                headers=headers,
                json=_reading_payload(
                    profile.id,
                    kind="blood_pressure",
                    value=120 + i,
                    ts=now - timedelta(hours=i + 1),
                ),
            )

        # Default limit=100 returns everything
        all_r = client.get(
            f"/api/readings?profile_id={profile.id}", headers=headers
        ).json()
        assert len(all_r) == 35

        # limit=10 returns first 10 by timestamp desc
        first10 = client.get(
            f"/api/readings?profile_id={profile.id}&limit=10", headers=headers
        ).json()
        assert len(first10) == 10
        # Ordered descending by reading_timestamp
        timestamps = [r["reading_timestamp"] for r in first10]
        assert timestamps == sorted(timestamps, reverse=True)

        # offset=10 limit=10 returns the next page
        next10 = client.get(
            f"/api/readings?profile_id={profile.id}&limit=10&offset=10",
            headers=headers,
        ).json()
        assert len(next10) == 10
        # No overlap between first and next pages
        first_ids = {r["id"] for r in first10}
        next_ids = {r["id"] for r in next10}
        assert first_ids.isdisjoint(next_ids)

    def test_filter_by_reading_type(self, client, db):
        user = _make_user(db, "filt@test.com")
        profile = _make_profile(db, user, "F")
        headers = _headers(user)
        now = datetime.now(timezone.utc)

        for i in range(3):
            client.post(
                "/api/readings",
                headers=headers,
                json=_reading_payload(profile.id, kind="glucose", value=110 + i, ts=now - timedelta(minutes=i)),
            )
        for i in range(2):
            client.post(
                "/api/readings",
                headers=headers,
                json=_reading_payload(profile.id, kind="blood_pressure", value=130 + i, ts=now - timedelta(minutes=i)),
            )

        glu = client.get(
            f"/api/readings?profile_id={profile.id}&reading_type=glucose",
            headers=headers,
        ).json()
        bp = client.get(
            f"/api/readings?profile_id={profile.id}&reading_type=blood_pressure",
            headers=headers,
        ).json()

        assert len(glu) == 3
        assert all(r["reading_type"] == "glucose" for r in glu)
        assert len(bp) == 2
        assert all(r["reading_type"] == "blood_pressure" for r in bp)

    def test_invalid_reading_type_rejected(self, client, db):
        user = _make_user(db, "badfilter@test.com")
        profile = _make_profile(db, user, "BF")
        resp = client.get(
            f"/api/readings?profile_id={profile.id}&reading_type=pizza",
            headers=_headers(user),
        )
        assert resp.status_code == 400
