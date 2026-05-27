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

# Flags to ensure legacy warnings only print once to avoid log spam (Issue 2).
_warned_play_store_alias = False
_warned_app_store_alias = False


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
    global _warned_play_store_alias
    global _warned_app_store_alias

    ua = (user_agent or "").lower()

    if "android" in ua:
        if settings.SHARE_ANDROID_URL:
            target = settings.SHARE_ANDROID_URL
        elif settings.PLAY_STORE_URL:
            target = settings.PLAY_STORE_URL
            if not _warned_play_store_alias:
                logger.warning("Legacy PLAY_STORE_URL is set. Please migrate to SHARE_ANDROID_URL.")
                _warned_play_store_alias = True
        else:
            target = settings.SHARE_WEB_URL
            
    elif any(x in ua for x in ("iphone", "ipad", "ipod")):
        if settings.SHARE_IOS_URL:
            target = settings.SHARE_IOS_URL
        elif settings.APP_STORE_URL:
            target = settings.APP_STORE_URL
            if not _warned_app_store_alias:
                logger.warning("Legacy APP_STORE_URL is set. Please migrate to SHARE_IOS_URL.")
                _warned_app_store_alias = True
        else:
            target = settings.SHARE_WEB_URL
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

    Uses a temporary redirect (302) during pre-launch because store
    destinations may change (web fallback → Play Store). 301s are 
    cached aggressively by browsers and WhatsApp link previews, which 
    can permanently pin old targets (Issue 1).
    """
    target = _resolve_target(request.headers.get("user-agent", ""))
    return RedirectResponse(url=target, status_code=302)


@router.get(
    "/.well-known/assetlinks.json",
    include_in_schema=False,
)
@limiter.limit("30/minute")
def android_app_links_assetlinks(request: Request):
    """Android App Links manifest.

    Serves the JSON Google's verifier fetches when registering this
    domain to open the app directly (no chooser, no Play Store hop).
    """
    # C2: Use the real default from settings to avoid inconsistencies.
    package = settings.ANDROID_PACKAGE_NAME
    # M3: Direct attribute access; Pydantic ensures it's set or None (Issue 3).
    cert = settings.SHARE_ANDROID_CERT_SHA256 or ""

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
