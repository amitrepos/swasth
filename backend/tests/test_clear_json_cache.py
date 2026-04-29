"""Tests for clear_json_cache.py — AI insight cache clearing utility."""
from unittest.mock import MagicMock, patch, call

import pytest

from clear_json_cache import clear_json_cached_insights


class TestClearJsonCachedInsights:
    """Test clear_json_cached_insights function."""

    @patch("clear_json_cache.SessionLocal")
    def test_clears_json_insights_with_markdown(self, mock_session):
        """Should delete insights containing markdown code blocks."""
        mock_db = MagicMock()
        mock_session.return_value = mock_db

        # Mock insight with markdown
        mock_insight = MagicMock()
        mock_insight.id = 1
        mock_insight.profile_id = 100
        mock_insight.prompt_summary = "Daily insight"

        mock_filter = mock_db.query.return_value.filter.return_value
        mock_filter.count.return_value = 1
        mock_filter.limit.return_value.all.return_value = [mock_insight]

        clear_json_cached_insights(dry_run=False)

        mock_db.delete.assert_called_once_with(mock_insight)
        mock_db.commit.assert_called_once()
        mock_db.close.assert_called_once()

    @patch("clear_json_cache.SessionLocal")
    def test_clears_insights_with_json_foods(self, mock_session):
        """Should delete insights containing JSON foods array."""
        mock_db = MagicMock()
        mock_session.return_value = mock_db

        mock_insight = MagicMock()
        mock_insight.id = 2
        mock_insight.profile_id = 101
        mock_insight.prompt_summary = "Nutrition analysis"

        mock_filter = mock_db.query.return_value.filter.return_value
        mock_filter.count.return_value = 1
        mock_filter.limit.return_value.all.return_value = [mock_insight]

        clear_json_cached_insights(dry_run=False)

        mock_db.delete.assert_called_once_with(mock_insight)
        mock_db.commit.assert_called_once()

    @patch("clear_json_cache.SessionLocal")
    def test_clears_nutrition_analysis_insights(self, mock_session):
        """Should delete insights with nutrition in prompt_summary."""
        mock_db = MagicMock()
        mock_session.return_value = mock_db

        mock_insight = MagicMock()
        mock_insight.id = 3
        mock_insight.profile_id = 102
        mock_insight.prompt_summary = "Meal nutrition breakdown"

        mock_filter = mock_db.query.return_value.filter.return_value
        mock_filter.count.return_value = 1
        mock_filter.limit.return_value.all.return_value = [mock_insight]

        clear_json_cached_insights(dry_run=False)

        mock_db.delete.assert_called_once_with(mock_insight)

    @patch("clear_json_cache.SessionLocal")
    def test_clears_multiple_insights(self, mock_session, caplog):
        """Should delete all matching insights."""
        mock_db = MagicMock()
        mock_session.return_value = mock_db

        mock_insights = [
            MagicMock(id=1, profile_id=100, prompt_summary="Insight 1"),
            MagicMock(id=2, profile_id=101, prompt_summary="Insight 2"),
            MagicMock(id=3, profile_id=102, prompt_summary="Insight 3"),
        ]

        mock_filter = mock_db.query.return_value.filter.return_value
        mock_filter.count.return_value = 3
        mock_filter.limit.return_value.all.return_value = mock_insights

        with caplog.at_level("INFO"):
            clear_json_cached_insights(dry_run=False)

        assert mock_db.delete.call_count == 3
        mock_db.commit.assert_called_once()

        assert "Found 3 cached insights" in caplog.text
        assert "Successfully deleted 3 cached insights" in caplog.text

    @patch("clear_json_cache.SessionLocal")
    def test_handles_no_insights_found(self, mock_session, caplog):
        """Should handle case when no insights match criteria."""
        mock_db = MagicMock()
        mock_session.return_value = mock_db

        mock_filter = mock_db.query.return_value.filter.return_value
        mock_filter.count.return_value = 0

        with caplog.at_level("INFO"):
            clear_json_cached_insights(dry_run=False)

        mock_db.delete.assert_not_called()
        mock_db.commit.assert_not_called()

        assert "Found 0 cached insights" in caplog.text
        assert "No cached insights to clear" in caplog.text

    @patch("clear_json_cache.SessionLocal")
    def test_handles_database_error(self, mock_session, caplog):
        """Should rollback and handle database errors gracefully."""
        mock_db = MagicMock()
        mock_session.return_value = mock_db

        mock_db.query.return_value.filter.return_value.count.side_effect = Exception(
            "Database connection lost"
        )

        # Should raise the exception
        with pytest.raises(Exception, match="Database connection lost"):
            clear_json_cached_insights(dry_run=False)

        mock_db.rollback.assert_called_once()
        mock_db.close.assert_called_once()

        assert "Error clearing cached insights" in caplog.text

    @patch("clear_json_cache.SessionLocal")
    def test_rollback_on_commit_error(self, mock_session, caplog):
        """Should rollback if commit fails."""
        mock_db = MagicMock()
        mock_session.return_value = mock_db

        mock_insight = MagicMock(id=1, profile_id=100, prompt_summary="Test")
        mock_filter = mock_db.query.return_value.filter.return_value
        mock_filter.count.return_value = 1
        mock_filter.limit.return_value.all.return_value = [mock_insight]
        mock_db.commit.side_effect = Exception("Commit failed")

        # Should raise the exception
        with pytest.raises(Exception, match="Commit failed"):
            clear_json_cached_insights(dry_run=False)

        mock_db.rollback.assert_called_once()
        mock_db.close.assert_called_once()

        assert "Error clearing cached insights" in caplog.text

    @patch("clear_json_cache.SessionLocal")
    def test_closes_db_session_on_success(self, mock_session):
        """Should always close database session."""
        mock_db = MagicMock()
        mock_session.return_value = mock_db

        mock_query = mock_db.query.return_value
        mock_query.filter.return_value.all.return_value = []
        mock_query.filter.return_value.count.return_value = 0

        clear_json_cached_insights()

        mock_db.close.assert_called_once()

    @patch("clear_json_cache.SessionLocal")
    def test_closes_db_session_on_error(self, mock_session, caplog):
        """Should close database session even on error."""
        mock_db = MagicMock()
        mock_session.return_value = mock_db

        mock_db.query.side_effect = Exception("Query failed")

        # Should raise the exception
        with pytest.raises(Exception, match="Query failed"):
            clear_json_cached_insights(dry_run=False)

        mock_db.close.assert_called_once()

    @patch("clear_json_cache.SessionLocal")
    def test_query_filters_correctly(self, mock_session):
        """Should query AiInsightLog with correct filters."""
        mock_db = MagicMock()
        mock_session.return_value = mock_db

        import models
        mock_filter = mock_db.query.return_value.filter.return_value
        mock_filter.count.return_value = 0

        clear_json_cached_insights(dry_run=False)

        # Verify query was made on AiInsightLog model
        mock_db.query.assert_called_once()
        call_args = mock_db.query.call_args
        assert call_args[0][0] == models.AiInsightLog

        # Verify filter was applied
        mock_db.query.return_value.filter.assert_called_once()
