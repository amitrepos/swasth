#!/usr/bin/env python3
"""jira_fetch_ticket.py — fetch a JIRA ticket and render a markdown brief.

Usage:
    jira_fetch_ticket.py <TICKET_KEY> [--out PATH]

Writes a markdown brief to PATH (default /tmp/ticket.md) containing the ticket's
summary, description, comments, labels, priority, and parent epic. This is the
canonical context the worker reads — not the JIRA REST response inlined into
prompts.

Comments are sanitized via phi_scrub before being written so PHI from prior
comments cannot leak through the prompt or the GHA log.

Environment:
    JIRA_URL, JIRA_EMAIL, JIRA_API_TOKEN — required.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any

import requests
from requests.auth import HTTPBasicAuth

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
try:
    from phi_scrub import scrub  # type: ignore
except ImportError:
    def scrub(text: str) -> str:  # fallback no-op if phi_scrub missing
        return text


def _adf_to_text(node: Any) -> str:
    """Render Atlassian Document Format (ADF) JSON to **Markdown**.

    Preserves headings (`#`), bold (`**`), and inline code (backticks) — the downstream churn gate
    (check_no_regression.py) keys off `## Affected Surfaces` / `**Affected Surfaces**` markers and
    backticked file paths, so these marks must survive the fetch (previously they were stripped).
    """
    if isinstance(node, str):
        return node
    if isinstance(node, dict):
        ntype = node.get("type")
        if ntype == "text":
            text = node.get("text", "")
            marks = {m.get("type") for m in node.get("marks", [])}
            if "code" in marks:
                text = f"`{text}`"
            if "strong" in marks:
                text = f"**{text}**"
            if "em" in marks:
                text = f"*{text}*"
            return text
        if ntype == "hardBreak":
            return "\n"
        if ntype == "heading":
            level = (node.get("attrs") or {}).get("level", 2)
            inner = "".join(_adf_to_text(c) for c in node.get("content", [])).strip()
            return f"\n{'#' * int(level)} {inner}\n\n"
        if ntype == "paragraph":
            return "".join(_adf_to_text(c) for c in node.get("content", [])) + "\n\n"
        if ntype in ("bulletList", "orderedList"):
            return "".join(_adf_to_text(c) for c in node.get("content", []))
        if ntype == "listItem":
            return "- " + "".join(_adf_to_text(c) for c in node.get("content", [])).strip() + "\n"
        if ntype == "codeBlock":
            return "```\n" + "".join(_adf_to_text(c) for c in node.get("content", [])) + "\n```\n"
        if "content" in node:
            return "".join(_adf_to_text(c) for c in node["content"])
    if isinstance(node, list):
        return "".join(_adf_to_text(c) for c in node)
    return ""


def fetch_ticket(key: str) -> dict[str, Any]:
    url = os.environ["JIRA_URL"].rstrip("/")
    email = os.environ["JIRA_EMAIL"]
    token = os.environ["JIRA_API_TOKEN"]
    endpoint = f"{url}/rest/api/3/issue/{key}"
    params = {
        "fields": "summary,description,labels,priority,issuetype,status,parent,comment,reporter",
    }
    r = requests.get(endpoint, auth=HTTPBasicAuth(email, token), params=params, timeout=30)
    r.raise_for_status()
    return r.json()


def render_brief(issue: dict[str, Any]) -> str:
    f = issue.get("fields", {})
    key = issue.get("key", "?")
    summary = f.get("summary", "")
    status = (f.get("status") or {}).get("name", "?")
    priority = (f.get("priority") or {}).get("name", "?")
    issue_type = (f.get("issuetype") or {}).get("name", "?")
    labels = f.get("labels") or []
    reporter = f.get("reporter") or {}
    reporter_name = reporter.get("displayName", "?")
    reporter_id = reporter.get("accountId", "")
    parent = f.get("parent")
    parent_str = ""
    if parent:
        pf = parent.get("fields", {})
        parent_str = f"{parent.get('key')} — {pf.get('summary', '')}"
    description_md = _adf_to_text(f.get("description"))
    comments = ((f.get("comment") or {}).get("comments")) or []

    lines: list[str] = []
    lines.append(f"# {key} — {summary}\n")
    lines.append(f"- **Status:** {status}")
    lines.append(f"- **Priority:** {priority}")
    lines.append(f"- **Issue Type:** {issue_type}")
    lines.append(f"- **Labels:** {', '.join(labels) if labels else '(none)'}")
    # Machine-readable line so the grooming workflow can hand the ticket back to its reporter.
    lines.append(f"- **Reporter accountId:** {reporter_id or '(unknown)'}  ({reporter_name})")
    if parent_str:
        lines.append(f"- **Parent / Epic:** {parent_str}")
    lines.append("")
    lines.append("## Description\n")
    lines.append(scrub(description_md.strip()) or "_(no description)_")
    lines.append("")
    lines.append("## Comments\n")
    if not comments:
        lines.append("_(no comments)_")
    else:
        for c in comments:
            author = (c.get("author") or {}).get("displayName", "?")
            created = c.get("created", "")
            body = scrub(_adf_to_text(c.get("body")).strip())
            lines.append(f"### {author} — {created}\n\n{body}\n")
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("ticket_key")
    parser.add_argument("--out", default="/tmp/ticket.md")
    args = parser.parse_args()

    for var in ("JIRA_URL", "JIRA_EMAIL", "JIRA_API_TOKEN"):
        if not os.environ.get(var):
            print(f"jira_fetch_ticket: missing env var {var}", file=sys.stderr)
            return 2

    try:
        issue = fetch_ticket(args.ticket_key)
    except requests.HTTPError as e:
        print(f"jira_fetch_ticket: HTTP error fetching {args.ticket_key}: {e}", file=sys.stderr)
        return 3
    except requests.RequestException as e:
        print(f"jira_fetch_ticket: network error: {e}", file=sys.stderr)
        return 3

    brief = render_brief(issue)
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out).write_text(brief, encoding="utf-8")
    print(f"jira_fetch_ticket: wrote {len(brief)} chars to {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
