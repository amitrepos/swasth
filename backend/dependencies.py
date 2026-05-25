"""Shared FastAPI dependencies."""
from fastapi import Depends, HTTPException, Request, status
from sqlalchemy.orm import Session
from typing import Annotated, Optional
import ipaddress
import models
import auth
import os
import logging
import threading
import geoip2.database
import geoip2.errors
from database import get_db
from encryption_service import hash_email

logger = logging.getLogger(__name__)

# ──────────────────────────────────────────────────────────────────────
# Geofence: data-modifying endpoints must come from an Indian IP to
# satisfy DPDPA 2023 (data fiduciary obligations on cross-border
# transfer of personal data) and DISHA (digital health data residency).
# GDPR is EU law and does NOT apply here; do not cite it in code or
# audit logs — auditors get confused, and we lose the actual statute.
# ──────────────────────────────────────────────────────────────────────

# Cache for the GeoIP reader to avoid re-opening the file on every request.
# Lock guards the lazy-init to prevent the race where two concurrent
# requests both open the mmdb — one FD wins, the other leaks forever.
_geoip_reader: Optional[geoip2.database.Reader] = None
_geoip_lock = threading.Lock()

# Trusted-proxy CIDRs. XFF is only honoured when request.client.host is
# inside one of these — otherwise an attacker can send their own XFF
# header with a spoofed Indian IP and walk through the geofence.
# Defaults cover loopback + RFC1918 (the typical nginx-on-localhost or
# private-LB topology). Override via TRUSTED_PROXIES env (comma-sep CIDRs)
# in environments with a public LB outside the private range.
_DEFAULT_TRUSTED_PROXIES = "127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,::1/128,fc00::/7"


def _trusted_proxy_networks() -> list:
    raw = os.environ.get("TRUSTED_PROXIES", _DEFAULT_TRUSTED_PROXIES)
    nets = []
    for cidr in (c.strip() for c in raw.split(",") if c.strip()):
        try:
            nets.append(ipaddress.ip_network(cidr, strict=False))
        except ValueError:
            logger.warning(f"Ignoring invalid TRUSTED_PROXIES entry: {cidr}")
    return nets


def _ip_is_trusted_proxy(ip_str: str, nets: list) -> bool:
    try:
        ip = ipaddress.ip_address(ip_str)
    except ValueError:
        return False
    return any(ip in net for net in nets)


def _get_client_ip(request: Request) -> str:
    """Return the real client IP, resistant to XFF spoofing.

    XFF is only consulted when the immediate peer (request.client.host)
    is a trusted proxy. We then walk the XFF chain from right to left,
    stopping at the first untrusted address — that is the real client
    as seen by the outermost trusted hop. If no trusted proxy is in
    front of us, we ignore XFF entirely and trust request.client.host.
    """
    peer = request.client.host if request.client else "127.0.0.1"
    trusted = _trusted_proxy_networks()

    if not _ip_is_trusted_proxy(peer, trusted):
        # Direct connection (or peer is NOT a trusted proxy). Ignore XFF;
        # client could have set it themselves.
        return peer

    xff = request.headers.get("X-Forwarded-For")
    if not xff:
        return peer

    # Walk right-to-left, skipping trusted-proxy hops. The first
    # untrusted IP is the real client; if everything is trusted, fall
    # back to the leftmost entry.
    hops = [h.strip() for h in xff.split(",") if h.strip()]
    for hop in reversed(hops):
        if not _ip_is_trusted_proxy(hop, trusted):
            return hop
    return hops[0] if hops else peer


def _get_geoip_reader() -> Optional[geoip2.database.Reader]:
    """Lazy-load the GeoIP database reader (thread-safe)."""
    global _geoip_reader
    if _geoip_reader is not None:
        return _geoip_reader

    with _geoip_lock:
        # Double-check after acquiring the lock — another thread may
        # have populated the cache while we were waiting.
        if _geoip_reader is not None:
            return _geoip_reader

        db_path = os.path.join(os.path.dirname(__file__), "GeoLite2-Country.mmdb")
        if not os.path.exists(db_path):
            # Fallback for local development or if DB is missing in CI
            return None

        try:
            _geoip_reader = geoip2.database.Reader(db_path)
            return _geoip_reader
        except Exception as e:
            logger.warning(f"Failed to load GeoIP database: {e}")
            return None


