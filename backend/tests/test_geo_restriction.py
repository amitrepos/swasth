"""Tests for region-based write gating (NUO-135)."""
import asyncio
import os
from datetime import datetime, timezone

import pytest
from fastapi import Request

import models
from dependencies import _get_client_ip
from utils import geo


@pytest.fixture(autouse=True)
def _clear_geo_cache():
    """Don't let one test's IP→country cache leak into the next."""
    geo.reset_cache()
    yield
    geo.reset_cache()


def _decide(req):
    """Resolve the client IP the same way production does (spoof-resistant)
    then run the async decision function from a sync test body."""
    ip = _get_client_ip(req)
    return asyncio.run(geo.is_india_writer_allowed(req, ip))


def _async_country(value):
    """Build an async stand-in for `geo._lookup_country` returning `value`."""
    async def _stub(ip):
        return value
    return _stub


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
    allowed, country, source = _decide(req)
    assert allowed is True
    assert country == "IN"
    assert source == "disabled"


def test_private_ip_with_no_locale_is_unknown(monkeypatch):
    monkeypatch.setenv("GEO_RESTRICT_ENABLED", "true")
    req = _fake_request(client_host="10.0.0.5")
    allowed, country, source = _decide(req)
    assert allowed is False
    assert country == "UNKNOWN"
    assert source == "private"


def test_private_ip_with_in_locale_falls_back_to_india(monkeypatch):
    monkeypatch.setenv("GEO_RESTRICT_ENABLED", "true")
    req = _fake_request(headers={"Accept-Language": "hi-IN,en;q=0.5"}, client_host="127.0.0.1")
    allowed, country, source = _decide(req)
    assert allowed is True
    assert country == "IN"
    assert source == "private"


def test_x_forwarded_for_is_honored(monkeypatch):
    monkeypatch.setenv("GEO_RESTRICT_ENABLED", "true")
    # ipapi is mocked to return US
    monkeypatch.setattr(geo, "_lookup_country", _async_country("US"))
    req = _fake_request(headers={"X-Forwarded-For": "8.8.8.8, 10.0.0.1"}, client_host="10.0.0.1")
    allowed, country, source = _decide(req)
    assert allowed is False
    assert country == "US"
    assert source == "ip"


def test_lookup_returns_india_allows_write(monkeypatch):
    monkeypatch.setenv("GEO_RESTRICT_ENABLED", "true")
    monkeypatch.setattr(geo, "_lookup_country", _async_country("IN"))
    req = _fake_request(client_host="49.207.0.1")
    allowed, country, source = _decide(req)
    assert allowed is True
    assert country == "IN"
    assert source == "ip"


def test_lookup_unknown_with_in_locale_allows(monkeypatch):
    monkeypatch.setenv("GEO_RESTRICT_ENABLED", "true")
    monkeypatch.setattr(geo, "_lookup_country", _async_country("UNKNOWN"))
    req = _fake_request(
        headers={"Accept-Language": "en-IN"},
        client_host="203.0.113.5",
    )
    allowed, country, source = _decide(req)
    assert allowed is True
    assert source == "locale"


def test_unresolvable_ip_is_error(monkeypatch):
    """When the caller cannot resolve a client IP at all (ip=None), the
    decision is a blocked 'error' — never a silent allow."""
    monkeypatch.setenv("GEO_RESTRICT_ENABLED", "true")
    req = _fake_request()
    allowed, country, source = asyncio.run(geo.is_india_writer_allowed(req, None))
    assert allowed is False
    assert country == "UNKNOWN"
    assert source == "error"


def test_spoofed_xff_from_untrusted_peer_is_blocked(monkeypatch):
    """SECURITY (NUO-135): a non-India client cannot bypass the gate by
    sending `X-Forwarded-For: <Indian IP>`. The peer is not a trusted
    proxy, so XFF is ignored and the real (US) peer IP is looked up."""
    monkeypatch.setenv("GEO_RESTRICT_ENABLED", "true")

    looked_up = {}

    async def _record_lookup(ip):
        looked_up["ip"] = ip
        # The real peer (1.2.3.4) is a US IP in this scenario.
        return "US"

    monkeypatch.setattr(geo, "_lookup_country", _record_lookup)
    # Attacker connects directly (untrusted peer) but spoofs an Indian XFF.
    req = _fake_request(
        headers={"X-Forwarded-For": "106.51.0.1", "Accept-Language": "en-US"},
        client_host="1.2.3.4",
    )
    allowed, country, source = _decide(req)
    assert allowed is False
    assert country == "US"
    # The spoofed Indian IP must NOT have reached the geo lookup.
    assert looked_up["ip"] == "1.2.3.4"


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
            "intake_period": "MORNING",
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
            "intake_period": "MORNING",
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


def _create_medication_for_geo_tests(client, db, test_user, auth_headers, monkeypatch):
    """Create a med while geo gate is off (CI default), return row id."""
    monkeypatch.delenv("GEO_RESTRICT_ENABLED", raising=False)
    pid = _profile_id_for(test_user, db)
    r = client.post(
        "/api/medications",
        json={
            "profile_id": pid,
            "name": "Aspirin",
            "intake_period": "MORNING",
            "taken_at": datetime.now(timezone.utc).isoformat(),
        },
        headers=auth_headers,
    )
    assert r.status_code == 201, r.text
    return r.json()["id"]


def test_patch_medication_blocked_when_geo_enabled_non_india(
    client, db, test_user, auth_headers, monkeypatch
):
    med_id = _create_medication_for_geo_tests(client, db, test_user, auth_headers, monkeypatch)
    monkeypatch.setenv("GEO_RESTRICT_ENABLED", "true")
    r = client.patch(
        f"/api/medications/{med_id}",
        json={"dose": "100 mg"},
        headers={**auth_headers, "Accept-Language": "en-US"},
    )
    assert r.status_code == 451
    assert r.json()["detail"]["code"] == "REGION_NOT_ALLOWED"


def test_delete_medication_blocked_when_geo_enabled_non_india(
    client, db, test_user, auth_headers, monkeypatch
):
    med_id = _create_medication_for_geo_tests(client, db, test_user, auth_headers, monkeypatch)
    monkeypatch.setenv("GEO_RESTRICT_ENABLED", "true")
    r = client.delete(
        f"/api/medications/{med_id}",
        headers={**auth_headers, "Accept-Language": "en-US"},
    )
    assert r.status_code == 451
    assert r.json()["detail"]["code"] == "REGION_NOT_ALLOWED"


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
