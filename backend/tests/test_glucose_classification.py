"""Unit tests for glucose classification (backend/health_utils.py :: classify_glucose)."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from health_utils import classify_glucose


class TestGlucoseLow:
    def test_low_30(self):
        assert classify_glucose(30) == "LOW"

    def test_low_69(self):
        assert classify_glucose(69) == "LOW"

    def test_low_69_9(self):
        assert classify_glucose(69.9) == "LOW"


class TestGlucoseNormal:
    def test_normal_boundary_70(self):
        assert classify_glucose(70) == "NORMAL"

    def test_normal_100(self):
        assert classify_glucose(100) == "NORMAL"

    def test_normal_upper_130(self):
        assert classify_glucose(130) == "NORMAL"


class TestGlucoseHigh:
    def test_high_131(self):
        assert classify_glucose(131) == "HIGH"

    def test_high_150(self):
        assert classify_glucose(150) == "HIGH"

    def test_high_upper_180(self):
        assert classify_glucose(180) == "HIGH"


class TestGlucoseCritical:
    def test_critical_181(self):
        assert classify_glucose(181) == "CRITICAL"

    def test_critical_200(self):
        assert classify_glucose(200) == "CRITICAL"

    def test_critical_500(self):
        assert classify_glucose(500) == "CRITICAL"


class TestGlucoseEdgeCases:
    def test_zero(self):
        assert classify_glucose(0) == "LOW"

    def test_negative(self):
        assert classify_glucose(-5) == "LOW"

    def test_boundary_70_exact(self):
        """70 is the first NORMAL value."""
        assert classify_glucose(70) == "NORMAL"

    def test_boundary_130_exact(self):
        """130 is the last NORMAL value."""
        assert classify_glucose(130) == "NORMAL"

    def test_boundary_180_exact(self):
        """180 is the last HIGH value."""
        assert classify_glucose(180) == "HIGH"

    def test_boundary_180_01(self):
        assert classify_glucose(180.01) == "CRITICAL"