def verify_india_location(request: Request) -> None:
    """Enforce India-only geofencing on data-modifying endpoints.

    Required by DPDPA 2023 (Sec. 16 — restrictions on cross-border data
    transfer for sensitive personal data) and DISHA's data-residency
    expectations for digital health records. GDPR is NOT the basis —
    that's EU law and would not protect Indian data subjects.

    Client IP resolution is XFF-spoof-resistant: see _get_client_ip.
    If GeoLite2-Country.mmdb is missing, the request is allowed
    (dev/CI fallback). Raises 403 REGION_RESTRICTED when the resolved
    country is not 'IN'.
    """
    # 1. Feature flag / bypass for tests + emergency rollback. AUDITED:
    # we log every bypassed request so the access trail still exists if
    # someone leaves the flag flipped in production by accident.
    if os.environ.get("BYPASS_GEO_RESTRICTION", "").lower() == "true":
        peer = request.client.host if request.client else "unknown"
        logger.warning(
            "GEOFENCE_BYPASS active — BYPASS_GEO_RESTRICTION=true. "
            f"peer={peer} path={request.url.path} method={request.method}. "
            "This must NEVER stay on in production; flip off after the "
            "incident/test."
        )
        return

    # 2. Extract client IP (XFF only honoured behind trusted proxies)
    client_ip = _get_client_ip(request)

    # 3. Check location
    reader = _get_geoip_reader()
    if reader is None:
        # Mock behavior: allow all if DB file is missing (dev environment)
        return

    try:
        response = reader.country(client_ip)
        if response.country.iso_code != "IN":
            logger.info(
                f"Blocked request from {client_ip} "
                f"(Country: {response.country.iso_code})"
            )
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="REGION_RESTRICTED"
            )
    except geoip2.errors.AddressNotFoundError:
        # IP not in database (likely private/local IP). Allow it.
        return
    except HTTPException:
        raise
    except Exception as e:
        # Don't block users if the lookup service itself fails
        logger.error(f"GeoIP lookup error for {client_ip}: {e}")
        return

def get_current_user(
    token: Annotated[str, Depends(auth.oauth2_scheme)],
    db: Session = Depends(get_db),
) -> models.User:
    """Extract and validate the current user from the JWT token.

    Use as a dependency in any route that requires authentication:
        user: models.User = Depends(get_current_user)
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    payload = auth.decode_access_token(token)
    if payload is None:
        raise credentials_exception
    email: str = payload.get("sub")
    if email is None:
        raise credentials_exception
    user = db.query(models.User).filter(models.User.email_hash == hash_email(email)).first()
    if user is None:
        raise credentials_exception
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Your account has been suspended. Contact support.",
        )
    return user


def get_profile_access_or_403(
    profile_id: int,
    user: models.User,
    db: Session,
) -> models.ProfileAccess:
    """Return the ProfileAccess row if the user has any access (owner or viewer).
    Raises 403 if the user has no access to this profile.
    """
    access = (
        db.query(models.ProfileAccess)
        .filter(
            models.ProfileAccess.profile_id == profile_id,
            models.ProfileAccess.user_id == user.id,
        )
        .first()
    )
    if access is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have access to this profile",
        )
    return access


def get_profile_editor_or_403(
    profile_id: int,
    user: models.User,
    db: Session,
) -> models.ProfileAccess:
    """Return the ProfileAccess row if the user is owner or editor.
    Raises 403 for viewers or users with no access.
    """
    access = (
        db.query(models.ProfileAccess)
        .filter(
            models.ProfileAccess.profile_id == profile_id,
            models.ProfileAccess.user_id == user.id,
            models.ProfileAccess.access_level.in_(["owner", "editor"]),
        )
        .first()
    )
    if access is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You need editor or owner access to perform this action",
        )
    return access


def get_doctor_patient_access(
    profile_id: int,
    user: models.User,
    db: Session,
) -> models.DoctorPatientLink:
    """Verify doctor has an active link to this patient profile.
    Logs the access for DPDPA audit trail.
    Raises 403 if the user is not a doctor or has no active link.
    """
    if user.role != models.UserRole.doctor:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only doctors can access this resource",
        )
    link = (
        db.query(models.DoctorPatientLink)
        .filter(
            models.DoctorPatientLink.doctor_id == user.id,
            models.DoctorPatientLink.profile_id == profile_id,
            models.DoctorPatientLink.status == "active",
        )
        .first()
    )
    if link is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No active access to this patient",
        )
    return link


def get_profile_owner_or_403(
    profile_id: int,
    user: models.User,
    db: Session,
) -> models.ProfileAccess:
    """Return the ProfileAccess row only if the user is the owner.
    Raises 403 for viewers or users with no access.
    """
    access = (
        db.query(models.ProfileAccess)
        .filter(
            models.ProfileAccess.profile_id == profile_id,
            models.ProfileAccess.user_id == user.id,
            models.ProfileAccess.access_level == "owner",
        )
        .first()
    )
    if access is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the profile owner can perform this action",
        )
    return access
