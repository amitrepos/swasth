"""NUO-132: verify README.md Automation section acceptance criteria.

Edge case: if ## Automation already exists, we skip adding it (no duplicate).
These tests prove the README satisfies all acceptance criteria.
"""
import pathlib

README = pathlib.Path(__file__).parents[1] / "README.md"
RUNBOOK = "docs/JIRA_AGENT_AUTOMATION.md"


def _h2_sections(text: str) -> list[str]:
    return [line.strip() for line in text.splitlines() if line.startswith("## ")]


def test_automation_section_exists():
    text = README.read_text()
    assert "## Automation" in _h2_sections(text), "README must contain an ## Automation section"


def test_automation_section_links_runbook():
    text = README.read_text()
    assert RUNBOOK in text, f"README ## Automation section must link to {RUNBOOK}"


def test_automation_section_not_duplicated():
    text = README.read_text()
    count = _h2_sections(text).count("## Automation")
    assert count == 1, f"## Automation must appear exactly once, found {count}"
