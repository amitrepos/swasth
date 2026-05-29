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
# truthy value, which then failed is_safe_url (no scheme) and the
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
    """Defense-in-depth test for the JSON-serialization layer.

    NOTE — this test mocks `routes_share.settings` directly, which
    BYPASSES the pydantic field validators in config.py. In real
    operation the validators reject:
      - ANDROID_PACKAGE_NAME containing non-package chars (`"` etc.)
      - SHARE_ANDROID_CERT_SHA256 that isn't 64 hex chars
    So the route never sees the values injected below in production —
    this test exists only to prove the *inner* JSON layer is safe even
    if the validators were ever weakened or bypassed.

    What we assert: the served body is valid JSON, structured as a
    list, and any special characters are properly escaped by
    json.dumps (not surfaced raw, which the old f-string interpolation
    would have done). We deliberately do NOT assert the raw mocked
    values are echoed in the parsed output — that would imply the
    route serves unvalidated certs to Google's verifier, which is
    misleading. The point is that *whatever* the route emits, it must
    be parseable JSON with no injection surface."""
    import json as _json

    with mock.patch("routes_share.settings") as s:
        _apply(
            s,
            ANDROID_PACKAGE_NAME='com.evil"app',      # stray double-quote
            SHARE_ANDROID_CERT_SHA256="AA\\BB:CC",    # backslash
        )
        resp = client.get("/.well-known/assetlinks.json")
    assert resp.status_code == 200
    # MUST parse — invalid JSON here would surface the
    # f-string-injection regression we are guarding against.
    parsed = _json.loads(resp.text)
    assert isinstance(parsed, list)
    # Structure check only — confirms the JSON shape survives weird
    # input. We do not assert verbatim echo of the (would-be-rejected)
    # mocked values; see docstring.
    assert len(parsed) == 1
    target = parsed[0].get("target", {})
    assert "package_name" in target
    assert "sha256_cert_fingerprints" in target
    assert isinstance(target["sha256_cert_fingerprints"], list)
    # Wire-level safety check: the raw response bytes must not contain
    # an unescaped " inside the package_name value (that would prove
    # the f-string injection regressed). json.dumps escapes it as \".
    assert '"com.evil"app"' not in resp.text


def test_assetlinks_empty_state_is_valid_json(client):
    """The empty-cert branch must also return parseable JSON, not a
    bare "[]" string we hand-rolled."""
    import json as _json

    with mock.patch("routes_share.settings") as s:
        _apply(s, ANDROID_PACKAGE_NAME="com.swasth.app", SHARE_ANDROID_CERT_SHA256=None)
        resp = client.get("/.well-known/assetlinks.json")
    assert resp.status_code == 200
    assert _json.loads(resp.text) == []


def test_assetlinks_sets_cache_control_for_rotation_window(client):
    """Reviewer M1: Google's verifier caches assetlinks.json for up to
    24h by default. Without a Cache-Control header we have no way to
    roll out a cert rotation (new signing key, Play Console re-sign)
    without a multi-day App-Links outage. max-age=3600 caps the cache
    at 1 hour."""
    with mock.patch("routes_share.settings") as s:
        _apply(s, ANDROID_PACKAGE_NAME="com.swasth.app", SHARE_ANDROID_CERT_SHA256=None)
        resp = client.get("/.well-known/assetlinks.json")
    assert resp.status_code == 200
    cc = resp.headers.get("cache-control", "")
    assert "max-age=3600" in cc, (
        f"Cache-Control header missing or wrong: {cc!r}. Verifier will "
        "cache stale manifests for up to 24h after a cert rotation."
    )


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
    store/web target. `is_safe_url` rejects any URL with userinfo,
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
    FINAL_SAFE_FALLBACK kicks in. No path lets evil through."""
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


def testis_safe_url_accepts_swasth_subdomains_and_stores():
    """Direct unit-level coverage of the allowlist policy."""
    from config import is_safe_url

    assert is_safe_url("https://swasth.health") is True
    assert is_safe_url("https://app.swasth.health") is True
    assert is_safe_url("https://staging.swasth.health/path?q=1") is True
    assert is_safe_url("https://play.google.com/store/apps/details?id=x") is True
    assert is_safe_url("https://apps.apple.com/in/app/swasth/id123") is True


def testis_safe_url_rejects_lookalikes_and_bad_schemes():
    """Lookalike domains, plain HTTP for stores, and non-HTTPS schemes
    must all be rejected."""
    from config import is_safe_url

    # Lookalike — "notswasth.health" must not satisfy the suffix
    # check (the leading dot in _ALLOWED_SUFFIX prevents it).
    assert is_safe_url("https://notswasth.health") is False
    assert is_safe_url("https://swasth.health.evil.com") is False
    # Non-HTTPS schemes — HTTP is now also rejected (C1).
    assert is_safe_url("javascript:alert(1)") is False
    assert is_safe_url("data:text/html,foo") is False
    assert is_safe_url("ftp://swasth.health") is False
    # Empty / malformed.
    assert is_safe_url("") is False
    assert is_safe_url("not-a-url") is False


def testis_safe_url_rejects_plain_http_even_on_allowed_host():
    """Reviewer C1: plaintext http:// over a plaintext request lets
    a MITM strip TLS and intercept the redirect. The store URLs and
    swasth.health all serve HTTPS at their end, so http:// here can
    only be a misconfiguration or an attack. Reject every http:// —
    no exception for any host."""
    from config import is_safe_url

    assert is_safe_url("http://swasth.health") is False
    assert is_safe_url("http://app.swasth.health") is False
    assert is_safe_url("http://play.google.com/store/apps/details?id=x") is False
    assert is_safe_url("http://apps.apple.com/in/app/swasth/id123") is False


def test_invite_blocks_http_share_web_url(client):
    """If SHARE_WEB_URL is mistakenly configured as http://, resolver
    must fall through to FINAL_SAFE_FALLBACK (the hardcoded https
    constant) rather than serving the plaintext URL."""
    with mock.patch("routes_share.settings") as s:
        _apply(s, SHARE_WEB_URL="http://swasth.health")
        resp = client.get(
            "/invite", headers={"User-Agent": _DESKTOP_UA}, follow_redirects=False
        )
    assert resp.status_code == 302
    # FINAL_SAFE_FALLBACK is hardcoded https://swasth.health.
    assert resp.headers["location"] == "https://swasth.health"
    assert not resp.headers["location"].startswith("http://")


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

# ──────────────────────────────────────────────────────────────────
# Settings format validators — reviewer M2
# ──────────────────────────────────────────────────────────────────
# These are unit tests on the Settings class, not the route. They
# instantiate Settings directly with the field overridden — bypassing
# the .env file — to assert that bad values are rejected at startup.

def test_settings_rejects_invalid_android_package_name():
    """Garbage in ANDROID_PACKAGE_NAME must fail at startup, not
    silently serve a manifest Google's verifier will reject."""
    import pytest as _pytest
    from pydantic import ValidationError
    from config import Settings

    for bad in [
        "",              # empty
        "com",           # single segment
        "1com.swasth",   # segment starts with digit
        "com..swasth",   # empty segment
        "com.swasth!",   # invalid char
        "com.swasth\n",  # control char
        "com swasth",    # space
    ]:
        with _pytest.raises(ValidationError):
            Settings(ANDROID_PACKAGE_NAME=bad)


def test_settings_accepts_valid_android_package_name():
    """Realistic values: dotted identifiers with letters / digits /
    underscores per segment."""
    from config import Settings

    for ok in [
        "com.swasth.app",
        "com.swasth",
        "io.flutter.plugins.test_app",
        "com.swasth.app.staging",
    ]:
        s = Settings(ANDROID_PACKAGE_NAME=ok)
        assert s.ANDROID_PACKAGE_NAME == ok


def test_settings_accepts_cert_sha256_in_both_formats():
    """Play Console renders the fingerprint colon-separated by
    default; operators sometimes strip the colons before pasting.
    Both forms must work; output normalizes to colon-separated
    upper-case for downstream consumers."""
    from config import Settings

    expected = "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99"
    continuous = expected.replace(":", "")
    lower = expected.lower()

    for form in (expected, continuous, lower):
        s = Settings(SHARE_ANDROID_CERT_SHA256=form)
        assert s.SHARE_ANDROID_CERT_SHA256 == expected, (
            f"Cert format {form!r} did not normalize to canonical "
            f"colon-separated upper-case: got {s.SHARE_ANDROID_CERT_SHA256!r}"
        )


def test_settings_rejects_invalid_cert_sha256():
    """Bad fingerprints must fail at startup."""
    import pytest as _pytest
    from pydantic import ValidationError
    from config import Settings

    for bad in [
        "tooshort",
        "AA:BB",
        "ZZ" * 32,             # non-hex
        "AA" * 31,             # 62 chars, not 64
        "AA" * 33,             # 66 chars, not 64
        "AA:BB:CC:" + ("AA" * 30),  # right length minus the trailing bytes
    ]:
        with _pytest.raises(ValidationError):
            Settings(SHARE_ANDROID_CERT_SHA256=bad)


def test_settings_accepts_null_cert_sha256():
    """None / empty string → None (pre-launch state). Must NOT raise."""
    from config import Settings

    assert Settings(SHARE_ANDROID_CERT_SHA256=None).SHARE_ANDROID_CERT_SHA256 is None
    assert Settings(SHARE_ANDROID_CERT_SHA256="").SHARE_ANDROID_CERT_SHA256 is None


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
