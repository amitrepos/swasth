"""Tests for region-based write gating (NUO-135)."""
import os
from datetime import datetime, timezone

import pytest
from fastapi import Request

import models
from utils import geo


@pytest.fixture(autouse=True)
def _clear_geo_cache():
    """Don't let one test's IP→country cache leak into the next."""
    geo.reset_cache()
    yield
    geo.reset_cache()


# ---------------------------------------------------------------------------
# Pure helpers
# ---------------------------------------------------------------------------

def _fake_request(headers=None, client_host="8.8.8.8"):
    scope = {
        "type": "http",
        "headers": [
            (k.lower().encode(), v.encode()) for k, v in (headers or {}).items()
        ],
        "client": (client_host, 12345),
        "method": "GET",
        "path": "/x",
        "query_string": b"",
    }
    return Request(scope)


def test_master_switch_disabled_treats_everyone_as_india(monkeypatch):
    monkeypatch.delenv("GEO_RESTRICT_ENABLED", raising=False)
    req = _fake_request(client_host="1.1.1.1")
    allowed, country, source = geo.is_india_writer_allowed(req)
    assert allowed is True
    assert country == "IN"
    assert source == "disabled"


def test_private_ip_with_no_locale_is_unknown(monkeypatch):
    monkeypatch.setenv("GEO_RESTRICT_ENABLED", "true")
    req = _fake_request(client_host="10.0.0.5")
    allowed, country, source = geo.is_india_writer_allowed(req)
    assert allowed is False
    assert country == "UNKNOWN"
    assert source == "private"


def test_private_ip_with_in_locale_falls_back_to_india(monkeypatch):
    monkeypatch.setenv("GEO_RESTRICT_ENABLED", "true")
    req = _fake_request(headers={"Accept-Language": "hi-IN,en;q=0.5"}, client_host="127.0.0.1")
    allowed, country, source = geo.is_india_writer_allowed(req)
    assert allowed is True
    assert country == "IN"
    assert source == "private"


def test_x_forwarded_for_is_honored(monkeypatch):
    monkeypatch.setenv("GEO_RESTRICT_ENABLED", "true")
    # ipapi is mocked to return US
    monkeypatch.setattr(geo, "_lookup_country_cached", lambda ip: "US")
    req = _fake_request(headers={"X-Forwarded-For": "8.8.8.8, 10.0.0.1"}, client_host="10.0.0.1")
    allowed, country, source = geo.is_india_writer_allowed(req)
    assert allowed is False
    assert country == "US"
    assert source == "ip"


def test_lookup_returns_india_allows_write(monkeypatch):
    monkeypatch.setenv("GEO_RESTRICT_ENABLED", "true")
    monkeypatch.setattr(geo, "_lookup_country_cached", lambda ip: "IN")
    req = _fake_request(client_host="49.207.0.1")
    allowed, country, source = geo.is_india_writer_allowed(req)
    assert allowed is True
    assert country == "IN"
    assert source == "ip"


def test_lookup_unknown_with_in_locale_allows(monkeypatch):
    monkeypatch.setenv("GEO_RESTRICT_ENABLED", "true")
    monkeypatch.setattr(geo, "_lookup_country_cached", lambda ip: "UNKNOWN")
    req = _fake_request(
        headers={"Accept-Language": "en-IN"},
        client_host="203.0.113.5",
    )
    allowed, country, source = geo.is_india_writer_allowed(req)
    assert allowed is True
    assert source == "locale"


def test_no_client_no_headers_is_error(monkeypatch):
    monkeypatch.setenv("GEO_RESTRICT_ENABLED", "true")
    scope = {
        "type": "http",
        "headers": [],
        "client": None,
        "method": "GET",
        "path": "/x",
        "query_string": b"",
    }
    req = Request(scope)
    allowed, country, source = geo.is_india_writer_allowed(req)
    assert allowed is False
    assert source == "error"


# ---------------------------------------------------------------------------
# Endpoint-level behaviour (TestClient)
# ---------------------------------------------------------------------------

def test_public_region_returns_disabled_by_default(client, monkeypatch):
    monkeypatch.delenv("GEO_RESTRICT_ENABLED", raising=False)
    r = client.get("/api/public/region")
    assert r.status_code == 200
    body = r.json()
    assert body["is_india"] is True
    assert body["source"] == "disabled"


