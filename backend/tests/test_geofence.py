"""Unit tests for the India-only geofence dependency.

NOTE on import path: CI and the local pre-commit hook both run pytest with
the working directory set to backend/, which means modules live at the
top level (e.g. `dependencies`, not `backend.dependencies`). Using the
package-prefixed import broke on CI. Keep this as a flat import.
"""
import pytest
from fastapi import HTTPException, Request
import unittest.mock as mock

import dependencies
from dependencies import verify_india_location


class MockGeoIPResponse:
    def __init__(self, iso_code):
        self.country = mock.Mock()
        self.country.iso_code = iso_code


def _make_request(peer_ip="14.139.1.1", xff=None):
    request = mock.Mock(spec=Request)
    request.headers = {"X-Forwarded-For": xff} if xff else {}
    if peer_ip is None:
        request.client = None
    else:
        request.client = mock.Mock()
        request.client.host = peer_ip
    request.url = mock.Mock()
    request.url.path = "/readings"
    request.method = "POST"
    return request


# ──────────────────────────────────────────────────────────────────
# Original happy / unhappy paths
# ──────────────────────────────────────────────────────────────────

def test_verify_india_location_missing_db():
    """When the mmdb is absent, the dep fails open (dev/CI fallback)."""
    request = _make_request(peer_ip="8.8.8.8")
    with mock.patch("dependencies._get_geoip_reader", return_value=None):
        verify_india_location(request)  # must not raise


def test_verify_india_location_allowed_ip():
    request = _make_request(peer_ip="14.139.1.1")
    reader = mock.Mock()
    reader.country.return_value = MockGeoIPResponse("IN")
    with mock.patch("dependencies._get_geoip_reader", return_value=reader):
        verify_india_location(request)


def test_verify_india_location_blocked_ip():
    request = _make_request(peer_ip="8.8.8.8")
    reader = mock.Mock()
    reader.country.return_value = MockGeoIPResponse("US")
    with mock.patch("dependencies._get_geoip_reader", return_value=reader):
        with pytest.raises(HTTPException) as exc:
            verify_india_location(request)
        assert exc.value.status_code == 403
        assert exc.value.detail == "REGION_RESTRICTED"


# ──────────────────────────────────────────────────────────────────
# XFF spoofing resistance — trust XFF only behind a trusted proxy
# ──────────────────────────────────────────────────────────────────

def test_xff_honored_when_peer_is_trusted_proxy():
    """Peer is a private/loopback hop → XFF is the source of truth."""
    request = _make_request(peer_ip="10.0.0.1", xff="14.139.1.1, 10.0.0.5")
    reader = mock.Mock()
    reader.country.return_value = MockGeoIPResponse("IN")
    with mock.patch("dependencies._get_geoip_reader", return_value=reader):
        verify_india_location(request)
        reader.country.assert_called_once_with("14.139.1.1")


def test_xff_ignored_when_peer_is_public():
    """Attacker hits the API directly with a forged XFF claiming an
    Indian IP. Peer is a real US address → we must ignore the header
    and geofence the peer, otherwise the geofence is decorative."""
    request = _make_request(peer_ip="8.8.8.8", xff="14.139.1.1")
    reader = mock.Mock()
    reader.country.return_value = MockGeoIPResponse("US")
    with mock.patch("dependencies._get_geoip_reader", return_value=reader):
        with pytest.raises(HTTPException) as exc:
            verify_india_location(request)
        assert exc.value.detail == "REGION_RESTRICTED"
        reader.country.assert_called_once_with("8.8.8.8")


# ──────────────────────────────────────────────────────────────────
# Edge cases the previous suite missed
# ──────────────────────────────────────────────────────────────────

def test_request_client_is_none_does_not_crash():
    """ASGI can hand us request.client=None (lifespan or unit-test
    Requests). The dep must not AttributeError; falls back to localhost
    which is in the trusted-proxy range, so XFF (absent) is ignored
    and the loopback lookup short-circuits AddressNotFoundError."""
    request = _make_request(peer_ip=None)
    reader = mock.Mock()
    reader.country.side_effect = __import__("geoip2.errors", fromlist=["AddressNotFoundError"]).AddressNotFoundError("private")
    with mock.patch("dependencies._get_geoip_reader", return_value=reader):
        verify_india_location(request)  # must not raise


def test_generic_geoip_exception_fails_open():
    """If the GeoIP library itself blows up (corrupt DB, OSError, …) we
    must not block the user — we fail open and log."""
    request = _make_request(peer_ip="14.139.1.1")
    reader = mock.Mock()
    reader.country.side_effect = RuntimeError("mmdb corrupt")
    with mock.patch("dependencies._get_geoip_reader", return_value=reader):
        verify_india_location(request)  # must not raise


def test_bypass_only_accepts_literal_true_lowercase():
    """BYPASS_GEO_RESTRICTION must require the literal string 'true'
    (case-insensitive). '1', 'yes', anything else MUST NOT bypass —
    otherwise a stray env value silently disables the geofence."""
    request = _make_request(peer_ip="8.8.8.8")
    reader = mock.Mock()
    reader.country.return_value = MockGeoIPResponse("US")
    with mock.patch("dependencies._get_geoip_reader", return_value=reader):
        with mock.patch.dict("os.environ", {"BYPASS_GEO_RESTRICTION": "1"}, clear=False):
            with pytest.raises(HTTPException) as exc:
                verify_india_location(request)
            assert exc.value.detail == "REGION_RESTRICTED"


def test_bypass_true_emits_audit_log(caplog):
    """When the bypass IS active we must leave an audit trail. Without
    this, an operator could leave the flag flipped in prod and we'd
    have no record of which requests skipped the check."""
    request = _make_request(peer_ip="8.8.8.8")
    with mock.patch.dict("os.environ", {"BYPASS_GEO_RESTRICTION": "true"}, clear=False):
        with caplog.at_level("WARNING", logger="dependencies"):
            verify_india_location(request)
        assert any("GEOFENCE_BYPASS" in r.message for r in caplog.records), \
            "Bypass must emit a WARNING with GEOFENCE_BYPASS so audit can grep it"
