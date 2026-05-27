"""Public, unauthenticated endpoints surfaced to the web landing page.

Kept in its own router so it's obvious which routes do NOT require a token.
Anything added here is visible to anyone on the public internet — review for
PII / abuse vectors before adding new endpoints.
"""
import os

from fastapi import APIRouter, Request
from limiter import limiter

from config import settings

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
