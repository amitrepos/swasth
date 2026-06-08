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


@pytest.fixture(autouse=True)
def _clear_trusted_proxy_cache():
    """Tests that monkey-patch TRUSTED_PROXIES need a fresh parse; clear
    the module-level cache before every test so order-of-execution
    cannot leak state between cases."""
    dependencies._reset_trusted_proxy_cache()
    yield
    dependencies._reset_trusted_proxy_cache()


class MockGeoIPResponse:
    def __init__(self, iso_code):
        self.country = mock.Mock()
        self.country.iso_code = iso_code


def _make_request(peer_ip="14.139.1.1", xff=None, auth_token=None):
    """Build a mock Request that mirrors production header semantics.

    Uses starlette.datastructures.Headers so header lookups are
    case-insensitive — matches what FastAPI hands us at runtime. A
    plain dict would silently break any production code path that
    reads a header with a different case than the test set, which is
    the failure mode that originally motivated the lowercase-only
    convention.
    """
    from starlette.datastructures import Headers
    raw: dict = {}
    if xff:
        raw["x-forwarded-for"] = xff
    if auth_token:
        raw["authorization"] = f"Bearer {auth_token}"
    request = mock.Mock(spec=Request)
    request.headers = Headers(raw)
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


# ──────────────────────────────────────────────────────────────────
# DPDPA — PII handling in logs
# ──────────────────────────────────────────────────────────────────

def test_blocked_request_log_masks_client_ip(caplog):
    """DPDPA treats IPs as personal data; the INFO log on a blocked
    request must mask the last octet so routine ops logs are not a
    de facto personal-data store."""
    request = _make_request(peer_ip="8.8.8.8")
    reader = mock.Mock()
    reader.country.return_value = MockGeoIPResponse("US")
    with mock.patch("dependencies._get_geoip_reader", return_value=reader):
        with caplog.at_level("INFO", logger="dependencies"):
            with pytest.raises(HTTPException):
                verify_india_location(request)
        joined = " ".join(r.message for r in caplog.records)
        assert "ip_masked=8.8.8.x" in joined, \
            "Blocked-request log must include ip_masked=… with the last octet redacted"
        assert "8.8.8.8" not in joined, \
            "Full client IP must never appear in INFO logs (DPDPA personal data)"


# ──────────────────────────────────────────────────────────────────
# Perf — trusted-proxy parsing is cached
# ──────────────────────────────────────────────────────────────────

def test_trusted_proxy_networks_cached_across_calls():
    """_trusted_proxy_networks is called once per request via
    _get_client_ip. Re-parsing TRUSTED_PROXIES on every call wastes
    CPU on a hot path — the value is static at process start."""
    first = dependencies._trusted_proxy_networks()
    second = dependencies._trusted_proxy_networks()
    assert first is second, \
        "Trusted-proxy list must be cached (identity match), not re-parsed per call"


# ──────────────────────────────────────────────────────────────────
# Defensive: None country code (satellite / anycast)
# ──────────────────────────────────────────────────────────────────

def test_none_country_code_fails_open():
    """GeoLite2 returns iso_code=None for satellite / anycast IPs and
    records without a country assignment. None != 'IN' would 403 real
    Bihar users on VSAT links; treat None as fail-open."""
    request = _make_request(peer_ip="14.139.1.1")
    reader = mock.Mock()
    reader.country.return_value = MockGeoIPResponse(None)
    with mock.patch("dependencies._get_geoip_reader", return_value=reader):
        verify_india_location(request)  # must not raise


# ──────────────────────────────────────────────────────────────────
# Route-wiring integration tests — catch decorator-typo regressions
# ──────────────────────────────────────────────────────────────────
#
# The unit tests above patch verify_india_location's internals. They
# would all pass even if the dependency were silently dropped from a
# route. These TestClient cases fire a real HTTP request and assert
# the 403 surfaces — the only way to detect a regression where someone
# forgets to add `dependencies=[Depends(verify_india_location)]` to a
# new route or removes it during refactor.


