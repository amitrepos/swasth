"""Tests for the unauthenticated /api/public/* router.

This router is reachable without a token (used by the web Contact Us
footer before login). Each test confirms both the contract AND the
default-fallback behaviour so a misconfigured server still serves a
sane response.
"""
from config import settings


def test_get_support_returns_200_and_expected_keys(client):
    """Endpoint exists, requires no auth, returns the three contract keys."""
    response = client.get("/api/public/support")
    assert response.status_code == 200
    body = response.json()
    assert set(body.keys()) == {"email", "whatsapp_number", "phone_number"}


def test_get_support_email_falls_back_to_default_when_not_overridden(client, monkeypatch):
    """If no env override, SUPPORT_EMAIL falls back to the safe default in config.py.

    Guards against a deploy where SUPPORT_EMAIL is unset in .env — the
    Contact Us card must never render with an empty email button.
    """
    monkeypatch.setattr(settings, "SUPPORT_EMAIL", "support@swasth.health")
    monkeypatch.setattr(settings, "SUPPORT_WHATSAPP_NUMBER", None)
    monkeypatch.setattr(settings, "SUPPORT_PHONE_NUMBER", None)

    body = client.get("/api/public/support").json()
    assert body["email"] == "support@swasth.health"
    assert body["whatsapp_number"] is None
    assert body["phone_number"] is None


def test_get_support_returns_configured_values(client, monkeypatch):
    """When env vars are set, the endpoint returns them verbatim."""
    monkeypatch.setattr(settings, "SUPPORT_EMAIL", "help@example.com")
    monkeypatch.setattr(settings, "SUPPORT_WHATSAPP_NUMBER", "919876543210")
    monkeypatch.setattr(settings, "SUPPORT_PHONE_NUMBER", "+919876543210")

    body = client.get("/api/public/support").json()
    assert body["email"] == "help@example.com"
    assert body["whatsapp_number"] == "919876543210"
    assert body["phone_number"] == "+919876543210"


def test_get_support_is_unauthenticated(client):
    """No Authorization header required — visitor must reach support pre-login."""
    response = client.get("/api/public/support")  # no headers
    assert response.status_code == 200
