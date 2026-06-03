"""IP geolocation helpers for region-based gating (NUO-135).

Design choices:
- **Fail-open**: if the lookup fails (timeout, network down, service quota),
  we return `("UNKNOWN", "error")` and let `is_india_writer_allowed` apply
  the locale fallback. We MUST NOT lock genuine India users out because
  ipapi.co was unreachable.
- **Override knob**: `GEO_RESTRICT_ENABLED` env var. When unset/false, every
  request is allowed to write — local dev / CI / pre-pilot stays unblocked.
- **In-memory TTL cache**: same IP usually hits within seconds of itself;
  we cache the country code for 1 hour (`_GEO_TTL_SECONDS`) to dodge the
  free-tier quota without pinning a VPN user to a stale decision forever.
- **Locale fallback**: when geo says UNKNOWN we trust `Accept-Language`
  containing `en-IN`/`hi-IN` etc. — diaspora caregivers' phones usually
  carry their host-country locale.

- **No IP extraction here**: this module is deliberately free of any
  `X-Forwarded-For` parsing. The caller resolves the real client IP with
  the spoof-resistant `dependencies._get_client_ip` (which only honours
  XFF behind a trusted proxy) and passes it in. Parsing XFF here without
  the trusted-proxy chain would let any client send
  `X-Forwarded-For: <Indian IP>` and walk through the NUO-135 gate.

Public API:
    `get_request_country(request, ip) -> (country_code, source)`
    `is_india_writer_allowed(request, ip) -> (allowed, country_code, source)`
"""
from __future__ import annotations

import logging
import os
import re
import time
from threading import Lock
from typing import Optional, Tuple

import httpx
from fastapi import Request

logger = logging.getLogger(__name__)

# ipapi.co free tier = 1000 requests/day. The TTL cache below absorbs almost
# all traffic at Bihar-pilot scale, so we stay well under quota. When the quota
# IS exhausted, ipapi.co returns HTTP 429; `_lookup_country` maps any non-200 to
# "UNKNOWN", which `get_request_country` then resolves via the locale fallback —
# i.e. we FAIL OPEN (genuine India users are never locked out by a quota error).
# Operators should therefore treat occasional 429s from ipapi.co as expected,
# not an incident.
#
# `GEO_LOOKUP_URL` is overridable via env so an operator can point at a paid or
# self-hosted endpoint (e.g. a MaxMind/GeoIP proxy) without a code deploy when
# the free-tier quota becomes a bottleneck. The override MUST contain the
# literal `{ip}` placeholder — it's `.format(ip=...)`-substituted per request —
# and MUST return the bare ISO-2 country code as plain text (as ipapi.co does).
GEO_LOOKUP_URL = os.getenv("GEO_LOOKUP_URL", "https://ipapi.co/{ip}/country/").strip() or "https://ipapi.co/{ip}/country/"
GEO_LOOKUP_TIMEOUT = 1.5  # seconds — must be tight; we're on the request path

# In-memory TTL cache: {ip: (expires_at_monotonic, country_code)}. The previous
# lru_cache had no expiry, so a VPN user who switched location stayed pinned to
# the cached decision for the whole process lifetime (weeks in prod). A 1-hour
# TTL bounds that staleness while still dodging the free-tier quota. The lock
# guards the dict because FastAPI runs sync deps in a thread pool (concurrent
# access) and `_lookup_country` is awaited from async route handlers.
_GEO_TTL_SECONDS = 3600
_geo_cache: dict[str, Tuple[float, str]] = {}
_geo_lock = Lock()

_PRIVATE_PREFIXES = (
    "10.", "172.16.", "172.17.", "172.18.", "172.19.", "172.20.",
    "172.21.", "172.22.", "172.23.", "172.24.", "172.25.", "172.26.",
    "172.27.", "172.28.", "172.29.", "172.30.", "172.31.",
    "192.168.", "127.", "::1", "fc", "fd", "fe80:",
)


def _is_geo_enabled() -> bool:
    """Master switch for the whole feature. Default OFF so local dev works.

    Set `GEO_RESTRICT_ENABLED=true` in production .env to turn it on."""
    return os.getenv("GEO_RESTRICT_ENABLED", "").strip().lower() in ("1", "true", "yes")


def _is_private_ip(ip: str) -> bool:
    return ip.startswith(_PRIVATE_PREFIXES)


