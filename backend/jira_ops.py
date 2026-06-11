"""
jira_ops.py — Auto-create JIRA tickets from P0 ops alerts.

When a P0 alert fires (and isn't suppressed by the cooldown), we open a ticket
in the Swasth ops project (SWAS) so the incident is tracked and triaged, not
just emailed into an inbox. Dedup is by alert_key: each alert carries a label
``ops-alert-<alert_key>``; if an OPEN ticket with that label already exists we
add a "still firing" comment instead of spawning a duplicate every scheduler
tick.

Hard invariant: JIRA is best-effort. Any network/HTTP failure is logged and
swallowed — alerting and email must NEVER depend on JIRA being reachable. The
body contains aggregate counts only (same PHI-free contract as the email).
"""

import logging
import re
from typing import Optional

import requests
from requests.auth import HTTPBasicAuth

from config import settings

logger = logging.getLogger("swasth.jira_ops")

_TIMEOUT = 10  # seconds — never block the scheduler/email path on JIRA


def _enabled() -> bool:
    return bool(
        settings.JIRA_OPS_ENABLED
        and settings.JIRA_URL
        and settings.JIRA_EMAIL
        and settings.JIRA_API_TOKEN
        and settings.JIRA_OPS_PROJECT_KEY
    )


def _auth() -> HTTPBasicAuth:
    return HTTPBasicAuth(settings.JIRA_EMAIL, settings.JIRA_API_TOKEN)


def _label(alert_key: str) -> str:
    # JIRA labels cannot contain spaces; alert_key is already snake_case.
    # Sanitize defensively: the label is interpolated into a JQL string in
    # _find_open_issue, so a stray quote/space in a future alert_key must not
    # be able to break or spoof the query. alert_keys are developer-defined
    # constants today; this keeps that invariant enforced, not just assumed.
    safe = re.sub(r"[^A-Za-z0-9_-]", "_", alert_key or "unknown")
    return f"ops-alert-{safe}"


def _adf(text: str) -> dict:
    """Minimal Atlassian Document Format wrapper for a plain-text paragraph."""
    return {
        "type": "doc",
        "version": 1,
        "content": [
            {"type": "paragraph", "content": [{"type": "text", "text": text}]}
        ],
    }


def _find_open_issue(label: str) -> Optional[str]:
    """Return the key of an existing OPEN issue with this label, else None."""
    jql = (
        f'project = "{settings.JIRA_OPS_PROJECT_KEY}" '
        f'AND labels = "{label}" AND statusCategory != Done '
        f"ORDER BY created DESC"
    )
    resp = requests.get(
        f"{settings.JIRA_URL}/rest/api/3/search/jql",
        params={"jql": jql, "maxResults": 1, "fields": "key"},
        auth=_auth(),
        timeout=_TIMEOUT,
    )
    resp.raise_for_status()
    issues = resp.json().get("issues", [])
    return issues[0]["key"] if issues else None


def _comment(issue_key: str, text: str) -> None:
    resp = requests.post(
        f"{settings.JIRA_URL}/rest/api/3/issue/{issue_key}/comment",
        json={"body": _adf(text)},
        auth=_auth(),
        timeout=_TIMEOUT,
    )
    resp.raise_for_status()


def _create_issue(alert_key: str, summary: str, description: str) -> str:
    payload = {
        "fields": {
            "project": {"key": settings.JIRA_OPS_PROJECT_KEY},
            "issuetype": {"name": settings.JIRA_OPS_ISSUE_TYPE},
            "summary": summary[:250],  # JIRA summary max 255
            "description": _adf(description),
            "labels": ["ops-alert", _label(alert_key)],
        }
    }
    resp = requests.post(
        f"{settings.JIRA_URL}/rest/api/3/issue",
        json=payload,
        auth=_auth(),
        timeout=_TIMEOUT,
    )
    resp.raise_for_status()
    return resp.json()["key"]


def create_or_update_ticket(alert_key: str, tier: str, title: str, body: dict) -> Optional[str]:
    """Open (or comment on) a JIRA ticket for an ops alert.

    Returns the issue key on success, or None if disabled/failed. NEVER raises —
    the alert pipeline must survive JIRA being down.
    """
    if not _enabled():
        return None

    label = _label(alert_key)
    summary = f"[{tier}] {title}"
    detail_lines = [f"{k}: {v}" for k, v in (body or {}).items()]
    description = (
        f"Auto-created from Swasth ops monitoring.\n"
        f"Alert: {alert_key} (tier {tier})\n"
        f"{title}\n\n" + "\n".join(detail_lines)
    )

    try:
        existing = _find_open_issue(label)
        if existing:
            _comment(existing, f"Still firing: {title}")
            logger.info("jira_ops commented on existing %s for %s", existing, alert_key)
            return existing
        key = _create_issue(alert_key, summary, description)
        logger.info("jira_ops created %s for %s", key, alert_key)
        return key
    except Exception:
        # Best-effort: log and move on. Alerting must not depend on JIRA.
        logger.error("jira_ops failed to create/update ticket for %s", alert_key, exc_info=True)
        return None
