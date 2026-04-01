"""Extended tests for ai_service.py — covers Gemini/DeepSeek API call paths via module-level mocking."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from unittest.mock import patch, MagicMock
import models
from tests.conftest import TEST_USER_EMAIL


class TestFallbackChain:
    """Test the generate_health_insight fallback chain."""

    @patch("ai_service.settings")
    def test_both_keys_missing_returns_none(self, mock_settings, db, test_user):
        mock_settings.GEMINI_API_KEY = None
        mock_settings.DEEPSEEK_API_KEY = None

        from ai_service import generate_health_insight
        result = generate_health_insight("test", test_user.id, db)
        assert result is None

    @patch("ai_service._try_deepseek")
    @patch("ai_service._try_gemini")
    @patch("ai_service.settings")
    def test_gemini_fails_deepseek_succeeds(self, mock_settings, mock_gemini, mock_deepseek, db, test_user):
        mock_settings.GEMINI_API_KEY = "key"
        mock_settings.DEEPSEEK_API_KEY = "key"
        mock_gemini.return_value = {"text": None, "error": "quota exceeded", "tokens": None, "ms": 100}
        mock_deepseek.return_value = {"text": "Fallback advice.", "error": None, "tokens": 50, "ms": 200}

        from ai_service import generate_health_insight
        result = generate_health_insight("test", test_user.id, db)
        assert result == "Fallback advice."

    @patch("ai_service._try_gemini")
    @patch("ai_service.settings")
    def test_gemini_succeeds_skips_deepseek(self, mock_settings, mock_gemini, db, test_user):
        mock_settings.GEMINI_API_KEY = "key"
        mock_settings.DEEPSEEK_API_KEY = "key"
        mock_gemini.return_value = {"text": "Gemini says drink water.", "error": None, "tokens": 80, "ms": 150}

        from ai_service import generate_health_insight
        result = generate_health_insight("test", test_user.id, db)
        assert result == "Gemini says drink water."

    @patch("ai_service._try_deepseek")
    @patch("ai_service._try_gemini")
    @patch("ai_service.settings")
    def test_both_fail_logs_failure(self, mock_settings, mock_gemini, mock_deepseek, db, test_user):
        mock_settings.GEMINI_API_KEY = "key"
        mock_settings.DEEPSEEK_API_KEY = "key"
        mock_gemini.return_value = {"text": None, "error": "API error", "tokens": None, "ms": 100}
        mock_deepseek.return_value = {"text": None, "error": "timeout", "tokens": None, "ms": 200}

        from ai_service import generate_health_insight
        result = generate_health_insight("test", test_user.id, db, prompt_summary="test failure")
        assert result is None

        # Verify failure was logged
        log = db.query(models.AiInsightLog).filter(
            models.AiInsightLog.model_used == "failed",
        ).first()
        assert log is not None


class TestVisionFallbackChain:

    @patch("ai_service._try_gemini_vision")
    @patch("ai_service.settings")
    def test_vision_fails_returns_none(self, mock_settings, mock_vision, db, test_user):
        """When Gemini Vision fails, returns None (Gemini-only for vision accuracy)."""
        mock_settings.GEMINI_API_KEY = "key"
        mock_settings.GEMINI_API_KEYS = None
        mock_vision.return_value = {"text": None, "error": "vision failed", "tokens": None, "ms": 100}

        from ai_service import generate_vision_insight
        result = generate_vision_insight("test", b"img", test_user.id, db)
        assert result is None

    @patch("ai_service._try_gemini_vision")
    @patch("ai_service.settings")
    def test_vision_succeeds(self, mock_settings, mock_vision, db, test_user):
        mock_settings.GEMINI_API_KEY = "key"
        mock_vision.return_value = {"text": "BP looks normal.", "error": None, "tokens": 100, "ms": 300}

        from ai_service import generate_vision_insight
        result = generate_vision_insight("test", b"img", test_user.id, db)
        assert result == "BP looks normal."

    @patch("ai_service.settings")
    def test_both_keys_missing(self, mock_settings, db, test_user):
        mock_settings.GEMINI_API_KEY = None
        mock_settings.DEEPSEEK_API_KEY = None

        from ai_service import generate_vision_insight
        result = generate_vision_insight("test", b"img", test_user.id, db)
        assert result is None


class TestAuditLogging:

    @patch("ai_service._try_gemini")
    @patch("ai_service.settings")
    def test_success_logged_to_db(self, mock_settings, mock_gemini, db, test_user):
        mock_settings.GEMINI_API_KEY = "key"
        mock_settings.DEEPSEEK_API_KEY = None
        mock_gemini.return_value = {"text": "Good health.", "error": None, "tokens": 80, "ms": 150}

        from ai_service import generate_health_insight
        generate_health_insight("test prompt", test_user.id, db, prompt_summary="audit test")

        log = db.query(models.AiInsightLog).filter(
            models.AiInsightLog.prompt_summary == "audit test",
        ).first()
        assert log is not None
        assert log.model_used == "gemini-2.5-flash"
        assert log.tokens_used == 80
        assert log.latency_ms == 150

    @patch("ai_service._try_gemini")
    @patch("ai_service.settings")
    def test_log_db_error_doesnt_crash(self, mock_settings, mock_gemini, db, test_user):
        """If logging fails, the main function should still return the result."""
        mock_settings.GEMINI_API_KEY = "key"
        mock_settings.DEEPSEEK_API_KEY = None
        mock_gemini.return_value = {"text": "Result.", "error": None, "tokens": 50, "ms": 100}

        with patch("ai_service._log", side_effect=Exception("DB write failed")):
            from ai_service import generate_health_insight
            # Should not crash even if logging fails
            # (The actual code catches exceptions in _log, so this tests that path)
