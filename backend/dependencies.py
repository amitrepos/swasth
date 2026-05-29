"""Shared FastAPI dependencies."""
import atexit
from fastapi import Depends, HTTPException, Request, status
from sqlalchemy.orm import Session
from typing import Annotated, Optional, Union
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
#
# Sentinel pattern: _geoip_reader holds one of three values:
#   - None              → not yet attempted (lazy-init has not run)
#   - _GEOIP_UNAVAILABLE → attempt completed and failed (DB missing /
#                          corrupt). Cached so we don't retry the file
#                          open on every request, which would re-stat
#                          the FS and re-log the warning thousands of
#                          times per hour on a server with no mmdb.
#   - geoip2.database.Reader instance → ready to use
_GEOIP_UNAVAILABLE: object = object()
_geoip_reader: Union[None, object, geoip2.database.Reader] = None
_geoip_lock = threading.Lock()


def _close_geoip_reader() -> None:
    """Close the cached mmdb FD. Wired to atexit so process shutdown
    releases the descriptor cleanly instead of relying on the kernel
    to reap it. Safe to call multiple times."""
    global _geoip_reader
    with _geoip_lock:
        reader = _geoip_reader
        _geoip_reader = None
        if isinstance(reader, geoip2.database.Reader):
            try:
                reader.close()
            except Exception as e:  # pragma: no cover — best-effort cleanup
                logger.warning(f"GeoIP reader close failed: {e}")


atexit.register(_close_geoip_reader)

# Trusted-proxy CIDRs. XFF is only honoured when request.client.host is
# inside one of these — otherwise an attacker can send their own XFF
# header with a spoofed Indian IP and walk through the geofence.
# Defaults cover loopback + RFC1918 (the typical nginx-on-localhost or
# private-LB topology). Override via TRUSTED_PROXIES env (comma-sep CIDRs)
# in environments with a public LB outside the private range.
_DEFAULT_TRUSTED_PROXIES = "127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,::1/128,fc00::/7"

# Cache of parsed trusted-proxy networks. TRUSTED_PROXIES is read from
# the environment at process start; re-parsing it on every request
# allocates a fresh list per HTTP call and burns CPU on a hot path.
# Lazy + lock-guarded so concurrent first-requests can't double-parse.
_trusted_networks_cache: Optional[list] = None
_trusted_networks_lock = threading.Lock()


def _trusted_proxy_networks() -> list:
    global _trusted_networks_cache
    if _trusted_networks_cache is not None:
        return _trusted_networks_cache
    with _trusted_networks_lock:
        if _trusted_networks_cache is not None:
            return _trusted_networks_cache
        raw = os.environ.get("TRUSTED_PROXIES", _DEFAULT_TRUSTED_PROXIES)
        nets = []
        for cidr in (c.strip() for c in raw.split(",") if c.strip()):
            try:
                nets.append(ipaddress.ip_network(cidr, strict=False))
            except ValueError:
                logger.warning(f"Ignoring invalid TRUSTED_PROXIES entry: {cidr}")
        if not nets:
            # Empty list means "no IP is a trusted proxy" → XFF is
            # ignored for every request. That's a defensible posture if
            # intentional (no reverse proxy in front of the API), but
            # it's also the silent-failure mode of TRUSTED_PROXIES="" or
            # a CIDR list of only-invalid entries. Warn so operators
            # notice the geofence is now resolving on the literal peer
            # IP, not on the X-Forwarded-For header.
            logger.warning(
                "TRUSTED_PROXIES resolved to an empty CIDR list. "
                "X-Forwarded-For will be ignored for ALL requests; "
                "the geofence will resolve on request.client.host only. "
                "If this server runs behind a reverse proxy, set "
                "TRUSTED_PROXIES to the proxy's CIDR range."
            )
        _trusted_networks_cache = nets
        return _trusted_networks_cache


def _reset_trusted_proxy_cache() -> None:
    """Test-only hook so suites that monkey-patch TRUSTED_PROXIES can
    force a re-parse. Production code never calls this."""
    global _trusted_networks_cache
    with _trusted_networks_lock:
        _trusted_networks_cache = None


