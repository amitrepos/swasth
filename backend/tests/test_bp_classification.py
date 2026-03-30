"""Unit tests for BP classification (backend/health_utils.py :: classify_bp)."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from health_utils import classify_bp


class TestBPNormal:
    def test_normal_120_80(self):
        assert classify_bp(120, 80) == "NORMAL"

    def test_boundary_131_86_is_normal(self):
        """131/86 is the upper edge of NORMAL (not exceeding thresholds)."""
        assert classify_bp(131, 86) == "NORMAL"

    def test_normal_90_60(self):
        """Lower boundary of NORMAL."""
        assert classify_bp(90, 60) == "NORMAL"

    def test_normal_mid_range(self):
        assert classify_bp(110, 75) == "NORMAL"


class TestBPStage1:
    def test_systolic_132_triggers_stage1(self):
        assert classify_bp(132, 80) == "HIGH - STAGE 1"

    def test_diastolic_87_triggers_stage1(self):
        assert classify_bp(120, 87) == "HIGH - STAGE 1"

    def test_stage1_135_88(self):
        assert classify_bp(135, 88) == "HIGH - STAGE 1"

    def test_stage1_upper_boundary_140_90(self):
        """140/90 is still STAGE 1 (not exceeding 140/90)."""
        assert classify_bp(140, 90) == "HIGH - STAGE 1"


class TestBPStage2:
    def test_systolic_141_triggers_stage2(self):
        assert classify_bp(141, 80) == "HIGH - STAGE 2"

    def test_diastolic_91_triggers_stage2(self):
        assert classify_bp(120, 91) == "HIGH - STAGE 2"

    def test_both_high(self):
        assert classify_bp(150, 95) == "HIGH - STAGE 2"

    def test_crisis_180_120(self):
        assert classify_bp(180, 120) == "HIGH - STAGE 2"

    def test_extreme_values(self):
        assert classify_bp(200, 130) == "HIGH - STAGE 2"


class TestBPLow:
    def test_low_systolic(self):
        assert classify_bp(89, 70) == "LOW"

    def test_low_diastolic(self):
        assert classify_bp(120, 59) == "LOW"

    def test_both_low(self):
        assert classify_bp(80, 50) == "LOW"

    def test_very_low(self):
        assert classify_bp(60, 40) == "LOW"


class TestBPEdgeCases:
    def test_systolic_exactly_90(self):
        """90 is not < 90, so not LOW."""
        assert classify_bp(90, 70) == "NORMAL"

    def test_diastolic_exactly_60(self):
        """60 is not < 60, so not LOW."""
        assert classify_bp(110, 60) == "NORMAL"

    def test_systolic_exactly_140_dia_normal(self):
        """140 is not > 140, still STAGE 1 range (> 131)."""
        assert classify_bp(140, 80) == "HIGH - STAGE 1"
