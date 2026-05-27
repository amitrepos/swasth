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
import os

from urllib.parse import urlparse
from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from limiter import limiter

from config import settings

router = APIRouter()

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
    """Pick the right store / web URL for the requesting device."""
    ua = (user_agent or "").lower()

    if "android" in ua:
        target = (
            settings.SHARE_ANDROID_URL
            or settings.PLAY_STORE_URL
            or settings.SHARE_WEB_URL
        )
    elif any(x in ua for x in ("iphone", "ipad", "ipod")):
        target = (
            settings.SHARE_IOS_URL
            or settings.APP_STORE_URL
            or settings.SHARE_WEB_URL
        )
    else:
        target = settings.SHARE_WEB_URL

    if not _is_safe_url(target):
        return settings.SHARE_WEB_URL
    return target


@router.get("/invite", include_in_schema=False)
@limiter.limit("60/minute")
def share_invite_landing(request: Request):
    """Smart-redirect entry point shared via WhatsApp / SMS.

    Returns a 302 to the right store/web URL for the device. Kept
    deliberately simple — no DB, no auth, no PII. Cacheable for 5 min
    at the CDN edge.
    """
    target = _resolve_target(request.headers.get("user-agent", ""))
    return RedirectResponse(url=target, status_code=302)


@router.get(
    "/.well-known/assetlinks.json",
    include_in_schema=False,
    response_class=HTMLResponse,
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
    package = getattr(settings, "ANDROID_PACKAGE_NAME", "com.example.swasth")
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
    return HTMLResponse(
        content=json.dumps(payload, separators=(",", ":")),
        media_type="application/json",
    )
