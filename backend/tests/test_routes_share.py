"""Tests for the public /invite smart-redirect + Android App Links manifest.

The /invite route is hit by WhatsApp recipients tapping shared links.
It MUST:
  - never require auth
  - never touch the DB
  - never echo any PII back to the caller
  - resolve to the right store/web target per User-Agent
  - be served from the ROOT (not under /api), because assetlinks.json
    has to live at /.well-known/assetlinks.json on the apex of the
    domain that's claiming Android App Links
"""
from unittest import mock


# ──────────────────────────────────────────────────────────────────
# /invite smart-redirect
# ──────────────────────────────────────────────────────────────────

_ANDROID_UA = (
    "Mozilla/5.0 (Linux; Android 14; Pixel 7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36"
)
_IPHONE_UA = (
    "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) "
    "AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
)
_DESKTOP_UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36"
)


def test_invite_route_is_mounted_at_root(client):
    """Tapping the WhatsApp link hits the bare host + /invite, not
    /api/invite. If someone moves this under the /api prefix the share
    URL in the Flutter ShareService stops resolving."""
    resp = client.get("/invite", follow_redirects=False)
    assert resp.status_code == 302, (
        f"Expected 302 redirect from /invite, got {resp.status_code}: {resp.text}. "
        "If this is 404, the routes_share router is not mounted at root."
    )


def test_invite_redirects_android_to_play_store_when_set(client):
    """When SHARE_ANDROID_URL is set in env, an Android UA must land
    on the Play Store listing (not the web fallback)."""
    play_url = "https://play.google.com/store/apps/details?id=com.swasth.app"
    with mock.patch("routes_share.settings") as s:
        s.SHARE_ANDROID_URL = play_url
        s.SHARE_IOS_URL = None
        s.SHARE_WEB_URL = "https://swasth.health"
        s.PLAY_STORE_URL = None
        s.APP_STORE_URL = None
        resp = client.get(
            "/invite", headers={"User-Agent": _ANDROID_UA}, follow_redirects=False
        )
    assert resp.status_code == 302
    assert resp.headers["location"] == play_url


def test_invite_redirects_ios_to_app_store_when_set(client):
    """Same guarantee for iOS — must land on App Store, not Play."""
    app_url = "https://apps.apple.com/in/app/swasth/id1234567890"
    with mock.patch("routes_share.settings") as s:
        s.SHARE_ANDROID_URL = "https://play.google.com/store/apps/details?id=com.swasth.app"
        s.SHARE_IOS_URL = app_url
        s.SHARE_WEB_URL = "https://swasth.health"
        s.PLAY_STORE_URL = None
        s.APP_STORE_URL = None
        resp = client.get(
            "/invite", headers={"User-Agent": _IPHONE_UA}, follow_redirects=False
        )
    assert resp.status_code == 302
    assert resp.headers["location"] == app_url


def test_invite_desktop_lands_on_web(client):
    """Desktop / unrecognized UA must always fall through to the web
    app — the Play Store URL is meaningless on a laptop."""
    web = "https://swasth.health"
    with mock.patch("routes_share.settings") as s:
        s.SHARE_ANDROID_URL = "https://play.google.com/..."
        s.SHARE_IOS_URL = "https://apps.apple.com/..."
        s.SHARE_WEB_URL = web
        s.PLAY_STORE_URL = None
        s.APP_STORE_URL = None
        resp = client.get(
            "/invite", headers={"User-Agent": _DESKTOP_UA}, follow_redirects=False
        )
    assert resp.status_code == 302
    assert resp.headers["location"] == web


def test_invite_android_falls_back_to_web_when_play_store_unset(client):
    """Pre-launch state: no Play Store URL yet. Android UA must still
    work — landing on the web app — not 500 or empty redirect."""
    web = "https://swasth.health"
    with mock.patch("routes_share.settings") as s:
        s.SHARE_ANDROID_URL = None
        s.SHARE_IOS_URL = None
        s.SHARE_WEB_URL = web
        s.PLAY_STORE_URL = None
        s.APP_STORE_URL = None
        resp = client.get(
            "/invite", headers={"User-Agent": _ANDROID_UA}, follow_redirects=False
        )
    assert resp.status_code == 302
    assert resp.headers["location"] == web


def test_invite_handles_missing_user_agent_header(client):
    """Bots / curl without a UA must not crash the endpoint."""
    resp = client.get("/invite", headers={"User-Agent": ""}, follow_redirects=False)
    assert resp.status_code == 302  # falls through to web fallback


# ──────────────────────────────────────────────────────────────────
# /.well-known/assetlinks.json
# ──────────────────────────────────────────────────────────────────

def test_assetlinks_returns_empty_array_when_cert_unset(client):
    """Pre-Play-Console state: no signing cert SHA known yet.
    Returning [] is the correct App-Links manifest for 'no associated
    app' — Google's verifier reads it cleanly and reports the domain
    as not claimed."""
    with mock.patch("routes_share.settings") as s:
        s.ANDROID_PACKAGE_NAME = "com.swasth.app"
        s.SHARE_ANDROID_CERT_SHA256 = None
        resp = client.get("/.well-known/assetlinks.json")
    assert resp.status_code == 200
    assert resp.headers["content-type"].startswith("application/json")
    assert resp.text.strip() == "[]"


