"""Tests for age-contextual health notes in health_utils.py."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from health_utils import age_context_bp, age_context_glucose


class TestAgeContextBP:
    """Age-contextual notes for blood pressure readings."""

    def test_elderly_stage1_gets_note(self):
        note = age_context_bp(135, 85, "HIGH - STAGE 1", 70)
        assert note is not None
        assert "140/90" in note

    def test_very_elderly_stage2_under_150(self):
        note = age_context_bp(145, 88, "HIGH - STAGE 2", 82)
        assert note is not None
        assert "150/90" in note

    def test_young_high_bp_gets_lifestyle_note(self):
        note = age_context_bp(138, 88, "HIGH - STAGE 1", 25)
        assert note is not None
        assert "young age" in note.lower()

    def test_normal_bp_returns_none(self):
        assert age_context_bp(118, 78, "NORMAL", 45) is None

    def test_no_age_returns_none(self):
        assert age_context_bp(140, 90, "HIGH - STAGE 2", None) is None

    def test_middle_age_stage1_returns_none(self):
        """40-year-old with Stage 1 — no special age context."""
        assert age_context_bp(135, 85, "HIGH - STAGE 1", 40) is None


class TestAgeContextGlucose:
    """Age-contextual notes for glucose readings."""

    def test_elderly_high_glucose_gets_note(self):
        note = age_context_glucose(165, "HIGH", 70)
        assert note is not None
        assert "relaxed" in note.lower()

    def test_elderly_very_high_no_note(self):
        """Above 180 is too high even for elderly — no relaxation note."""
        assert age_context_glucose(200, "CRITICAL", 70) is None

    def test_prediabetic_fasting_30plus(self):
        note = age_context_glucose(110, "NORMAL", 35, "Fasting")
        assert note is not None
        assert "prediabetic" in note.lower()

    def test_prediabetic_non_fasting_no_note(self):
        """Post-meal prediabetic range doesn't trigger the fasting-specific note."""
        assert age_context_glucose(110, "NORMAL", 35, "Post-meal") is None

    def test_normal_glucose_no_note(self):
        assert age_context_glucose(90, "NORMAL", 45) is None

    def test_no_age_returns_none(self):
        assert age_context_glucose(165, "HIGH", None) is None
