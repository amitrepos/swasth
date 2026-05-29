import logging

from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse, RedirectResponse
from limiter import limiter

from config import settings, is_safe_url, FINAL_SAFE_FALLBACK

logger = logging.getLogger(__name__)
router = APIRouter()


# TODO: remove PLAY_STORE_URL / APP_STORE_URL legacy aliases below once
#       SHARE_ANDROID_URL / SHARE_IOS_URL are confirmed set in every
#       deployed environment.
def _resolve_target(user_agent: str) -> str:
    """Pick the right store / web URL for the requesting device."""
    ua = (user_agent or "").lower()

    if "android" in ua:
        if settings.SHARE_ANDROID_URL:
            target = settings.SHARE_ANDROID_URL
        elif settings.PLAY_STORE_URL:
            target = settings.PLAY_STORE_URL
            # Intentional: warn on every hit, no dedup. /invite is
            # rate-limited at 60/min upstream so log noise is bounded,
            # and the message is precisely the "you have legacy config,
            # fix it" signal ops needs — silencing after the first hit
            # would let the misconfiguration drift unnoticed.
            logger.warning(
                "Legacy PLAY_STORE_URL is set. Please migrate to SHARE_ANDROID_URL."
            )
        else:
            target = settings.SHARE_WEB_URL

    elif any(x in ua for x in ("iphone", "ipad", "ipod")):
        if settings.SHARE_IOS_URL:
            target = settings.SHARE_IOS_URL
        elif settings.APP_STORE_URL:
            target = settings.APP_STORE_URL
            logger.warning(
                "Legacy APP_STORE_URL is set. Please migrate to SHARE_IOS_URL."
            )
        else:
            target = settings.SHARE_WEB_URL
    else:
        target = settings.SHARE_WEB_URL

    # Final safety net: if whatever we resolved isn't safe (bad scheme,
    # non-allowlisted host, malformed URL), fall through to the web
    # URL — and if THAT is also unsafe, the hardcoded apex constant.
    if not is_safe_url(target):
        if is_safe_url(settings.SHARE_WEB_URL):
            return settings.SHARE_WEB_URL
        return FINAL_SAFE_FALLBACK

    return target


@router.get("/invite", include_in_schema=False)
@limiter.limit("60/minute")
async def share_invite_landing(request: Request):
    """Smart-redirect entry point shared via WhatsApp / SMS.

    Uses a temporary redirect (302) during pre-launch because store
    destinations may change (web fallback → Play Store). 301s are
    cached aggressively by browsers and WhatsApp link previews, which
    can permanently pin old targets.
    """
    target = _resolve_target(request.headers.get("user-agent", ""))
    return RedirectResponse(url=target, status_code=302)


@router.get(
    "/.well-known/assetlinks.json",
    include_in_schema=False,
)
@limiter.limit("30/minute")
async def android_app_links_assetlinks(request: Request):
    """Android App Links manifest.

    Serves the JSON Google's verifier fetches when registering this
    domain to open the app directly (no chooser, no Play Store hop).
    """
    package = settings.ANDROID_PACKAGE_NAME
    cert = settings.SHARE_ANDROID_CERT_SHA256 or ""

    # Build via json.dumps over a real dict (handled by JSONResponse).
    # Never f-string interpolation — a mis-paste of `package` or `cert`
    # containing a double-quote, backslash, or control char would
    # otherwise emit invalid JSON OR open an injection surface for any
    # consumer that trusted the structure.
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
    # Google's Digital Asset Links verifier caches the manifest for
    # up to 24 hours by default. When we rotate signing keys (Play
    # Console re-sign, new internal-testing track), App Links break
    # for the whole cache window. max-age=3600 keeps the verifier
    # cached for an hour — short enough to roll out a cert rotation
    # without a multi-day outage, long enough to avoid hammering us
    # on every install.
    return JSONResponse(
        content=payload,
        headers={"Cache-Control": "max-age=3600"},
    )