def _mask_ip(ip: str) -> str:
    """Mask the host portion of an IP for logs — DPDPA treats IPs as personal
    data. Kept local (not imported from dependencies._mask_ip) to avoid a
    circular import: dependencies imports from this module."""
    if ":" in ip:
        parts = ip.split(":")
        return ":".join(parts[:-1] + ["x"]) if len(parts) >= 2 else "ipv6"
    parts = ip.split(".")
    return ".".join(parts[:3] + ["x"]) if len(parts) == 4 else "ipv4"


async def _lookup_country(ip: str) -> str:
    """Async network lookup, TTL-cached by IP. Returns ISO-2 code or 'UNKNOWN'.

    Uses `httpx.AsyncClient` so the (up to 1.5s) lookup awaits on the event
    loop instead of burning a thread-pool worker per cache-miss IP — matters
    on a slow Bihar 3G connection. Deliberately fails open on any error.
    """
    now = time.monotonic()
    with _geo_lock:
        hit = _geo_cache.get(ip)
        if hit is not None and hit[0] > now:
            return hit[1]

    try:
        async with httpx.AsyncClient(timeout=GEO_LOOKUP_TIMEOUT) as client:
            resp = await client.get(GEO_LOOKUP_URL.format(ip=ip))
        if resp.status_code != 200:
            result = "UNKNOWN"
        else:
            text = (resp.text or "").strip().upper()
            result = text if re.fullmatch(r"[A-Z]{2}", text) else "UNKNOWN"
    except Exception as exc:  # broad-except: we deliberately fail-open
        logger.info("geo lookup failed for %s: %s", ip, exc)
        result = "UNKNOWN"

    with _geo_lock:
        _geo_cache[ip] = (now + _GEO_TTL_SECONDS, result)
    return result


def _locale_suggests_india(request: Request) -> bool:
    """Last-resort fallback: device locale headers contain `*-IN`."""
    al = request.headers.get("accept-language", "")
    return bool(re.search(r"\b(en|hi|bn|ta|te|kn|ml|mr|gu|pa|or|as|ur)[-_]IN\b", al, re.I))


async def get_request_country(request: Request, ip: Optional[str]) -> Tuple[str, str]:
    """Return (country_code, source).

    `ip` MUST be the spoof-resistant client IP resolved by the caller via
    `dependencies._get_client_ip`. We never read `X-Forwarded-For` here —
    doing so without the trusted-proxy chain is the NUO-135 bypass Daniel
    flagged. `request` is still used for the locale fallback headers.

    `source` is one of: 'ip', 'private', 'locale', 'disabled', 'error'.
    Country code is ISO-2 ('IN', 'US', ...) or 'UNKNOWN'.
    """
    if not _is_geo_enabled():
        return "IN", "disabled"

    if not ip:
        return "UNKNOWN", "error"

    if _is_private_ip(ip):
        # Localhost / VPC traffic — we have no way to geolocate; trust locale.
        return ("IN" if _locale_suggests_india(request) else "UNKNOWN"), "private"

    country = await _lookup_country(ip)
    if country == "UNKNOWN":
        # Quota exhaustion or a network blip on a real public IP lands here.
        # We fail open to the locale check so genuine India users are never
        # locked out, but WARN: during these windows a non-India caller whose
        # device sends an *-IN Accept-Language can slip through. The log lets
        # an operator correlate a spike with an ipapi.co quota/outage window.
        logger.warning(
            "geo: locale fallback for public IP %s (ipapi.co quota or network error?)",
            _mask_ip(ip),
        )
        return ("IN" if _locale_suggests_india(request) else "UNKNOWN"), "locale"
    return country, "ip"


async def is_india_writer_allowed(request: Request, ip: Optional[str]) -> Tuple[bool, str, str]:
    """Decision function used by the dependency.

    `ip` is the spoof-resistant client IP resolved by the caller (see
    `dependencies._get_client_ip`). Returns (allowed, country_code,
    source) — letting the caller log or surface the reason. India =
    allowed. Anything else = blocked. When the master switch is off, we
    treat every caller as India.
    """
    country, source = await get_request_country(request, ip)
    if country == "IN":
        return True, "IN", source
    return False, country, source


# Test hook — pytest can blow away the cache to avoid pollution across tests.
def reset_cache() -> None:
    with _geo_lock:
        _geo_cache.clear()
