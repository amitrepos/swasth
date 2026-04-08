"""Tests for pre-existing health_utils classification functions."""
from health_utils import classify_bp, classify_glucose, age_context_bp, age_context_glucose


class TestClassifyBp:
    def test_normal(self):
        assert classify_bp(120, 80) == "NORMAL"

    def test_low(self):
        assert classify_bp(85, 55) == "LOW"

    def test_stage1(self):
        assert classify_bp(135, 88) == "HIGH - STAGE 1"

    def test_stage2(self):
        assert classify_bp(145, 95) == "HIGH - STAGE 2"


class TestClassifyGlucose:
    def test_low(self):
        assert classify_glucose(60) == "LOW"

    def test_normal(self):
        assert classify_glucose(100) == "NORMAL"

    def test_high(self):
        assert classify_glucose(150) == "HIGH"

    def test_critical(self):
        assert classify_glucose(200) == "CRITICAL"


class TestAgeContextBp:
    def test_none_age(self):
        assert age_context_bp(130, 85, "HIGH - STAGE 1", None) is None

    def test_elderly_stage1_acceptable(self):
        result = age_context_bp(135, 85, "HIGH - STAGE 1", 70)
        assert result is not None
        assert "ESC 2023" in result

    def test_very_elderly_stage2_acceptable(self):
        result = age_context_bp(145, 85, "HIGH - STAGE 2", 82)
        assert result is not None
        assert "150/90" in result

    def test_young_high(self):
        result = age_context_bp(140, 90, "HIGH - STAGE 1", 25)
        assert result is not None
        assert "young" in result.lower()

    def test_middle_age_normal(self):
        assert age_context_bp(120, 80, "NORMAL", 45) is None


class TestAgeContextGlucose:
    def test_none_age(self):
        assert age_context_glucose(150, "HIGH", None) is None

    def test_elderly_high_relaxed(self):
        result = age_context_glucose(160, "HIGH", 70)
        assert result is not None
        assert "relaxed" in result.lower()

    def test_prediabetic_fasting(self):
        result = age_context_glucose(110, "NORMAL", 40, "fasting")
        assert result is not None
        assert "prediabetic" in result.lower()

    def test_normal_no_context(self):
        assert age_context_glucose(100, "NORMAL", 45) is None
