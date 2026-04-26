from datetime import datetime, timezone


def utc_isoformat(dt: datetime | None) -> str | None:
    """Return ISO 8601 string with explicit UTC offset, or None."""
    if dt is None:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.isoformat()


def ensure_utc(dt: datetime | None) -> datetime | None:
    """Return a UTC-aware datetime. Naive datetimes are assumed to be UTC."""
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt
