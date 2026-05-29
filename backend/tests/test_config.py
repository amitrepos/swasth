import pytest
from pydantic import ValidationError
from config import Settings

def test_settings_valid_urls():
    """Verify that valid approved URLs pass validation."""
    settings = Settings(
        SHARE_ANDROID_URL="https://play.google.com/store/apps/details?id=com.swasth.app",
        SHARE_IOS_URL="https://apps.apple.com/in/app/swasth/id123",
        SHARE_WEB_URL="https://swasth.health",
        PLAY_STORE_URL="https://play.google.com/store/apps/details?id=com.swasth.app",
        APP_STORE_URL="https://apps.apple.com/in/app/swasth/id123"
    )
    assert settings.SHARE_ANDROID_URL == "https://play.google.com/store/apps/details?id=com.swasth.app"
    assert settings.SHARE_WEB_URL == "https://swasth.health"

def test_settings_invalid_scheme():
    """Verify that non-HTTPS URLs raise ValidationError."""
    with pytest.raises(ValidationError) as excinfo:
        Settings(SHARE_WEB_URL="http://swasth.health")
    
    assert "SHARE_WEB_URL must be a valid, secure HTTPS URL" in str(excinfo.value)
    assert "got: 'http://swasth.health'" in str(excinfo.value)

def test_settings_invalid_host():
    """Verify that non-approved domains raise ValidationError."""
    with pytest.raises(ValidationError) as excinfo:
        Settings(SHARE_ANDROID_URL="https://evil.com/malware")
    
    assert "SHARE_ANDROID_URL must be a valid, secure HTTPS URL" in str(excinfo.value)
    assert "got: 'https://evil.com/malware'" in str(excinfo.value)

def test_settings_subdomain_allowed():
    """Verify that subdomains of swasth.health are allowed."""
    settings = Settings(SHARE_WEB_URL="https://staging.swasth.health")
    assert settings.SHARE_WEB_URL == "https://staging.swasth.health"

def test_settings_none_allowed_for_optional():
    """Verify that None/empty strings are allowed for optional URL fields."""
    settings = Settings(
        SHARE_ANDROID_URL=None,
        SHARE_IOS_URL="",
        PLAY_STORE_URL=None,
        APP_STORE_URL=""
    )
    assert settings.SHARE_ANDROID_URL is None
    assert settings.SHARE_IOS_URL is None # Normalized to None by validator


def test_settings_userinfo_bypass_rejected():
    """CRITICAL: a URL whose hostname is allowlisted but carries userinfo
    (user:pass@host) must be rejected. urllib's parsed.hostname strips
    userinfo, so naively trusting `host in allowlist` would let an
    attacker craft https://evil.com:443@play.google.com/... which renders
    in the browser as evil.com. is_safe_url explicitly rejects userinfo
    via parsed.username/password; this test pins that defence."""
    with pytest.raises(ValidationError) as excinfo:
        Settings(
            SHARE_ANDROID_URL="https://evil.com:443@play.google.com/store/apps/details?id=com.swasth.app"
        )
    assert "SHARE_ANDROID_URL must be a valid, secure HTTPS URL" in str(excinfo.value)


def test_settings_suffix_bypass_rejected():
    """CRITICAL: the suffix-allowlist `.swasth.health` must not match
    `notswasth.health`. The leading dot in _ALLOWED_SUFFIX is the
    defence; this test pins it. Without the leading dot, an attacker
    could register notswasth.health and pass validation."""
    with pytest.raises(ValidationError) as excinfo:
        Settings(SHARE_WEB_URL="https://notswasth.health")
    assert "SHARE_WEB_URL must be a valid, secure HTTPS URL" in str(excinfo.value)


def test_settings_share_web_url_empty_rejected():
    """SHARE_WEB_URL is the always-on web fallback (non-Optional str).
    Empty string must be rejected, not coerced to None — coercion would
    violate the declared type and make `settings.SHARE_WEB_URL` unsafe
    downstream in routes_share._resolve_target."""
    with pytest.raises(ValidationError) as excinfo:
        Settings(SHARE_WEB_URL="")
    assert "SHARE_WEB_URL must be a non-empty HTTPS URL" in str(excinfo.value)