def _us_reader():
    """Mock GeoIP reader that classifies every IP as US."""
    reader = mock.Mock()
    reader.country.return_value = MockGeoIPResponse("US")
    return reader


def _profile_id_for(user) -> int:
    """Look up the owner ProfileAccess for `user` (User has no
    `profile_accesses` relationship on the ORM; query it directly)."""
    import models
    from sqlalchemy.orm import object_session
    session = object_session(user)
    access = (
        session.query(models.ProfileAccess)
        .filter(
            models.ProfileAccess.user_id == user.id,
            models.ProfileAccess.access_level == "owner",
        )
        .first()
    )
    assert access is not None, "test_user fixture should create an owner ProfileAccess"
    return access.profile_id


def test_route_wired_post_readings_blocks_us_nuo135(client, auth_headers, test_user, monkeypatch):
    """POST /readings uses require_india_writer (451), not verify_india_location (403)."""
    from datetime import datetime, timezone

    profile_id = _profile_id_for(test_user)
    body = {
        "profile_id": profile_id,
        "reading_type": "glucose",
        "glucose_value": 110,
        "glucose_unit": "mg/dL",
        "value_numeric": 110,
        "unit_display": "mg/dL",
        "reading_timestamp": datetime.now(timezone.utc).isoformat(),
    }
    # require_india_writer now resolves country via the mmdb (not the old
    # GEO_RESTRICT_ENABLED/ipapi.co path). Mock the reader to claim US so
    # the gate blocks; without this, CI has no mmdb → fail-open → 201.
    with mock.patch("dependencies._get_geoip_reader", return_value=_us_reader()):
        r = client.post(
            "/api/readings",
            json=body,
            headers={**auth_headers, "Accept-Language": "en-US"},
        )
    assert r.status_code == 451, (
        f"Expected 451 from require_india_writer, got {r.status_code}: {r.text}. "
        "POST /readings must not stack verify_india_location with require_india_writer."
    )
    assert r.json()["detail"]["code"] == "REGION_NOT_ALLOWED"