def test_public_region_blocks_when_enabled_without_locale(client, monkeypatch):
    monkeypatch.setenv("GEO_RESTRICT_ENABLED", "true")
    r = client.get("/api/public/region")
    body = r.json()
    assert body["is_india"] is False
    assert body["write_allowed"] is False


def test_public_region_allows_when_locale_in(client, monkeypatch):
    monkeypatch.setenv("GEO_RESTRICT_ENABLED", "true")
    r = client.get("/api/public/region", headers={"Accept-Language": "hi-IN"})
    body = r.json()
    assert body["is_india"] is True


# ---------------------------------------------------------------------------
# Write-endpoint enforcement (NUO-135 acceptance criteria)
# ---------------------------------------------------------------------------

def _profile_id_for(user, db):
    return (
        db.query(models.ProfileAccess)
        .filter(models.ProfileAccess.user_id == user.id)
        .first()
        .profile_id
    )


def test_post_medication_blocked_when_geo_enabled_non_india(client, db, test_user, auth_headers, monkeypatch):
    monkeypatch.setenv("GEO_RESTRICT_ENABLED", "true")
    pid = _profile_id_for(test_user, db)
    r = client.post(
        "/api/medications",
        json={
            "profile_id": pid,
            "name": "Aspirin",
            "taken_at": datetime.now(timezone.utc).isoformat(),
        },
        headers={**auth_headers, "Accept-Language": "en-US"},
    )
    assert r.status_code == 451
    body = r.json()
    assert body["detail"]["code"] == "REGION_NOT_ALLOWED"


def test_post_medication_allowed_when_locale_in(client, db, test_user, auth_headers, monkeypatch):
    monkeypatch.setenv("GEO_RESTRICT_ENABLED", "true")
    pid = _profile_id_for(test_user, db)
    r = client.post(
        "/api/medications",
        json={
            "profile_id": pid,
            "name": "Aspirin",
            "taken_at": datetime.now(timezone.utc).isoformat(),
        },
        headers={**auth_headers, "Accept-Language": "en-IN"},
    )
    assert r.status_code == 201


def test_get_medications_NOT_blocked_outside_india(client, db, test_user, auth_headers, monkeypatch):
    """Reads must keep working for diaspora caregivers (NUO-135 acceptance)."""
    monkeypatch.setenv("GEO_RESTRICT_ENABLED", "true")
    pid = _profile_id_for(test_user, db)
    r = client.get(
        f"/api/medications?profile_id={pid}&days=30",
        headers={**auth_headers, "Accept-Language": "en-US"},
    )
    assert r.status_code == 200


def test_post_reading_blocked_when_geo_enabled_non_india(client, db, test_user, auth_headers, monkeypatch):
    monkeypatch.setenv("GEO_RESTRICT_ENABLED", "true")
    pid = _profile_id_for(test_user, db)
    payload = {
        "profile_id": pid,
        "reading_type": "glucose",
        "glucose_value": 120,
        "glucose_unit": "mg/dL",
        "value_numeric": 120,
        "unit_display": "mg/dL",
        "reading_timestamp": datetime.now(timezone.utc).isoformat(),
    }
    r = client.post(
        "/api/readings",
        json=payload,
        headers={**auth_headers, "Accept-Language": "en-US"},
    )
    assert r.status_code == 451


def test_post_chat_message_blocked_when_geo_enabled_non_india(client, db, test_user, auth_headers, monkeypatch):
    """NUO-135: chat is a write endpoint (creates ChatMessage + AI cost) so it
    must be gated alongside readings/meals/medications. Reads of chat history
    via GET stay open for diaspora caregivers."""
    monkeypatch.setenv("GEO_RESTRICT_ENABLED", "true")
    pid = _profile_id_for(test_user, db)
    r = client.post(
        "/api/chat/messages",
        json={
            "profile_id": pid,
            "message": "Why was my sugar high yesterday?",
        },
        headers={**auth_headers, "Accept-Language": "en-US"},
    )
    assert r.status_code == 451
    body = r.json()
    assert body["detail"]["code"] == "REGION_NOT_ALLOWED"


def test_get_chat_messages_NOT_blocked_outside_india(client, db, test_user, auth_headers, monkeypatch):
    """GET chat history must remain available to diaspora caregivers."""
    monkeypatch.setenv("GEO_RESTRICT_ENABLED", "true")
    pid = _profile_id_for(test_user, db)
    r = client.get(
        f"/api/chat/messages?profile_id={pid}",
        headers={**auth_headers, "Accept-Language": "en-US"},
    )
    assert r.status_code == 200
