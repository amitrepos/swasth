import logging

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

# Allowlist of hostnames that may be used as redirect targets. The
# scheme check in _is_safe_url stops obvious shenanigans (javascript:,
# data:), but a misconfigured env var pointing at a phishing host
# (e.g. SHARE_WEB_URL=https://evil.com) would otherwise silently
# redirect every WhatsApp invite tap. The netloc check below requires
# the resolved hostname to match one of these apex domains OR be a
# subdomain of swasth.health.
#
# To permit a new host (e.g. an internal-testing URL), add it here.
_ALLOWED_HOSTS = frozenset({
    "play.google.com",      # Android store
    "apps.apple.com",       # iOS store
    "swasth.health",        # web app apex
})
# Suffix match for subdomains. NOTE the leading dot — prevents
# "notswasth.health" from matching ".swasth.health".
_ALLOWED_SUFFIX = ".swasth.health"


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
    if not _is_safe_url(target):
        if _is_safe_url(settings.SHARE_WEB_URL):
            return settings.SHARE_WEB_URL
        return _FINAL_SAFE_FALLBACK

    return target


def _is_safe_url(url: str) -> bool:
    """Validate that a URL is safe to use as a redirect target.

    Two checks, both must pass:

    1. Scheme is http or https — blocks `javascript:`, `data:`,
       `file:`, etc.
    2. Hostname is on the allowlist (`_ALLOWED_HOSTS`) OR is a
       subdomain of `swasth.health`. Hostname is read from
       `parsed.hostname` (lowercased + port/user-info stripped by
       urllib), which prevents bypasses like
       `https://evil.com:443@play.google.com/...` — `netloc` of that
       URL is `evil.com:443@play.google.com`, but `hostname` is
       `evil.com` and rightly fails the check.
    """
    if not url:
        return False
    try:
        parsed = urlparse(url)
    except Exception:
        return False
    # HTTPS-only. A plaintext http:// redirect over a plaintext
    # network request lets a MITM intercept the Location header and
    # swap the destination — TLS-stripping on Bihar mobile networks
    # is a realistic attack vector. The store URLs (play.google.com,
    # apps.apple.com) and the swasth.health web app all serve HTTPS,
    # so http:// here can only be a misconfiguration or an attacker
    # value. If a future dev environment needs http://localhost,
    # gate it behind an explicit settings.DEBUG branch rather than
    # weakening this production path.
    if parsed.scheme != "https":
        return False
    # Reject URLs that carry userinfo (user:pass@host). Browsers do
    # honor the host AFTER the @, but the URL as a string LOOKS like
    # it points elsewhere — a phishing tell that has no legitimate
    # reason to appear in a store/web fallback target.
    if parsed.username is not None or parsed.password is not None:
        return False
    host = (parsed.hostname or "").lower()
    if not host:
        return False
    if host in _ALLOWED_HOSTS:
        return True
    if host.endswith(_ALLOWED_SUFFIX):
        return True
    return False


@router.get("/invite", include_in_schema=False)
@limiter.limit("60/minute")
def share_invite_landing(request: Request):
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
def android_app_links_assetlinks(request: Request):
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
