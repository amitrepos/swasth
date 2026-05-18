"""Verify README.md has the ## Automation section pointing to the runbook.

NUO-132 acceptance criteria:
  1. README.md contains a ## Automation heading.
  2. The section contains a link to docs/JIRA_AGENT_AUTOMATION.md.
  3. The target doc file exists.

Edge case: if the section already exists, do not duplicate it — this test
confirms idempotence by asserting the heading appears exactly once.
"""
import pathlib
import re


REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
README = REPO_ROOT / "README.md"
RUNBOOK = REPO_ROOT / "docs" / "JIRA_AGENT_AUTOMATION.md"


def test_readme_has_automation_heading():
    content = README.read_text()
    headings = re.findall(r"^## Automation\s*$", content, re.MULTILINE)
    assert len(headings) == 1, (
        f"Expected exactly one '## Automation' heading, found {len(headings)}"
    )


def test_readme_automation_section_links_runbook():
    content = README.read_text()
    assert "docs/JIRA_AGENT_AUTOMATION.md" in content, (
        "README.md must contain a link to docs/JIRA_AGENT_AUTOMATION.md"
    )


def test_runbook_file_exists():
    assert RUNBOOK.exists(), f"Runbook not found: {RUNBOOK}"
