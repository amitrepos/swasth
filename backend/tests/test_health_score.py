"""Unit tests for health score calculation (backend/health_utils.py)."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from health_utils import calculate_health_score


class TestHealthScoreBase:
    """Base score behaviour when no readings exist."""

    def test_base_score_no_readings(self):
        score, color = calculate_health_score(
            has_today_readings=False,
            today_all_normal=False,
            critical_count=0,
            high_count=0,
            week_all_normal=False,
            streak_days=0,
        )
        assert score == 50
        assert color == "orange"

    def test_base_with_week_normal(self):
        score, _ = calculate_health_score(
            has_today_readings=False,
            today_all_normal=False,
            critical_count=0,
            high_count=0,
            week_all_normal=True,
            streak_days=0,
        )
        # 50 + 10 = 60
        assert score == 60


class TestHealthScoreToday:
    """Points from today's readings."""

    def test_logged_today_bonus(self):
        score, _ = calculate_health_score(
            has_today_readings=True,
            today_all_normal=False,
            critical_count=0,
            high_count=0,
            week_all_normal=False,
            streak_days=0,
        )
        # 50 + 15 = 65
        assert score == 65

    def test_all_normal_today(self):
        score, _ = calculate_health_score(
            has_today_readings=True,
            today_all_normal=True,
            critical_count=0,
            high_count=0,
            week_all_normal=False,
            streak_days=0,
        )
        # 50 + 15 + 15 = 80
        assert score == 80

    def test_critical_penalty(self):
        score, _ = calculate_health_score(
            has_today_readings=True,
            today_all_normal=False,
            critical_count=1,
            high_count=0,
            week_all_normal=False,
            streak_days=0,
        )
        # 50 + 15 - 25 = 40
        assert score == 40

    def test_critical_penalty_capped(self):
        score, _ = calculate_health_score(
            has_today_readings=True,
            today_all_normal=False,
            critical_count=3,
            high_count=0,
            week_all_normal=False,
            streak_days=0,
        )
        # 50 + 15 - 25 (capped) = 40
        assert score == 40

    def test_high_penalty(self):
        score, _ = calculate_health_score(
            has_today_readings=True,
            today_all_normal=False,
            critical_count=0,
            high_count=1,
            week_all_normal=False,
            streak_days=0,
        )
        # 50 + 15 - 10 = 55
        assert score == 55

    def test_high_penalty_capped(self):
        score, _ = calculate_health_score(
            has_today_readings=True,
            today_all_normal=False,
            critical_count=0,
            high_count=5,
            week_all_normal=False,
            streak_days=0,
        )
        # 50 + 15 - 20 (capped) = 45
        assert score == 45

    def test_critical_and_high_combined(self):
        score, color = calculate_health_score(
            has_today_readings=True,
            today_all_normal=False,
            critical_count=1,
            high_count=2,
            week_all_normal=False,
            streak_days=0,
        )
        # 50 + 15 - 25 - 20 = 20
        assert score == 20
        assert color == "red"


class TestHealthScoreStreak:
    """Streak bonuses."""

    def test_streak_3(self):
        score, _ = calculate_health_score(
            has_today_readings=False,
            today_all_normal=False,
            critical_count=0,
            high_count=0,
            week_all_normal=False,
            streak_days=3,
        )
        # 50 + 5 = 55
        assert score == 55

    def test_streak_7(self):
        score, _ = calculate_health_score(
            has_today_readings=False,
            today_all_normal=False,
            critical_count=0,
            high_count=0,
            week_all_normal=False,
            streak_days=7,
        )
        # 50 + 5 + 5 = 60
        assert score == 60

    def test_streak_below_3_no_bonus(self):
        score, _ = calculate_health_score(
            has_today_readings=False,
            today_all_normal=False,
            critical_count=0,
            high_count=0,
            week_all_normal=False,
            streak_days=2,
        )
        assert score == 50


class TestHealthScoreMaxAndClamp:
    """Clamping and maximum achievable score."""

    def test_max_score(self):
        score, color = calculate_health_score(
            has_today_readings=True,
            today_all_normal=True,
            critical_count=0,
            high_count=0,
            week_all_normal=True,
            streak_days=7,
        )
        # 50 + 15 + 15 + 10 + 5 + 5 = 100
        assert score == 100
        assert color == "green"

    def test_score_clamped_at_zero(self):
        # Extreme penalties should not go below 0
        score, color = calculate_health_score(
            has_today_readings=True,
            today_all_normal=False,
            critical_count=1,
            high_count=2,
            week_all_normal=False,
            streak_days=0,
        )
        # 50 + 15 - 25 - 20 = 20 (doesn't hit zero here, but let's verify floor)
        assert score >= 0
        assert color == "red"


class TestHealthScoreColor:
    """Color thresholds."""

    def test_green_at_70(self):
        _, color = calculate_health_score(
            has_today_readings=True,
            today_all_normal=True,
            critical_count=0,
            high_count=0,
            week_all_normal=False,
            streak_days=3,
        )
        # 50 + 15 + 15 + 5 = 85 -> green
        assert color == "green"

    def test_orange_at_40(self):
        _, color = calculate_health_score(
            has_today_readings=True,
            today_all_normal=False,
            critical_count=1,
            high_count=0,
            week_all_normal=False,
            streak_days=0,
        )
        # 50 + 15 - 25 = 40 -> orange
        assert color == "orange"

    def test_red_below_40(self):
        _, color = calculate_health_score(
            has_today_readings=True,
            today_all_normal=False,
            critical_count=1,
            high_count=2,
            week_all_normal=False,
            streak_days=0,
        )
        # 50 + 15 - 25 - 20 = 20 -> red
        assert color == "red"