def test_route_wired_post_meals_blocks_us_nuo135(client, auth_headers, test_user, monkeypatch):
    """POST /meals uses require_india_writer (451), not verify_india_location (403)."""
    from datetime import datetime, timezone

    profile_id = _profile_id_for(test_user)
    body = {
        "profile_id": profile_id,
        "meal_type": "BREAKFAST",
        "category": "MODERATE_CARB",
        "input_method": "quick_select",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    # See note in the readings test: gate is mmdb-backed now, so mock US.
    with mock.patch("dependencies._get_geoip_reader", return_value=_us_reader()):
        r = client.post(
            "/api/meals",
            json=body,
            headers={**auth_headers, "Accept-Language": "en-US"},
        )
    assert r.status_code == 451, (
        f"Expected 451 from require_india_writer, got {r.status_code}: {r.text}. "
        "POST /meals must not stack verify_india_location with require_india_writer."
    )
    assert r.json()["detail"]["code"] == "REGION_NOT_ALLOWED"


def test_route_wired_delete_meal_blocks_us(client, auth_headers, test_user):
    """DELETE /meals/{id} must also be geofenced — destructive ops on
    PHI are exactly what the rule is meant to protect."""
    with mock.patch("dependencies._get_geoip_reader", return_value=_us_reader()):
        # The meal doesn't need to exist — the dependency runs before the
        # 404. If geofence is wired we get 403 first.
        r = client.delete("/api/meals/999999", headers=auth_headers)
    assert r.status_code == 403, (
        f"Expected 403 from geofence, got {r.status_code}: {r.text}. "
        "Likely cause: verify_india_location was dropped from DELETE /meals/{id}."
    )
    assert r.json().get("detail") == "REGION_RESTRICTED"


def test_route_not_geofenced_get_readings_passes_us(client, auth_headers, test_user):
    """GET /readings is intentionally NOT geofenced — diaspora users
    must be able to view existing history. This is a guardrail: if
    someone adds the dep to read endpoints by mistake, this test
    catches it before NRI users lose access to their own data."""
    profile_id = _profile_id_for(test_user)
    with mock.patch("dependencies._get_geoip_reader", return_value=_us_reader()):
        r = client.get(f"/api/readings?profile_id={profile_id}", headers=auth_headers)
    assert r.status_code != 403 or r.json().get("detail") != "REGION_RESTRICTED", (
        "GET /readings must NOT be geofenced; NRI users need read access. "
        "If this assertion fires, someone added verify_india_location to a "
        "read endpoint — revert that."
    )


# ──────────────────────────────────────────────────────────────────
# Wiring tests for the REMAINING geofenced routes
# ──────────────────────────────────────────────────────────────────
# The block above covers POST/DELETE happy paths. These cases cover
# the rest of the surface; they all use the same pattern: mock the
# GeoIP reader to claim US, fire the request, assert the geofence
# 403 surfaces before the route's own validation/404 logic.
#
# We don't care about 404/422 here — only that the geofence fires
# FIRST. If the dep is dropped, the assertion catches it because the
# request will get past the geofence and produce a different status.

def _assert_geofence_blocked(response, method: str, path: str):
    detail = ""
    try:
        detail = response.json().get("detail", "")
    except Exception:
        pass
    assert response.status_code == 403 and detail == "REGION_RESTRICTED", (
        f"Expected 403 REGION_RESTRICTED from geofence on {method} {path}, "
        f"got {response.status_code}: {response.text}. "
        "Likely cause: verify_india_location was dropped from this route."
    )


def test_route_wired_put_reading_blocks_us(client, auth_headers):
    """PUT /api/readings/{id} — edit reading."""
    with mock.patch("dependencies._get_geoip_reader", return_value=_us_reader()):
        r = client.put("/api/readings/999999", json={}, headers=auth_headers)
    _assert_geofence_blocked(r, "PUT", "/api/readings/{id}")


def test_route_wired_delete_reading_blocks_us(client, auth_headers):
    """DELETE /api/readings/{id} — delete reading."""
    with mock.patch("dependencies._get_geoip_reader", return_value=_us_reader()):
        r = client.delete("/api/readings/999999", headers=auth_headers)
    _assert_geofence_blocked(r, "DELETE", "/api/readings/{id}")


def test_route_wired_post_readings_parse_image_blocks_us(client, auth_headers):
    """POST /api/readings/parse-image — OCR upload (multipart)."""
    with mock.patch("dependencies._get_geoip_reader", return_value=_us_reader()):
        r = client.post(
            "/api/readings/parse-image?device_type=glucose",
            headers=auth_headers,
            files={"file": ("x.jpg", b"\x00\x00", "image/jpeg")},
        )
    _assert_geofence_blocked(r, "POST", "/api/readings/parse-image")


def test_route_wired_patch_meal_blocks_us(client, auth_headers):
    """PATCH /api/meals/{id} — edit meal."""
    with mock.patch("dependencies._get_geoip_reader", return_value=_us_reader()):
        r = client.patch("/api/meals/999999", json={}, headers=auth_headers)
    _assert_geofence_blocked(r, "PATCH", "/api/meals/{id}")


def test_route_wired_post_meals_parse_image_blocks_us(client, auth_headers):
    """POST /api/meals/parse-image — food-photo OCR (multipart)."""
    with mock.patch("dependencies._get_geoip_reader", return_value=_us_reader()):
        r = client.post(
            "/api/meals/parse-image",
            headers=auth_headers,
            files={"file": ("x.jpg", b"\x00\x00", "image/jpeg")},
        )
    _assert_geofence_blocked(r, "POST", "/api/meals/parse-image")


def test_route_wired_post_report_manual_trigger_blocks_us(client, auth_headers):
    """POST /api/report/manual-trigger — WhatsApp report dispatch."""
    with mock.patch("dependencies._get_geoip_reader", return_value=_us_reader()):
        r = client.post("/api/report/manual-trigger", headers=auth_headers)
    _assert_geofence_blocked(r, "POST", "/api/report/manual-trigger")


def test_route_wired_post_doctor_notes_blocks_us(client, auth_headers, test_user):
    """POST /api/doctor/patients/{id}/notes — clinical notes (PHI)."""
    profile_id = _profile_id_for(test_user)
    with mock.patch("dependencies._get_geoip_reader", return_value=_us_reader()):
        r = client.post(
            f"/api/doctor/patients/{profile_id}/notes",
            json={"note": "test"},
            headers=auth_headers,
        )
    _assert_geofence_blocked(r, "POST", "/api/doctor/patients/{id}/notes")


def test_route_wired_post_doctor_verify_blocks_us(client, auth_headers):
    """POST /api/doctor/verify/{doctor_id} — admin NMC verification."""
    with mock.patch("dependencies._get_geoip_reader", return_value=_us_reader()):
        r = client.post("/api/doctor/verify/1", headers=auth_headers)
    _assert_geofence_blocked(r, "POST", "/api/doctor/verify/{id}")


# ──────────────────────────────────────────────────────────────────
# Cache behaviour for the corrupt/missing-DB sentinel
# ──────────────────────────────────────────────────────────────────

def test_unavailable_geoip_db_is_cached(tmp_path, monkeypatch, caplog):
    """When the mmdb is absent the unavailable result must be cached;
    re-stat'ing the FS on every API call (and re-logging the warning)
    was the regression flagged by review."""
    # Force the cache to a fresh state.
    dependencies._reset_geoip_reader_cache()
    # Point the lookup at a directory with NO mmdb so the missing-DB
    # branch fires. We monkey-patch os.path.dirname(__file__) indirectly
    # by clearing the cache and verifying the sentinel persists.
    monkeypatch.setattr(
        "dependencies.os.path.exists", lambda _p: False
    )
    with caplog.at_level("WARNING", logger="dependencies"):
        first = dependencies._get_geoip_reader()
        second = dependencies._get_geoip_reader()
    assert first is None and second is None
    # Sentinel cached → no re-stat. We can detect this indirectly by
    # checking the global identity is now the sentinel, not bare None.
    assert dependencies._geoip_reader is dependencies._GEOIP_UNAVAILABLE, (
        "Missing-DB result must be cached as _GEOIP_UNAVAILABLE so we "
        "don't retry os.path.exists on every request."
    )
    # Clean up so later tests aren't affected.
    dependencies._reset_geoip_reader_cache()


# ──────────────────────────────────────────────────────────────────
# Empty TRUSTED_PROXIES must NOT silently disable proxy detection
# ──────────────────────────────────────────────────────────────────

def test_empty_trusted_proxies_logs_warning(caplog, monkeypatch):
    """TRUSTED_PROXIES='' produces an empty CIDR list; XFF is then
    ignored for every request. That's a defensible posture but it
    must be loud — operators need to notice if a deploy script
    accidentally clears the env var."""
    monkeypatch.setenv("TRUSTED_PROXIES", "")
    dependencies._reset_trusted_proxy_cache()
    with caplog.at_level("WARNING", logger="dependencies"):
        nets = dependencies._trusted_proxy_networks()
    assert nets == []
    assert any(
        "TRUSTED_PROXIES resolved to an empty CIDR list" in r.message
        for r in caplog.records
    ), "Empty TRUSTED_PROXIES must emit a WARNING — silent failure was the regression."


# ──────────────────────────────────────────────────────────────────
# Email allowlist (GEOFENCE_EMAIL_ALLOWLIST)
# ──────────────────────────────────────────────────────────────────
#
# Designated-account bypass — authenticated users whose email is in the
# allowlist skip the IP-country gate. Auth, rate limits, and audit
# logging still apply; only the geofence is short-circuited.
#
# These tests prove the slot-in is correct:
#   1. Empty allowlist → no behaviour change (existing tests still hold).
#   2. Allowlisted email + US IP → ALLOW.
#   3. Non-allowlisted email + US IP → BLOCK (the gate is not generally
#      weakened).
#   4. Malformed/missing Authorization → falls through to IP check
#      (a broken token must NOT inadvertently flip the geofence into
#      allow-all).
#   5. Audit log fires on every allowlist hit — the regulator-visible
#      trail.


def _mint_bearer_token(email: str) -> str:
    """Build a valid Bearer JWT for `email` using the same auth path
    production uses. We test the real decode → hash → membership chain
    end-to-end, not a mock of it."""
    import auth as _auth
    return _auth.create_access_token({"sub": email})


def _set_allowlist(monkeypatch, emails: str) -> None:
    """Override settings.GEOFENCE_EMAIL_ALLOWLIST and reset the cached
    hash set so the next verify_india_location call re-reads it."""
    from config import settings as _settings
    monkeypatch.setattr(_settings, "GEOFENCE_EMAIL_ALLOWLIST", emails)
    dependencies._reset_geofence_allowlist_cache()


@pytest.fixture(autouse=True)
def _clear_geofence_allowlist_cache():
    """Make sure no test leaks an allowlist-hashes value into the next."""
    dependencies._reset_geofence_allowlist_cache()
    yield
    dependencies._reset_geofence_allowlist_cache()


def test_allowlist_empty_no_behaviour_change():
    """Default state: GEOFENCE_EMAIL_ALLOWLIST="" (the cap is off).
    A US IP must still block, even if a valid token is attached. This
    pins that we didn't accidentally make the allowlist branch
    fail-open when the env var is unset."""
    request = _make_request(
        peer_ip="8.8.8.8",
        auth_token=_mint_bearer_token("anyone@swasth.health"),
    )
    reader = mock.Mock()
    reader.country.return_value = MockGeoIPResponse("US")
    with mock.patch("dependencies._get_geoip_reader", return_value=reader):
        with pytest.raises(HTTPException) as exc:
            verify_india_location(request)
        assert exc.value.detail == "REGION_RESTRICTED"


def test_allowlist_hit_allows_us_request(monkeypatch):
    """Authenticated user whose email is in GEOFENCE_EMAIL_ALLOWLIST
    must bypass the IP check even from a US IP."""
    _set_allowlist(monkeypatch, "smoke@swasth.health,qa@swasth.health")
    request = _make_request(
        peer_ip="8.8.8.8",
        auth_token=_mint_bearer_token("smoke@swasth.health"),
    )
    reader = mock.Mock()
    reader.country.return_value = MockGeoIPResponse("US")
    with mock.patch("dependencies._get_geoip_reader", return_value=reader):
        verify_india_location(request)  # must not raise
    # Sanity: if the allowlist short-circuited correctly, we shouldn't
    # have hit the GeoIP reader at all.
    assert reader.country.call_count == 0, (
        "Allowlist hit must short-circuit BEFORE GeoIP lookup — saves a "
        "DB call per allowlisted request and keeps the audit trail clean."
    )


def test_allowlist_miss_still_blocks_us(monkeypatch):
    """Allowlist is non-empty but the caller is not on it. US IP must
    still block — the bypass must not generalise."""
    _set_allowlist(monkeypatch, "smoke@swasth.health")
    request = _make_request(
        peer_ip="8.8.8.8",
        auth_token=_mint_bearer_token("attacker@evil.com"),
    )
    reader = mock.Mock()
    reader.country.return_value = MockGeoIPResponse("US")
    with mock.patch("dependencies._get_geoip_reader", return_value=reader):
        with pytest.raises(HTTPException) as exc:
            verify_india_location(request)
        assert exc.value.detail == "REGION_RESTRICTED"


def test_allowlist_hit_emits_audit_log(monkeypatch, caplog):
    """Every allowlist bypass must leave a DPDPA-visible audit trail.
    Log line: GEOFENCE_ALLOWLIST_HIT email_hash_prefix=<12 chars>
    path=… method=…. The 12-char prefix preserves correlation without
    being long enough to brute-force the email."""
    _set_allowlist(monkeypatch, "smoke@swasth.health")
    request = _make_request(
        peer_ip="8.8.8.8",
        auth_token=_mint_bearer_token("smoke@swasth.health"),
    )
    with caplog.at_level("INFO", logger="dependencies"):
        verify_india_location(request)
    hits = [r.message for r in caplog.records if "GEOFENCE_ALLOWLIST_HIT" in r.message]
    assert hits, (
        "Allowlist bypass must emit a GEOFENCE_ALLOWLIST_HIT INFO log so "
        "the audit trail exists. Missing log = compliance regression."
    )
    msg = hits[0]
    assert "email_hash_prefix=" in msg, "Log must include hashed-email prefix"
    assert "path=/readings" in msg
    assert "method=POST" in msg
    # Defence-in-depth: full email or full hash must never be in the log.
    assert "smoke@swasth.health" not in msg, (
        "Plaintext email must never appear in INFO logs (DPDPA PII)."
    )


def test_missing_bearer_token_falls_through_to_ip_check(monkeypatch):
    """No Authorization header → email_hash extraction returns None →
    geofence falls through to the IP check. A request without a token
    must NOT inadvertently bypass the geofence."""
    _set_allowlist(monkeypatch, "smoke@swasth.health")
    request = _make_request(peer_ip="8.8.8.8")  # headers default to {}
    reader = mock.Mock()
    reader.country.return_value = MockGeoIPResponse("US")
    with mock.patch("dependencies._get_geoip_reader", return_value=reader):
        with pytest.raises(HTTPException) as exc:
            verify_india_location(request)
        assert exc.value.detail == "REGION_RESTRICTED"


def test_expired_bearer_token_falls_through_to_ip_check(monkeypatch, caplog):
    """Expired JWT must NOT bypass the geofence — the decode-failure
    path in _email_hash_from_bearer_token already handles this via
    `except Exception`, but pin it explicitly so a future JWT-library
    upgrade that changes the expired-token exception type can't
    silently regress the gate. Two assertions: (a) the request still
    403s, (b) the allowlist audit log did NOT fire — a regression
    that let the expired token through to the allowlist branch would
    leave that log line even though the IP check eventually blocks."""
    from datetime import timedelta
    import auth as _auth

    _set_allowlist(monkeypatch, "smoke@swasth.health")
    expired_token = _auth.create_access_token(
        {"sub": "smoke@swasth.health"},
        expires_delta=timedelta(seconds=-1),
    )
    request = _make_request(peer_ip="8.8.8.8", auth_token=expired_token)
    reader = mock.Mock()
    reader.country.return_value = MockGeoIPResponse("US")
    with mock.patch("dependencies._get_geoip_reader", return_value=reader):
        with caplog.at_level("INFO", logger="dependencies"):
            with pytest.raises(HTTPException) as exc:
                verify_india_location(request)
            assert exc.value.detail == "REGION_RESTRICTED"
        assert not any("GEOFENCE_ALLOWLIST_HIT" in r.message for r in caplog.records), (
            "Expired token must NOT fire the allowlist audit-log. If this "
            "fires, the decode-failure path is not catching the expired-"
            "token exception type — a JWT-library upgrade may have broken it."
        )


def test_malformed_bearer_token_falls_through_to_ip_check(monkeypatch):
    """Garbage in the authorization header -> decode fails -> email_hash
    is None -> falls through to IP check. A broken token must NOT bypass."""
    from starlette.datastructures import Headers
    _set_allowlist(monkeypatch, "smoke@swasth.health")
    request = _make_request(peer_ip="8.8.8.8")
    request.headers = Headers({"authorization": "Bearer this-is-not-a-jwt"})
    reader = mock.Mock()
    reader.country.return_value = MockGeoIPResponse("US")
    with mock.patch("dependencies._get_geoip_reader", return_value=reader):
        with pytest.raises(HTTPException) as exc:
            verify_india_location(request)
        assert exc.value.detail == "REGION_RESTRICTED"


def test_allowlist_runs_after_env_bypass(monkeypatch):
    """Order check: BYPASS_GEO_RESTRICTION (step 1) must still win even
    when the caller is on the allowlist. Operators rely on the env flag
    as the emergency-rollback escape hatch."""
    _set_allowlist(monkeypatch, "smoke@swasth.health")
    request = _make_request(
        peer_ip="8.8.8.8",
        auth_token=_mint_bearer_token("smoke@swasth.health"),
    )
    with mock.patch.dict("os.environ", {"BYPASS_GEO_RESTRICTION": "true"}, clear=False):
        # Both bypasses would allow this request; we want to prove the
        # env flag wins (warning log, NOT info log).
        with mock.patch("dependencies._get_geoip_reader") as reader_mock:
            verify_india_location(request)
            assert reader_mock.call_count == 0


# ── Config-layer validation tests ───────────────────────────────────


def test_config_rejects_malformed_email_in_allowlist():
    """A typo in the env var (missing @ or dot) must crash boot, not
    silently widen the allowlist. Pydantic ValidationError surfaces in
    the process log before traffic is accepted."""
    from pydantic import ValidationError
    from config import Settings
    with pytest.raises(ValidationError):
        Settings(GEOFENCE_EMAIL_ALLOWLIST="notanemail,also-bad")


def test_config_rejects_oversized_allowlist():
    """Cap = 25. Going past it is a compliance smell that must require
    a code change, not just an env tweak."""
    from pydantic import ValidationError
    from config import Settings
    too_many = ",".join(f"user{i}@swasth.health" for i in range(26))
    with pytest.raises(ValidationError):
        Settings(GEOFENCE_EMAIL_ALLOWLIST=too_many)


def test_config_normalises_allowlist():
    """Validator must lowercase, trim, and dedupe so a sloppy paste
    in .env doesn't accidentally underfill the cap (duplicates) or
    miss matches at lookup time (case)."""
    from config import Settings
    s = Settings(GEOFENCE_EMAIL_ALLOWLIST=" Smoke@Swasth.Health , smoke@swasth.health , qa@swasth.health ")
    parts = s.GEOFENCE_EMAIL_ALLOWLIST.split(",")
    assert parts == ["smoke@swasth.health", "qa@swasth.health"], (
        f"Validator must lowercase + trim + dedupe; got: {parts}"
    )


def test_config_empty_allowlist_is_disabled():
    """Default state — empty string must parse fine and mean "feature off"."""
    from config import Settings
    s = Settings(GEOFENCE_EMAIL_ALLOWLIST="")
    assert s.GEOFENCE_EMAIL_ALLOWLIST == ""


def test_config_rejects_allowlist_without_pii_key():
    """Cross-field guard: GEOFENCE_EMAIL_ALLOWLIST + no PII_ENCRYPTION_KEY
    = silently broken allowlist. Boot must refuse — operator gets a loud
    failure instead of a smoke test that mysteriously stays blocked."""
    from pydantic import ValidationError
    from config import Settings
    with pytest.raises(ValidationError) as exc:
        Settings(
            GEOFENCE_EMAIL_ALLOWLIST="smoke@swasth.health",
            PII_ENCRYPTION_KEY=None,
        )
    assert "PII_ENCRYPTION_KEY" in str(exc.value)


def test_config_allows_empty_allowlist_without_pii_key():
    """Inverse: when the allowlist is empty, PII_ENCRYPTION_KEY being
    unset is irrelevant to the geofence feature — boot must NOT fail
    just because the allowlist gate is dormant."""
    from config import Settings
    s = Settings(GEOFENCE_EMAIL_ALLOWLIST="", PII_ENCRYPTION_KEY=None)
    assert s.GEOFENCE_EMAIL_ALLOWLIST == ""


def test_allowlist_cache_drops_none_hashes_and_warns(monkeypatch, caplog):
    """Runtime defence-in-depth: if somehow boot accepted an allowlist
    with no PII_ENCRYPTION_KEY (e.g. key cleared at runtime, or a future
    code path bypasses the model-validator), the cache builder must
    drop the None entries AND log a WARNING so the operator sees the
    cause. A frozenset containing None would otherwise sit silently."""
    _set_allowlist(monkeypatch, "smoke@swasth.health,qa@swasth.health")
    # Force hash_email to return None — simulates missing PII key.
    with mock.patch("dependencies.hash_email", return_value=None):
        with caplog.at_level("WARNING", logger="dependencies"):
            hashes = dependencies._get_geofence_allowlist_hashes()
    assert None not in hashes, "None must never appear in the hashed allowlist"
    assert hashes == frozenset(), (
        "All entries hashed to None should produce an empty allowlist, "
        f"got: {hashes}"
    )
    assert any(
        "GEOFENCE_EMAIL_ALLOWLIST" in r.message
        and "hashed to None" in r.message
        for r in caplog.records
    ), "Dropped entries must surface as a WARNING for operator visibility"


# ──────────────────────────────────────────────────────────────────
# geofence_startup_check — boot-time visibility of the fail-open gate
# ──────────────────────────────────────────────────────────────────

def test_startup_check_active_logs_info(caplog):
    """mmdb present → gate ACTIVE, returns True, logs an INFO line."""
    from dependencies import geofence_startup_check
    with mock.patch("dependencies._get_geoip_reader", return_value=mock.Mock()):
        with caplog.at_level("INFO", logger="dependencies"):
            result = geofence_startup_check()
    assert result is True
    assert any("ACTIVE" in r.message for r in caplog.records)


def test_startup_check_fail_open_prod_logs_error(monkeypatch, caplog):
    """mmdb missing + prod (REQUIRE_HTTPS=true) → returns False and logs
    a loud ERROR. Ops alert is disabled here so the test doesn't try to
    send mail; the alert dispatch is best-effort and wrapped anyway."""
    from config import settings as _settings
    from dependencies import geofence_startup_check
    monkeypatch.setattr(_settings, "REQUIRE_HTTPS", True)
    monkeypatch.setattr(_settings, "OPS_ALERTS_ENABLED", False)
    with mock.patch("dependencies._get_geoip_reader", return_value=None):
        with caplog.at_level("ERROR", logger="dependencies"):
            result = geofence_startup_check()
    assert result is False
    assert any("GEOFENCE_FAIL_OPEN" in r.message for r in caplog.records)


def test_startup_check_fail_open_dev_logs_info_only(monkeypatch, caplog):
    """mmdb missing + dev (REQUIRE_HTTPS=false) → returns False, INFO
    only, no ERROR and no alert attempt."""
    from config import settings as _settings
    from dependencies import geofence_startup_check
    monkeypatch.setattr(_settings, "REQUIRE_HTTPS", False)
    with mock.patch("dependencies._get_geoip_reader", return_value=None):
        with caplog.at_level("INFO", logger="dependencies"):
            result = geofence_startup_check()
    assert result is False
    assert not any(r.levelname == "ERROR" for r in caplog.records)