def test_assetlinks_includes_cert_when_set(client):
    """Once Play Console gives us the release SHA-256, the manifest
    must surface it so Android App Links verify."""
    cert = "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99"
    with mock.patch("routes_share.settings") as s:
        s.ANDROID_PACKAGE_NAME = "com.swasth.app"
        s.SHARE_ANDROID_CERT_SHA256 = cert
        resp = client.get("/.well-known/assetlinks.json")
    assert resp.status_code == 200
    body = resp.text
    assert "com.swasth.app" in body
    assert cert in body
    assert "delegate_permission/common.handle_all_urls" in body


# ──────────────────────────────────────────────────────────────────
# JSON safety — reviewer Issue 1
# ──────────────────────────────────────────────────────────────────

def test_assetlinks_handles_malicious_input_safely(client):
    """A mis-paste from Play Console could include a stray double-quote,
    backslash, or control char. The previous f-string interpolation
    produced invalid JSON OR an injection surface for any consumer
    that trusted the structure. json.dumps escapes correctly. Test
    asserts the served body is parseable JSON for every input."""
    import json as _json

    with mock.patch("routes_share.settings") as s:
        s.ANDROID_PACKAGE_NAME = 'com.evil"app'      # stray double-quote
        s.SHARE_ANDROID_CERT_SHA256 = "AA\\BB:CC"    # backslash
        resp = client.get("/.well-known/assetlinks.json")
    assert resp.status_code == 200
    # MUST parse — invalid JSON would crash here and surface the
    # f-string-injection regression.
    parsed = _json.loads(resp.text)
    assert isinstance(parsed, list)
    assert parsed[0]["target"]["package_name"] == 'com.evil"app'
    assert parsed[0]["target"]["sha256_cert_fingerprints"] == ["AA\\BB:CC"]


def test_assetlinks_empty_state_is_valid_json(client):
    """The empty-cert branch must also return parseable JSON, not a
    bare "[]" string we hand-rolled."""
    import json as _json

    with mock.patch("routes_share.settings") as s:
        s.ANDROID_PACKAGE_NAME = "com.swasth.app"
        s.SHARE_ANDROID_CERT_SHA256 = None
        resp = client.get("/.well-known/assetlinks.json")
    assert resp.status_code == 200
    assert _json.loads(resp.text) == []


# ──────────────────────────────────────────────────────────────────
# Security & Rate Limiting — Reviewer Issues C1, C2
# ──────────────────────────────────────────────────────────────────

def test_invite_prevents_open_redirect_on_malicious_env_var(client):
    """C1 — Malicious input in environment variables (e.g. javascript:)
    must be blocked. Fallback to settings.SHARE_WEB_URL."""
    with mock.patch("routes_share.settings") as s:
        # Attacker-controlled / misconfigured value
        s.SHARE_ANDROID_URL = "javascript:alert(1)"
        s.SHARE_WEB_URL = "https://swasth.health"
        s.PLAY_STORE_URL = None
        s.APP_STORE_URL = None
        
        resp = client.get(
            "/invite", headers={"User-Agent": _ANDROID_UA}, follow_redirects=False
        )
    
    assert resp.status_code == 302
    # Should NOT be the javascript: URL
    assert resp.headers["location"] == "https://swasth.health"


def test_invite_falls_back_to_legacy_play_store_url(client):
    """M5 — If SHARE_ANDROID_URL is None but PLAY_STORE_URL is set,
    the redirect must use the legacy alias."""
    legacy_url = "https://play.google.com/store/apps/details?id=legacy.app"
    with mock.patch("routes_share.settings") as s:
        s.SHARE_ANDROID_URL = None
        s.PLAY_STORE_URL = legacy_url
        s.SHARE_WEB_URL = "https://swasth.health"
        resp = client.get(
            "/invite", headers={"User-Agent": _ANDROID_UA}, follow_redirects=False
        )
    assert resp.status_code == 302
    assert resp.headers["location"] == legacy_url


def test_invite_falls_back_to_legacy_app_store_url(client):
    """M5 — Same for iOS/APP_STORE_URL."""
    legacy_url = "https://apps.apple.com/app/legacy/id123"
    with mock.patch("routes_share.settings") as s:
        s.SHARE_IOS_URL = None
        s.APP_STORE_URL = legacy_url
        s.SHARE_WEB_URL = "https://swasth.health"
        resp = client.get(
            "/invite", headers={"User-Agent": _IPHONE_UA}, follow_redirects=False
        )
    assert resp.status_code == 302
    assert resp.headers["location"] == legacy_url


def test_share_invite_uses_shared_limiter_for_429_not_500(client):
    """C2, M6 — Ensure we are using the shared limiter. When the limit is
    tripped, we must return 429 (Rate Limit Exceeded) via the global
    handler in main.py, NOT a 500 (AttributeError) from an isolated
    limiter with no registered handler."""
    from limiter import limiter

    # 1. Verification of singleton (fixes C2)
    import routes_share
    assert routes_share.limiter is limiter

    # 2. Verification of global handler registration (fixes M6)
    # Check that the FastAPI app has the correct exception handler registered
    from slowapi.errors import RateLimitExceeded
    from main import app

    assert RateLimitExceeded in app.exception_handlers
    # The handler is _rate_limit_exceeded_handler from slowapi
    from slowapi import _rate_limit_exceeded_handler
    assert app.exception_handlers[RateLimitExceeded] == _rate_limit_exceeded_handler

