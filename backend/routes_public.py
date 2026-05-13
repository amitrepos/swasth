"""Public, unauthenticated endpoints surfaced to the web landing page.

Kept in its own router so it's obvious which routes do NOT require a token.
Anything added here is visible to anyone on the public internet — review for
PII / abuse vectors before adding new endpoints.
"""
from fastapi import APIRouter

from config import settings

router = APIRouter()


@router.get("/public/support")
def get_support_contacts():
    """Return Help & Support contacts for the web Contact Us footer.

    Both fields are operational metadata (not PHI). The endpoint is
    unauthenticated by design — the web landing page calls this before
    a visitor has logged in.

    - email: always present; falls back to "support@swasth.health".
    - whatsapp_number: digits-only E.164 (no '+', no spaces). `null` if
      not configured — the client hides the WhatsApp button in that case.
    """
    return {
        "email": settings.SUPPORT_EMAIL,
        "whatsapp_number": settings.SUPPORT_WHATSAPP_NUMBER,
        "phone_number": settings.SUPPORT_PHONE_NUMBER,
    }
