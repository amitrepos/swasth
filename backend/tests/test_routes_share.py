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
# UA strings used across the suite
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


# ──────────────────────────────────────────────────────────────────
# Settings-mock helper — reviewer Issue 4
# ──────────────────────────────────────────────────────────────────
# `mock.patch("routes_share.settings")` replaces the whole settings
# object; any attribute the test does not explicitly set falls back to
# a fresh MagicMock, which is truthy and is NOT None. That used to let
# tests pass for the wrong reason — e.g. the legacy-fallback tests did
# not set the modern alias and the resolver picked a MagicMock as a
# truthy value, which then failed _is_safe_url (no scheme) and the
# test happened to assert the right outcome via that broken path.
#
# This helper returns a MagicMock with EVERY share-related attribute
# the resolver / assetlinks handler reads, defaulted to None. Tests
# override only what they care about and rely on `None` for the rest —
# matches how pydantic Settings actually behaves at runtime when an
# env var is unset.

_SHARE_ATTRS = {
    "SHARE_ANDROID_URL": None,
    "SHARE_IOS_URL": None,
    "SHARE_WEB_URL": "https://swasth.health",
    "PLAY_STORE_URL": None,
    "APP_STORE_URL": None,
    "ANDROID_PACKAGE_NAME": "com.swasth.app",
    "SHARE_ANDROID_CERT_SHA256": None,
}


def _settings_mock(**overrides):
    """Configure a MagicMock with all share-related settings attrs.

    Use as: ``with mock.patch("routes_share.settings") as s:
                _settings_mock_apply(s, SHARE_ANDROID_URL="...")``
    """
    base = dict(_SHARE_ATTRS)
    base.update(overrides)
    return base


def _apply(s, **overrides):
    """Apply default attrs + overrides onto a `mock.patch` target."""
    for k, v in _settings_mock(**overrides).items():
        setattr(s, k, v)


# ──────────────────────────────────────────────────────────────────
# /invite smart-redirect — core paths
# ──────────────────────────────────────────────────────────────────

def test_invite_route_is_mounted_at_root(client):
    """Tapping the WhatsApp link hits the bare host + /invite, not
    /api/invite. If someone moves this under the /api prefix the share
    URL in the Flutter ShareService stops resolving."""
    resp = client.get("/invite", follow_redirects=False)
    assert resp.status_code == 302


def test_invite_redirects_android_to_play_store_when_set(client):
    """When SHARE_ANDROID_URL is set in env, an Android UA must land
    on the Play Store listing (not the web fallback)."""
    play_url = "https://play.google.com/store/apps/details?id=com.swasth.app"
    with mock.patch("routes_share.settings") as s:
        _apply(s, SHARE_ANDROID_URL=play_url)
        resp = client.get(
            "/invite", headers={"User-Agent": _ANDROID_UA}, follow_redirects=False
        )
    assert resp.status_code == 302
    assert resp.headers["location"] == play_url


def test_invite_redirects_ios_to_app_store_when_set(client):
    """Same guarantee for iOS — must land on App Store, not Play."""
    app_url = "https://apps.apple.com/in/app/swasth/id1234567890"
    with mock.patch("routes_share.settings") as s:
        _apply(
            s,
            SHARE_ANDROID_URL="https://play.google.com/store/apps/details?id=com.swasth.app",
            SHARE_IOS_URL=app_url,
        )
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
        _apply(
            s,
            SHARE_ANDROID_URL="https://play.google.com/store/apps/details?id=com.swasth.app",
            SHARE_IOS_URL="https://apps.apple.com/in/app/swasth/id1234567890",
            SHARE_WEB_URL=web,
        )
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
        _apply(s, SHARE_WEB_URL=web)
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
        _apply(s, ANDROID_PACKAGE_NAME="com.swasth.app", SHARE_ANDROID_CERT_SHA256=None)
        resp = client.get("/.well-known/assetlinks.json")
    assert resp.status_code == 200
    assert resp.headers["content-type"].startswith("application/json")
    assert resp.text.strip() == "[]"


def test_assetlinks_includes_cert_when_set(client):
    """Once Play Console gives us the release SHA-256, the manifest
    must surface it so Android App Links verify."""
    cert = "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99"
    with mock.patch("routes_share.settings") as s:
        _apply(s, ANDROID_PACKAGE_NAME="com.swasth.app", SHARE_ANDROID_CERT_SHA256=cert)
        resp = client.get("/.well-known/assetlinks.json")
    assert resp.status_code == 200
    body = resp.text
    assert "com.swasth.app" in body
    assert cert in body
    assert "delegate_permission/common.handle_all_urls" in body


