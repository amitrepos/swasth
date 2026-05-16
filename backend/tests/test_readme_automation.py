"""NUO-132: README must contain an Automation section linking to the runbook."""
import pathlib


README = pathlib.Path(__file__).parents[2] / "README.md"
RUNBOOK = "docs/JIRA_AGENT_AUTOMATION.md"


def _readme_text() -> str:
    return README.read_text(encoding="utf-8")


def test_automation_heading_present():
    assert "## Automation" in _readme_text(), "README missing ## Automation section"


def test_automation_links_to_runbook():
    assert RUNBOOK in _readme_text(), f"README missing link to {RUNBOOK}"


def test_automation_section_is_not_duplicated():
    text = _readme_text()
    assert text.count("## Automation") == 1, "## Automation section duplicated"