def _mask_ip(ip_str: str) -> str:
    """Mask the last octet (IPv4) or last hextet (IPv6) of an IP for
    log lines. DPDPA 2023 treats IPs as personal data, so we keep them
    out of routine INFO logs while preserving enough to correlate with
    an ASN/range during an incident review."""
    try:
        ip = ipaddress.ip_address(ip_str)
    except ValueError:
        return "invalid"
    if isinstance(ip, ipaddress.IPv4Address):
        parts = ip_str.split(".")
        return ".".join(parts[:3] + ["x"]) if len(parts) == 4 else "ipv4"
    parts = ip_str.split(":")
    return ":".join(parts[:-1] + ["x"]) if len(parts) >= 2 else "ipv6"


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
    """Lazy-load the GeoIP database reader (thread-safe).

    Returns either a live Reader, or None to indicate "DB unavailable;
    fail open". The unavailable result is cached via the sentinel so
    we don't re-stat the FS on every request when the mmdb is missing
    or corrupt — under the previous code, a server without the mmdb
    would re-run os.path.exists() and re-log the warning for every
    single API call.
    """
    global _geoip_reader
    if _geoip_reader is _GEOIP_UNAVAILABLE:
        return None
    if isinstance(_geoip_reader, geoip2.database.Reader):
        return _geoip_reader

    with _geoip_lock:
        # Double-check after acquiring the lock — another thread may
        # have populated the cache while we were waiting.
        if _geoip_reader is _GEOIP_UNAVAILABLE:
            return None
        if isinstance(_geoip_reader, geoip2.database.Reader):
            return _geoip_reader

        db_path = os.path.join(os.path.dirname(__file__), "GeoLite2-Country.mmdb")
        if not os.path.exists(db_path):
            # Local dev or CI with no mmdb. Cache the negative result.
            _geoip_reader = _GEOIP_UNAVAILABLE
            return None

        try:
            _geoip_reader = geoip2.database.Reader(db_path)
            return _geoip_reader
        except Exception as e:
            # Corrupt DB or geoip2 internal failure. Cache the negative
            # result so we don't retry the file open on every request.
            logger.warning(f"Failed to load GeoIP database: {e}")
            _geoip_reader = _GEOIP_UNAVAILABLE
            return None


def _reset_geoip_reader_cache() -> None:
    """Test-only hook so suites that swap mmdb state mid-run can force
    a re-init. Production code never calls this."""
    global _geoip_reader
    with _geoip_lock:
        reader = _geoip_reader
        _geoip_reader = None
        if isinstance(reader, geoip2.database.Reader):
            try:
                reader.close()
            except Exception:
                pass


# ──────────────────────────────────────────────────────────────────────
# Email allowlist (GEOFENCE_EMAIL_ALLOWLIST)
#
# Designated-account bypass for verify_india_location. The allowlist
# lives in settings as a comma-separated plaintext list. We hash each
# entry with the same HMAC routine that produces user.email_hash, then
# compare against the authenticated user's column at request time. This
# keeps the comparison O(1) and the hot path off the SHA-256 codepath.
#
# Cached lazy + lock-guarded — same pattern as the GeoIP reader. The
# env var doesn't change at runtime, so recomputing hashes per request
# would burn CPU for nothing.
# ──────────────────────────────────────────────────────────────────────
_geofence_allowlist_hashes_cache: Optional[frozenset] = None
_geofence_allowlist_lock = threading.Lock()


def _get_geofence_allowlist_hashes() -> frozenset:
    """Return the SHA-256-hashed allowlist as a frozenset.

    Lazy import of `settings` because dependencies.py is imported very
    early in the FastAPI bootstrap; pulling config at module-load time
    would risk a circular import if settings ever grows a dependency
    on anything in this file.
    """
    global _geofence_allowlist_hashes_cache
    if _geofence_allowlist_hashes_cache is not None:
        return _geofence_allowlist_hashes_cache
    with _geofence_allowlist_lock:
        if _geofence_allowlist_hashes_cache is not None:
            return _geofence_allowlist_hashes_cache
        from config import settings
        raw = settings.GEOFENCE_EMAIL_ALLOWLIST or ""
        emails = [e.strip().lower() for e in raw.split(",") if e.strip()]
        # hash_email is HMAC-SHA256(normalised_email) using PII_ENCRYPTION_KEY
        # and matches models.User.email_hash — that match is what makes
        # the membership test work. When PII_ENCRYPTION_KEY is unset the
        # function returns None for every entry; the config-layer
        # model_validator should have already refused boot in that case,
        # but we still defend at runtime: drop None hashes so the frozenset
        # never contains a sentinel that could accidentally match against
        # another None lookup result, and emit a loud WARNING so an
        # operator who somehow got past the boot check sees the cause.
        hashes: list = []
        dropped = 0
        for e in emails:
            h = hash_email(e)
            if h is None:
                dropped += 1
            else:
                hashes.append(h)
        if dropped:
            logger.warning(
                f"GEOFENCE_EMAIL_ALLOWLIST has {len(emails)} entries but "
                f"{dropped} hashed to None — likely PII_ENCRYPTION_KEY is "
                "unset. The dropped entries will NEVER match a real request. "
                "Set PII_ENCRYPTION_KEY in .env and restart."
            )
        _geofence_allowlist_hashes_cache = frozenset(hashes)
        return _geofence_allowlist_hashes_cache


