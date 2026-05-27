"""Public share-to-install landing page.

Serves the HTML target of WhatsApp-shared invite links. The flow:

    Doctor / patient taps "Share Swasth" in the app
        → app calls share_plus with the URL https://api.swasth.health/invite
        → recipient gets that URL in WhatsApp
        → tapping it lands here
        → we smart-redirect based on User-Agent:
            Android → Play Store listing (or internal-testing URL until live)
            iOS     → App Store listing (or TestFlight URL)
            other   → web app at https://swasth.health

Zero PII, zero DB writes. If we ever add per-invite tracking (referral
codes, doctor attribution, etc.) it should live in a NEW endpoint
(/invite/{token}) so this baseline path stays unauthenticated and
cacheable.

Why we host this ourselves instead of a third-party smart-link service:
   - DPDPA — no patient/doctor identifiers leave the Swasth domain.
   - One URL we control means we can flip the Play Store / App Store
     targets via env vars without an app update.
   - We can serve the correct assetlinks.json + apple-app-site-
     association from the same host, which is what Android App Links
     and iOS Universal Links require for direct-into-app open.
"""
import json
import logging
import os

from urllib.parse import urlparse
from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse, RedirectResponse
from limiter import limiter

from config import settings

logger = logging.getLogger(__name__)
router = APIRouter()

# Default fallback if both device-specific and web-default URLs are unsafe/missing.
# Hardcoded to a known-safe apex domain.
_FINAL_SAFE_FALLBACK = "https://swasth.health"


def _is_safe_url(url: str) -> bool:
    """Validate that the URL uses an allowed scheme (http/https).
    
    Prevents 'open redirect' vulnerabilities where a malicious URL 
    (e.g. javascript:alert(1)) could be injected via environment variables.
    """
    if not url:
        return False
    try:
        parsed = urlparse(url)
        return parsed.scheme in ("http", "https")
    except Exception:
        return False


def _resolve_target(user_agent: str) -> str:
    """Pick the right store / web URL for the requesting device.
    
    Note: PLAY_STORE_URL and APP_STORE_URL are legacy aliases. 
    # TODO: remove after SHARE_ANDROID_URL / SHARE_IOS_URL are confirmed set in all envs.
    """
    ua = (user_agent or "").lower()

    if "android" in ua:
        target = (
            settings.SHARE_ANDROID_URL
            or settings.PLAY_STORE_URL
            or settings.SHARE_WEB_URL
        )
        if settings.PLAY_STORE_URL and not settings.SHARE_ANDROID_URL:
            logger.warning("Legacy PLAY_STORE_URL is set. Please migrate to SHARE_ANDROID_URL.")
    elif any(x in ua for x in ("iphone", "ipad", "ipod")):
        target = (
            settings.SHARE_IOS_URL
            or settings.APP_STORE_URL
            or settings.SHARE_WEB_URL
        )
        if settings.APP_STORE_URL and not settings.SHARE_IOS_URL:
            logger.warning("Legacy APP_STORE_URL is set. Please migrate to SHARE_IOS_URL.")
    else:
        target = settings.SHARE_WEB_URL

    # C1: Ensure even the fallback is validated.
    if not _is_safe_url(target):
        if _is_safe_url(settings.SHARE_WEB_URL):
            return settings.SHARE_WEB_URL
        return _FINAL_SAFE_FALLBACK
        
    return target


@router.get("/invite", include_in_schema=False)
@limiter.limit("60/minute")
def share_invite_landing(request: Request):
    """Smart-redirect entry point shared via WhatsApp / SMS.

    Returns a 301 (Moved Permanently) to the right store/web URL for 
    the device. This is a stable redirect that can be cached by CDNs 
    and browsers for 5 min.
    """
    target = _resolve_target(request.headers.get("user-agent", ""))
    return RedirectResponse(url=target, status_code=301)


@router.get(
    "/.well-known/assetlinks.json",
    include_in_schema=False,
)
@limiter.limit("30/minute")
def android_app_links_assetlinks(request: Request):
    """Android App Links manifest.

    Serves the JSON Google's verifier fetches when registering this
    domain to open the app directly (no chooser, no Play Store hop).
    The SHA-256 fingerprint MUST match the release-signing cert
    Play Console assigns when the app is enrolled in any track
    (internal, closed, open, production). Until the cert is known,
    we serve an empty array — verifier returns "not associated",
    which is correct and harmless. Once the cert is known, set
    SHARE_ANDROID_CERT_SHA256 in .env and re-deploy.
    """
    # C2: Use the real default from settings to avoid inconsistencies.
    package = settings.ANDROID_PACKAGE_NAME
    cert = getattr(settings, "SHARE_ANDROID_CERT_SHA256", "") or ""

    # Build via json.dumps — never f-string interpolation. A mis-paste
    # from Play Console (stray double-quote, backslash, control char)
    # would produce invalid JSON OR open an injection surface if a
    # client trusted the structure. json.dumps escapes correctly
    # for every input and we serve the result verbatim.
    if not cert:
        payload: list = []
    else:
        payload = [{
            "relation": ["delegate_permission/common.handle_all_urls"],
            "target": {
                "namespace": "android_app",
                "package_name": package,
                "sha256_cert_fingerprints": [cert],
            },
        }]
    return JSONResponse(content=payload)