# ──────────────────────────────────────────────────────────────────
# JSON safety
# ──────────────────────────────────────────────────────────────────

def test_assetlinks_handles_malicious_input_safely(client):
    """A mis-paste from Play Console could include a stray double-quote,
    backslash, or control char. The previous f-string interpolation
    produced invalid JSON OR an injection surface for any consumer
    that trusted the structure. json.dumps escapes correctly. Test
    asserts the served body is parseable JSON for every input."""
    import json as _json

    with mock.patch("routes_share.settings") as s:
        _apply(
            s,
            ANDROID_PACKAGE_NAME='com.evil"app',      # stray double-quote
            SHARE_ANDROID_CERT_SHA256="AA\\BB:CC",    # backslash
        )
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
        _apply(s, ANDROID_PACKAGE_NAME="com.swasth.app", SHARE_ANDROID_CERT_SHA256=None)
        resp = client.get("/.well-known/assetlinks.json")
    assert resp.status_code == 200
    assert _json.loads(resp.text) == []


# ──────────────────────────────────────────────────────────────────
# Open-redirect defence — reviewer Issue 3 (netloc allowlist)
# ──────────────────────────────────────────────────────────────────

def test_invite_prevents_open_redirect_on_malicious_env_var(client):
    """A misconfigured SHARE_ANDROID_URL pointing at a non-allowlisted
    host (whether a phishing site or just a typo) must NOT make it
    through. Resolver falls back to SHARE_WEB_URL."""
    with mock.patch("routes_share.settings") as s:
        _apply(s, SHARE_ANDROID_URL="javascript:alert(1)")
        resp = client.get(
            "/invite", headers={"User-Agent": _ANDROID_UA}, follow_redirects=False
        )
    assert resp.status_code == 302
    assert resp.headers["location"] == "https://swasth.health"


def test_invite_blocks_https_phishing_host(client):
    """The scheme check alone is not enough — Issue 3 was that
    https://evil.com would pass with scheme-only validation. The
    netloc allowlist must now reject it."""
    with mock.patch("routes_share.settings") as s:
        _apply(s, SHARE_ANDROID_URL="https://evil.com?r=https://swasth.health")
        resp = client.get(
            "/invite", headers={"User-Agent": _ANDROID_UA}, follow_redirects=False
        )
    assert resp.status_code == 302
    # Must fall back to the safe web URL, NOT echo evil.com.
    assert "evil.com" not in resp.headers["location"]
    assert resp.headers["location"] == "https://swasth.health"


def test_invite_blocks_userinfo_bypass(client):
    """Common phishing bait: https://evil.com@play.google.com/x.
    Browsers DO honor the host after the @ (so the destination is
    actually play.google.com), but the URL-as-shown reads like it
    points at evil.com — a tell that has no legitimate reason in a
    store/web target. `_is_safe_url` rejects any URL with userinfo,
    so the resolver falls back to SHARE_WEB_URL."""
    with mock.patch("routes_share.settings") as s:
        _apply(s, SHARE_ANDROID_URL="https://evil.com@play.google.com/x")
        resp = client.get(
            "/invite", headers={"User-Agent": _ANDROID_UA}, follow_redirects=False
        )
    assert resp.status_code == 302
    # The userinfo-bearing URL must not be echoed back as the
    # Location header — falls back to the safe web URL.
    assert resp.headers["location"] == "https://swasth.health"


def test_invite_prevents_open_redirect_on_all_malicious_env_vars(client):
    """Even if SHARE_WEB_URL itself is malicious, the hardcoded
    _FINAL_SAFE_FALLBACK kicks in. No path lets evil through."""
    with mock.patch("routes_share.settings") as s:
        _apply(
            s,
            SHARE_ANDROID_URL="javascript:alert(1)",
            SHARE_WEB_URL="data:text/html,...",
        )
        resp = client.get(
            "/invite", headers={"User-Agent": _ANDROID_UA}, follow_redirects=False
        )
    assert resp.status_code == 302
    assert resp.headers["location"] == "https://swasth.health"


