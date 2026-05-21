"""IP geolocation helpers for region-based gating (NUO-135).

Design choices:
- **Fail-open**: if the lookup fails (timeout, network down, service quota),
  we return `("UNKNOWN", "error")` and let `is_india_writer_allowed` apply
  the locale fallback. We MUST NOT lock genuine India users out because
  ipapi.co was unreachable.
- **Override knob**: `GEO_RESTRICT_ENABLED` env var. When unset/false, every
  request is allowed to write — local dev / CI / pre-pilot stays unblocked.
- **In-memory LRU cache**: same IP usually hits within seconds of itself;
  we keep the last 4096 unique IPs to dodge the free-tier quota.
- **Locale fallback**: when geo says UNKNOWN we trust `Accept-Language`
  containing `en-IN`/`hi-IN` etc. — diaspora caregivers' phones usually
  carry their host-country locale.

Public API:
    `get_request_country(request) -> (country_code, source)`
    `is_india_writer_allowed(request) -> bool`
"""
from __future__ import annotations

import logging
import os
import re
from functools import lru_cache
from typing import Optional, Tuple

import httpx
from fastapi import Request

logger = logging.getLogger(__name__)

GEO_LOOKUP_URL = "https://ipapi.co/{ip}/country/"
GEO_LOOKUP_TIMEOUT = 1.5  # seconds — must be tight; we're on the request path

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


def _client_ip(request: Request) -> Optional[str]:
    """Best-effort client IP: trust X-Forwarded-For first hop, fall back to socket."""
    fwd = request.headers.get("x-forwarded-for", "")
    if fwd:
        # First entry is the original client per RFC 7239 conventions.
        return fwd.split(",")[0].strip() or None
    real_ip = request.headers.get("x-real-ip")
    if real_ip:
        return real_ip.strip()
    if request.client and request.client.host:
        return request.client.host
    return None


def _is_private_ip(ip: str) -> bool:
    return ip.startswith(_PRIVATE_PREFIXES)


@lru_cache(maxsize=4096)
def _lookup_country_cached(ip: str) -> str:
    """Network lookup. Cached by IP. Returns ISO-2 code or 'UNKNOWN'."""
    try:
        with httpx.Client(timeout=GEO_LOOKUP_TIMEOUT) as client:
            resp = client.get(GEO_LOOKUP_URL.format(ip=ip))
        if resp.status_code != 200:
            return "UNKNOWN"
        text = (resp.text or "").strip().upper()
        if re.fullmatch(r"[A-Z]{2}", text):
            return text
        return "UNKNOWN"
    except Exception as exc:  # broad-except: we deliberately fail-open
        logger.info("geo lookup failed for %s: %s", ip, exc)
        return "UNKNOWN"


def _locale_suggests_india(request: Request) -> bool:
    """Last-resort fallback: device locale headers contain `*-IN`."""
    al = request.headers.get("accept-language", "")
    return bool(re.search(r"\b(en|hi|bn|ta|te|kn|ml|mr|gu|pa|or|as|ur)[-_]IN\b", al, re.I))


def get_request_country(request: Request) -> Tuple[str, str]:
    """Return (country_code, source).

    `source` is one of: 'ip', 'private', 'locale', 'disabled', 'error'.
    Country code is ISO-2 ('IN', 'US', ...) or 'UNKNOWN'.
    """
    if not _is_geo_enabled():
        return "IN", "disabled"

    ip = _client_ip(request)
    if not ip:
        return "UNKNOWN", "error"

    if _is_private_ip(ip):
        # Localhost / VPC traffic — we have no way to geolocate; trust locale.
        return ("IN" if _locale_suggests_india(request) else "UNKNOWN"), "private"

    country = _lookup_country_cached(ip)
    if country == "UNKNOWN":
        return ("IN" if _locale_suggests_india(request) else "UNKNOWN"), "locale"
    return country, "ip"


def is_india_writer_allowed(request: Request) -> Tuple[bool, str, str]:
    """Decision function used by the dependency.

    Returns (allowed, country_code, source) — letting the caller log
    or surface the reason. India = allowed. Anything else = blocked.
    When the master switch is off, we treat every caller as India.
    """
    country, source = get_request_country(request)
    if country == "IN":
        return True, "IN", source
    return False, country, source


# Test hook — pytest can blow away the cache to avoid pollution across tests.
def reset_cache() -> None:
    _lookup_country_cached.cache_clear()
