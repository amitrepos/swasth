#!/usr/bin/env python3
"""md_to_adf.py — convert a small subset of Markdown to Atlassian Document Format (ADF).

JIRA Cloud renders ADF (JSON), not Markdown — posting raw markdown shows literal `###`/`**`/`-`.
This converts the agent's status comments to proper ADF blocks so they render cleanly.

Supports (enough for our comments): `#`/`##`/`###…` headings, `-`/`*` bullet lists, blank-line
paragraph breaks, and inline `**bold**` and `` `code` ``. Everything else is plain text.

Usage:
    cat comment.md | python3 scripts/md_to_adf.py            # prints the ADF `content` array
    cat comment.md | python3 scripts/md_to_adf.py --doc      # prints a full ADF doc {type:doc,...}
"""
import json
import re
import sys

INLINE = re.compile(r"(\*\*.+?\*\*|`[^`]+`)")


def inline_nodes(text):
    """Split a line into ADF text nodes, honouring **bold** and `code`."""
    nodes = []
    for part in INLINE.split(text):
        if not part:
            continue
        if part.startswith("**") and part.endswith("**") and len(part) > 4:
            nodes.append({"type": "text", "text": part[2:-2], "marks": [{"type": "strong"}]})
        elif part.startswith("`") and part.endswith("`") and len(part) > 2:
            nodes.append({"type": "text", "text": part[1:-1], "marks": [{"type": "code"}]})
        else:
            nodes.append({"type": "text", "text": part})
    return nodes or [{"type": "text", "text": " "}]


def convert(md):
    lines = md.replace("\r\n", "\n").split("\n")
    content = []
    bullets = []

    def flush_bullets():
        nonlocal bullets
        if bullets:
            content.append({
                "type": "bulletList",
                "content": [
                    {"type": "listItem",
                     "content": [{"type": "paragraph", "content": inline_nodes(b)}]}
                    for b in bullets
                ],
            })
            bullets = []

    for raw in lines:
        line = raw.rstrip()
        stripped = line.strip()
        if not stripped:
            flush_bullets()
            continue
        h = re.match(r"^(#{1,6})\s+(.*)$", stripped)
        b = re.match(r"^[-*]\s+(.*)$", stripped)
        if h:
            flush_bullets()
            level = min(len(h.group(1)), 6)
            content.append({"type": "heading", "attrs": {"level": level},
                            "content": inline_nodes(h.group(2))})
        elif b:
            bullets.append(b.group(1))
        else:
            flush_bullets()
            content.append({"type": "paragraph", "content": inline_nodes(stripped)})
    flush_bullets()

    if not content:
        content = [{"type": "paragraph", "content": [{"type": "text", "text": " "}]}]
    return content


def main(argv):
    md = sys.stdin.read()
    content = convert(md)
    if "--doc" in argv:
        print(json.dumps({"type": "doc", "version": 1, "content": content}))
    else:
        print(json.dumps(content))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
