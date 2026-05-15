#!/usr/bin/env python3
"""phi_scrub.py — second-line PHI scrubber for agent-generated text.

This is **defense-in-depth**, not the primary control. The primary control is
the synthetic-only test database (enforced by check_no_regression.sh). This
scrubber catches patterns that may slip past — phone-shaped digits, Aadhaar
patterns, vital signs in common formats, email addresses.

Per Matt audit C5 and runbook clarification N3-doc.

Usage as a library:
    from phi_scrub import scrub
    safe = scrub(user_text)

Usage as CLI:
    cat raw.txt | python phi_scrub.py > scrubbed.txt
"""
from __future__ import annotations

import re
import sys

# Pattern order matters. Specific patterns run before generic ones so a
# DOB like `12/03/1985` is matched by the date regex first instead of
# being eaten by the BP regex. Aadhaar requires word boundaries on the
# no-separator branch so timestamps and long digit runs are not captured.
# Per Daniel audit finding C3.
_PATTERNS: list[tuple[re.Pattern[str], str]] = [
    # Explicit PHI markers a developer might use: <phi>...</phi>. First so
    # everything inside is collapsed before any other pattern fires.
    (re.compile(r"<phi>.*?</phi>", re.DOTALL | re.IGNORECASE), "[PHI_BLOCK_REDACTED]"),
    # DOB-shaped dates — MUST run before BP_REDACTED, which would otherwise
    # match the leading `dd/mm` portion of `dd/mm/yyyy` (Daniel C3).
    (re.compile(r"\b(?:\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{4}-\d{1,2}-\d{1,2})\b"), "[DATE_REDACTED]"),
    # 10-digit numbers, optionally with +91 / 91 prefix.
    (re.compile(r"\b(?:\+?91[\s-]?)?[6-9]\d{9}\b"), "[PHONE_REDACTED]"),
    # Aadhaar pattern: 4-4-4 digits separated by spaces or dashes — anchored
    # so 12 unrelated digits in a row (e.g. unix timestamps) do not match.
    (re.compile(r"(?<!\d)\d{4}[\s-]\d{4}[\s-]\d{4}(?!\d)"), "[AADHAAR_REDACTED]"),
    # Email addresses.
    (re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"), "[EMAIL_REDACTED]"),
    # Glucose: numeric followed by mg/dL or mmol/L (BEFORE BP, since neither
    # overlaps but glucose units carry their own anchor).
    (re.compile(r"\b\d{2,4}(?:\.\d+)?\s*(?:mg/dL|mg/dl|mmol/L|mmol/l)\b"), "[GLUCOSE_REDACTED]"),
    # BP pattern: nnn/nn or nn/nn (with optional mmHg). Anchored to NOT
    # consume date components by requiring the BP-typical mmHg suffix OR
    # a clinical context cue. Without a cue, two-number-ratios are too
    # ambiguous to scrub safely.
    (re.compile(r"\b(\d{2,3})/(\d{2,3})\s*mmHg\b"), "[BP_REDACTED]"),
    (re.compile(r"(?i)\bBP[:\s]+(\d{2,3})/(\d{2,3})\b"), "BP: [BP_REDACTED]"),
    # Patient: / Reporter: / Name: <single word>.
    (re.compile(r"\b(Patient|Reporter|Name)\s*[:=]\s*([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)"),
     r"\1: [NAME_REDACTED]"),
]


def scrub(text: str) -> str:
    """Apply each pattern in order. Returns a scrubbed copy."""
    if not text:
        return text
    out = text
    for pat, repl in _PATTERNS:
        out = pat.sub(repl, out)
    return out


def main() -> int:
    data = sys.stdin.read()
    sys.stdout.write(scrub(data))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
