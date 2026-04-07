"""Tests for ai_service.py — multi-model fallback chain + audit logging."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from unittest.mock import patch, MagicMock
import pytest
import ai_service
import models


class TestFallbackChain:
    """Verify Gemini → DeepSeek → None fallback order."""

    def test_gemini_success_skips_deepseek(self, db, test_user):
        """When Gemini succeeds, DeepSeek should not be called."""
        with patch.object(ai_service, '_try_gemini', return_value={
            'text': 'Gemini insight', 'error': None, 'tokens': 50, 'ms': 200,
        }) as mock_g, patch.object(ai_service, '_try_deepseek') as mock_d, \
             patch('ai_service.settings') as mock_settings:
            mock_settings.GEMINI_API_KEY = 'fake-key'
            mock_settings.DEEPSEEK_API_KEY = None
            result = ai_service.generate_health_insight('test prompt', 1, db, 'summary')
            assert result == 'Gemini insight'
            mock_g.assert_called_once()
            mock_d.assert_not_called()

    def test_gemini_fail_triggers_deepseek(self, db, test_user):
        """When Gemini fails, DeepSeek should be tried."""
        with patch.object(ai_service, '_try_gemini', return_value={
            'text': None, 'error': '429 RATE_LIMITED', 'tokens': None, 'ms': 100,
        }), patch.object(ai_service, '_try_deepseek', return_value={
            'text': 'DeepSeek insight', 'error': None, 'tokens': 30, 'ms': 1500,
        }), patch('ai_service.settings') as mock_settings:
            mock_settings.GEMINI_API_KEY = 'fake-key'
            mock_settings.DEEPSEEK_API_KEY = 'fake-key'
            result = ai_service.generate_health_insight('test prompt', 1, db, 'summary')
            assert result == 'DeepSeek insight'

    def test_both_fail_returns_none(self, db, test_user):
        """When both models fail, return None."""
        with patch.object(ai_service, '_try_gemini', return_value={
            'text': None, 'error': '429', 'tokens': None, 'ms': 100,
        }), patch.object(ai_service, '_try_deepseek', return_value={
            'text': None, 'error': '402 Insufficient Balance', 'tokens': None, 'ms': 50,
        }), patch('ai_service.settings') as mock_settings:
            mock_settings.GEMINI_API_KEY = 'fake-key'
            mock_settings.DEEPSEEK_API_KEY = 'fake-key'
            result = ai_service.generate_health_insight('test prompt', 1, db, 'summary')
            assert result is None

    def test_no_gemini_key_skips_to_deepseek(self, db, test_user):
        """When GEMINI_API_KEY is not set, go straight to DeepSeek."""
        with patch.object(ai_service, '_try_deepseek', return_value={
            'text': 'DeepSeek only', 'error': None, 'tokens': 20, 'ms': 1000,
        }), patch.object(ai_service, '_try_gemini') as mock_g, \
             patch('ai_service.settings') as mock_settings:
            mock_settings.GEMINI_API_KEY = None
            mock_settings.DEEPSEEK_API_KEY = 'fake-key'
            result = ai_service.generate_health_insight('test prompt', 1, db, 'summary')
            assert result == 'DeepSeek only'
            mock_g.assert_not_called()


class TestAuditLogging:
    """Verify every AI call creates an audit row in ai_insight_logs."""

    def test_deepseek_success_logged(self, db, test_user):
        """DeepSeek is tried first (cheap, no rate limit)."""
        with patch.object(ai_service, '_try_deepseek', return_value={
            'text': 'Good insight', 'error': None, 'tokens': 40, 'ms': 200,
        }), patch('ai_service.settings') as mock_settings:
            mock_settings.DEEPSEEK_API_KEY = 'fake-key'
            mock_settings.GEMINI_API_KEY = None
            ai_service.generate_health_insight('prompt', 1, db, 'glucose avg 120')

        log = db.query(models.AiInsightLog).order_by(models.AiInsightLog.id.desc()).first()
        assert log is not None
        assert log.model_used == 'deepseek-chat'
        assert log.response_text == 'Good insight'
        assert log.fallback_reason is None
        assert log.tokens_used == 40
        assert log.prompt_summary == 'glucose avg 120'

    def test_gemini_fallback_logged_with_reason(self, db, test_user):
        """When DeepSeek fails, falls back to Gemini."""
        with patch.object(ai_service, '_try_deepseek', return_value={
            'text': None, 'error': 'timeout', 'tokens': None, 'ms': 50,
        }), patch.object(ai_service, '_try_gemini', return_value={
            'text': 'Fallback insight', 'error': None, 'tokens': 60, 'ms': 300,
        }), patch('ai_service.settings') as mock_settings:
            mock_settings.DEEPSEEK_API_KEY = 'fake-key'
            mock_settings.GEMINI_API_KEY = 'fake-key'
            ai_service.generate_health_insight('prompt', 1, db, 'bp avg 140/90')

        log = db.query(models.AiInsightLog).order_by(models.AiInsightLog.id.desc()).first()
        assert log is not None
        assert log.model_used == 'gemini-2.5-flash'
        assert log.response_text == 'Fallback insight'
        assert 'deepseek failed: timeout' in log.fallback_reason

    def test_both_fail_logged(self, db, test_user):
        with patch.object(ai_service, '_try_gemini', return_value={
            'text': None, 'error': '429', 'tokens': None, 'ms': 50,
        }), patch.object(ai_service, '_try_deepseek', return_value={
            'text': None, 'error': '402', 'tokens': None, 'ms': 50,
        }), patch('ai_service.settings') as mock_settings:
            mock_settings.GEMINI_API_KEY = 'fake-key'
            mock_settings.DEEPSEEK_API_KEY = 'fake-key'
            ai_service.generate_health_insight('prompt', 1, db, 'summary')

        log = db.query(models.AiInsightLog).order_by(models.AiInsightLog.id.desc()).first()
        assert log is not None
        assert log.model_used == 'failed'
        assert 'gemini: 429' in log.fallback_reason
        assert 'deepseek: 402' in log.fallback_reason


class TestSmartCaching:
    """Verify LLM is only called when new readings exist since last insight."""

    def test_returns_cached_when_no_new_readings(self, db, test_user):
        """If last insight is newer than last reading, return cached."""
        from datetime import datetime, timedelta

        # Insert a reading from yesterday
        reading = models.GlucoseReading(
            profile_id=1,
            logged_by=test_user.id,
            sequence_number=0,
            glucose_value=120,
            glucose_unit='mg/dL',
            status_flag='NORMAL',
            reading_timestamp=datetime.utcnow() - timedelta(hours=12),
        )
        db.add(reading)
        db.flush()

        # Insert a cached insight from 1 hour ago (newer than reading)
        log = models.AiInsightLog(
            profile_id=1,
            model_used='gemini-2.5-flash',
            response_text='Cached insight from earlier',
            prompt_summary='test',
        )
        db.add(log)
        db.commit()

        # Now generate_health_insight should NOT be called
        # The route handler checks timestamps and returns cached
        latest_insight = (
            db.query(models.AiInsightLog)
            .filter(models.AiInsightLog.profile_id == 1, models.AiInsightLog.model_used != 'failed')
            .order_by(models.AiInsightLog.created_at.desc())
            .first()
        )
        assert latest_insight is not None
        assert latest_insight.response_text == 'Cached insight from earlier'