def _reset_geofence_allowlist_cache() -> None:
    """Test-only — force a re-read of GEOFENCE_EMAIL_ALLOWLIST after a
    suite mutates the setting. Production code never calls this."""
    global _geofence_allowlist_hashes_cache
    with _geofence_allowlist_lock:
        _geofence_allowlist_hashes_cache = None


def _email_hash_from_bearer_token(request: Request) -> Optional[str]:
    """Best-effort: extract email_hash from the request's Bearer token.

    Returns None on any failure — caller falls through to the IP-country
    check. This is intentionally lenient: a missing/invalid/expired
    token must NOT inadvertently flip the geofence into "allow"; it
    must flow into the regular IP path. Real auth still runs in
    get_current_user on the same request — that's where token
    validation actually gates access.

    We avoid calling get_current_user here because of the forward-ref
    dance (verify_india_location is defined above get_current_user in
    this file) and because we don't need the DB row — only the hash.
    """
    # Starlette's Headers object normalises all keys to lowercase, so
    # the lowercase lookup is sufficient in production. Tests build
    # the mock request via test_geofence._make_request which constructs
    # a starlette.datastructures.Headers (case-insensitive) — so any
    # case in the test setup also resolves here.
    auth_header = request.headers.get("authorization")
    if not auth_header:
        return None
    parts = auth_header.split(None, 1)
    if len(parts) != 2 or parts[0].lower() != "bearer":
        return None
    token = parts[1].strip()
    if not token:
        return None
    try:
        payload = auth.decode_access_token(token)
    except Exception:
        return None
    if not payload:
        return None
    email = payload.get("sub")
    if not isinstance(email, str) or not email:
        return None
    try:
        return hash_email(email)
    except Exception:
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
            f"peer_masked={_mask_ip(peer)} path={request.url.path} "
            f"method={request.method}. This must NEVER stay on in production; "
            "flip off after the incident/test."
        )
        return

    # 1.5. Per-user email allowlist (GEOFENCE_EMAIL_ALLOWLIST).
    # Audit-logged designated-account bypass for cases where an
    # authenticated user legitimately operates from outside India
    # (smoke-test runners on US-hosted CI, staff in non-India offices).
    # Order matters: this runs AFTER the env-flag rollback (operators
    # need an emergency switch that does not depend on DB/auth state)
    # but BEFORE IP resolution (the allowlist is a per-identity decision,
    # not per-IP — no point burning a GeoIP lookup if we're going to
    # allow anyway). DPDPA: the email_hash itself is PII; we log only
    # a 12-char prefix, enough to correlate to an audit-trail entry
    # but not enough to brute-force the address.
    allowlist_hashes = _get_geofence_allowlist_hashes()
    if allowlist_hashes:
        email_hash = _email_hash_from_bearer_token(request)
        if email_hash is not None and email_hash in allowlist_hashes:
            logger.info(
                "GEOFENCE_ALLOWLIST_HIT "
                f"email_hash_prefix={email_hash[:12]} "
                f"path={request.url.path} method={request.method}"
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
        iso_code = response.country.iso_code
        # iso_code can be None for satellite/anycast IPs or records
        # without a country assignment. None != "IN" would evaluate True
        # and 403 those users — Bihar pilot VSAT links would fail.
        # Treat "no country known" the same as AddressNotFoundError:
        # fail open. Spoofed/unknown traffic is still rate-limited and
        # authenticated by other layers.
        if iso_code is None:
            return
        if iso_code != "IN":
            # DPDPA: IPs are personal data; do NOT log the full address at
            # INFO. Log country + path + masked IP — enough to correlate
            # with an ASN range during incident review, not enough to
            # uniquely identify a subscriber.
            logger.info(
                f"GEOFENCE_BLOCK country={iso_code} "
                f"path={request.url.path} method={request.method} "
                f"ip_masked={_mask_ip(client_ip)}"
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
        # Don't block users if the lookup service itself fails. Mask the
        # IP in the error log too — same DPDPA reasoning as above.
        logger.error(
            f"GeoIP lookup error: {e} ip_masked={_mask_ip(client_ip)}"
        )
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
