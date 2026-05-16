"""Regression test: README.md must have an Automation section (NUO-132)."""
import pathlib

README = pathlib.Path(__file__).parents[2] / "README.md"


def _readme_text() -> str:
    return README.read_text(encoding="utf-8")


def test_readme_has_automation_heading():
    assert "## Automation" in _readme_text(), "README missing '## Automation' section"


def test_readme_automation_links_to_runbook():
    text = _readme_text()
    assert "docs/JIRA_AGENT_AUTOMATION.md" in text, (
        "README Automation section missing link to docs/JIRA_AGENT_AUTOMATION.md"
    )


def test_readme_automation_no_duplicate_heading():
    headings = [line for line in _readme_text().splitlines() if line.strip() == "## Automation"]
    assert len(headings) == 1, f"README has {len(headings)} '## Automation' headings; expected exactly 1"
