"""Public, unauthenticated endpoints surfaced to the web landing page.

Kept in its own router so it's obvious which routes do NOT require a token.
Anything added here is visible to anyone on the public internet — review for
PII / abuse vectors before adding new endpoints.
"""
from fastapi import APIRouter, Request
from limiter import limiter

from config import settings
from dependencies import india_write_decision

router = APIRouter()


@router.get("/public/support")
@limiter.limit("30/minute")
def get_support_contacts(request: Request):
    """Return Help & Support contacts for the web Contact Us footer.

    Both fields are operational metadata (not PHI). The endpoint is
    unauthenticated by design — the web landing page calls this before
    a visitor has logged in.

    - email: always present; falls back to "support@swasth.health".
    - whatsapp_number: digits-only E.164 (no '+', no spaces). `null` if
      not configured — the client hides the WhatsApp button in that case.
    - phone_number: tel:-ready (with or without '+'). `null` if unset.

    Rate-limited to 30 req/min/IP. Honest visitors hit it once per
    page load; the cap covers retries on flaky networks while
    preventing trivial scraping.
    """
    return {
        "email": settings.SUPPORT_EMAIL,
        "whatsapp_number": settings.SUPPORT_WHATSAPP_NUMBER,
        "phone_number": settings.SUPPORT_PHONE_NUMBER,
    }


@router.get("/public/region")
@limiter.limit("30/minute")
async def get_region(request: Request):
    """Return the caller's region + whether write endpoints are open (NUO-135).

    Unauthenticated by design — Flutter calls this on first paint so it
    can render the read-only banner before the user even logs in.

    Body:
        country_code: ISO-2 (e.g. 'IN', 'US') or 'UNKNOWN' on lookup failure
        is_india:     true if the caller will pass `require_india_writer`
        write_allowed: alias for is_india (kept stable for client code)
        source:       'env_bypass' | 'email_allowlist' | 'mmdb'
                      — useful for client-side telemetry, never shown to users

    Uses the SAME `india_write_decision` the write gate enforces with, so
    this prediction can never disagree with the actual 451 the client gets.
    """
    allowed, country, source = india_write_decision(request)
    return {
        "country_code": country,
        "is_india": allowed,
        "write_allowed": allowed,
        "source": source,
    }