def test_is_safe_url_accepts_swasth_subdomains_and_stores():
    """Direct unit-level coverage of the allowlist policy."""
    from routes_share import _is_safe_url

    assert _is_safe_url("https://swasth.health") is True
    assert _is_safe_url("https://app.swasth.health") is True
    assert _is_safe_url("https://staging.swasth.health/path?q=1") is True
    assert _is_safe_url("https://play.google.com/store/apps/details?id=x") is True
    assert _is_safe_url("https://apps.apple.com/in/app/swasth/id123") is True


def test_is_safe_url_rejects_lookalikes_and_bad_schemes():
    """Lookalike domains, plain HTTP for stores, and non-HTTP schemes
    must all be rejected."""
    from routes_share import _is_safe_url

    # Lookalike — "notswasth.health" must not satisfy the suffix
    # check (the leading dot in _ALLOWED_SUFFIX prevents it).
    assert _is_safe_url("https://notswasth.health") is False
    assert _is_safe_url("https://swasth.health.evil.com") is False
    # Non-HTTP schemes.
    assert _is_safe_url("javascript:alert(1)") is False
    assert _is_safe_url("data:text/html,foo") is False
    assert _is_safe_url("ftp://swasth.health") is False
    # Empty / malformed.
    assert _is_safe_url("") is False
    assert _is_safe_url("not-a-url") is False


# ──────────────────────────────────────────────────────────────────
# Legacy alias fallback paths
# ──────────────────────────────────────────────────────────────────

def test_invite_falls_back_to_legacy_play_store_url(client):
    """If SHARE_ANDROID_URL is None but PLAY_STORE_URL is set, the
    redirect must use the legacy alias."""
    legacy_url = "https://play.google.com/store/apps/details?id=legacy.app"
    with mock.patch("routes_share.settings") as s:
        _apply(s, PLAY_STORE_URL=legacy_url)
        resp = client.get(
            "/invite", headers={"User-Agent": _ANDROID_UA}, follow_redirects=False
        )
    assert resp.status_code == 302
    assert resp.headers["location"] == legacy_url


def test_invite_falls_back_to_legacy_app_store_url(client):
    """Same for iOS / APP_STORE_URL."""
    legacy_url = "https://apps.apple.com/app/legacy/id123"
    with mock.patch("routes_share.settings") as s:
        _apply(s, APP_STORE_URL=legacy_url)
        resp = client.get(
            "/invite", headers={"User-Agent": _IPHONE_UA}, follow_redirects=False
        )
    assert resp.status_code == 302
    assert resp.headers["location"] == legacy_url


def test_legacy_alias_warning_logs_every_hit_no_dedup(client, caplog):
    """Reviewer Issue 1: the previous module-level booleans dedup'd the
    warning to once-ever which is (a) racy under concurrency and (b)
    silenced exactly the misconfiguration signal ops needs. Now we log
    on every hit. /invite is rate-limited at 60/min upstream so log
    noise is bounded.

    Asserts: two consecutive requests both emit the warning (proves
    dedup is gone). Disabled rate limiting in TESTING mode lets us
    fire both without hitting 429."""
    legacy_url = "https://play.google.com/store/apps/details?id=legacy.app"
    with mock.patch("routes_share.settings") as s:
        _apply(s, PLAY_STORE_URL=legacy_url)
        with caplog.at_level("WARNING", logger="routes_share"):
            client.get("/invite", headers={"User-Agent": _ANDROID_UA}, follow_redirects=False)
            client.get("/invite", headers={"User-Agent": _ANDROID_UA}, follow_redirects=False)
    msgs = [r.message for r in caplog.records if "PLAY_STORE_URL" in r.message]
    assert len(msgs) >= 2, (
        f"Expected ≥2 warnings (one per hit), got {len(msgs)}. "
        "The one-time-warn dedup regression is back."
    )


# ──────────────────────────────────────────────────────────────────
# Limiter wiring
# ──────────────────────────────────────────────────────────────────

def test_share_invite_uses_shared_limiter_for_429_not_500(client):
    """Ensure routes_share imports the SAME limiter instance the FastAPI
    app registers — otherwise a local limiter would 500 on
    RateLimitExceeded instead of 429."""
    from limiter import limiter

    import routes_share
    assert routes_share.limiter is limiter

    from slowapi.errors import RateLimitExceeded
    from main import app

    assert RateLimitExceeded in app.exception_handlers
    from slowapi import _rate_limit_exceeded_handler
    assert app.exception_handlers[RateLimitExceeded] == _rate_limit_exceeded_handler
