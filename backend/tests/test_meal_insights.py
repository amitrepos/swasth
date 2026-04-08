"""Tests for meal-glucose insight rules (Step 3 of Food Photo Classification).

All tip language MUST be suggestive only — "may help", "consider", never commanding.
Correlation disclaimers MUST be present.
"""
import pytest
from datetime import datetime, timezone, timedelta

from health_utils import (
    generate_meal_insights,
    high_carb_dinner_warning,
    sweet_alert,
    good_food_choice,
    carb_glucose_correlation,
    weekly_food_pattern,
)


# ---------------------------------------------------------------------------
# Helper: fake meal/reading objects for pure-function tests
# ---------------------------------------------------------------------------

class FakeMeal:
    def __init__(self, category, meal_type, timestamp=None):
        self.category = category
        self.meal_type = meal_type
        self.timestamp = timestamp or datetime.now(timezone.utc)


class FakeReading:
    def __init__(self, glucose_value, timestamp=None, reading_type="glucose", status_flag="NORMAL"):
        self.glucose_value = glucose_value
        self.reading_type = reading_type
        self.status_flag = status_flag
        self.reading_timestamp = timestamp or datetime.now(timezone.utc)


# ---------------------------------------------------------------------------
# Rule 1: high_carb_dinner_warning
# ---------------------------------------------------------------------------

class TestHighCarbDinnerWarning:
    def test_returns_tip_for_high_carb_dinner(self):
        meal = FakeMeal("HIGH_CARB", "DINNER")
        tip = high_carb_dinner_warning(meal)
        assert tip is not None
        assert "may help" in tip.lower() or "consider" in tip.lower()

    def test_no_tip_for_high_carb_lunch(self):
        meal = FakeMeal("HIGH_CARB", "LUNCH")
        tip = high_carb_dinner_warning(meal)
        assert tip is None

    def test_no_tip_for_low_carb_dinner(self):
        meal = FakeMeal("LOW_CARB", "DINNER")
        tip = high_carb_dinner_warning(meal)
        assert tip is None

    def test_no_commanding_language(self):
        meal = FakeMeal("HIGH_CARB", "DINNER")
        tip = high_carb_dinner_warning(meal)
        assert tip is not None
        tip_lower = tip.lower()
        for word in ["must", "should", "do this", "you need to"]:
            assert word not in tip_lower, f"Commanding word '{word}' found in tip"


# ---------------------------------------------------------------------------
# Rule 2: sweet_alert
# ---------------------------------------------------------------------------

class TestSweetAlert:
    def test_returns_tip_for_sweets(self):
        meal = FakeMeal("SWEETS", "SNACK")
        tip = sweet_alert(meal)
        assert tip is not None
        assert "consider" in tip.lower() or "may" in tip.lower()

    def test_no_tip_for_non_sweets(self):
        meal = FakeMeal("LOW_CARB", "SNACK")
        tip = sweet_alert(meal)
        assert tip is None

    def test_no_commanding_language(self):
        meal = FakeMeal("SWEETS", "SNACK")
        tip = sweet_alert(meal)
        assert tip is not None
        tip_lower = tip.lower()
        for word in ["must", "should", "do this", "you need to"]:
            assert word not in tip_lower


# ---------------------------------------------------------------------------
# Rule 3: good_food_choice (positive reinforcement)
# ---------------------------------------------------------------------------

class TestGoodFoodChoice:
    def test_returns_tip_for_low_carb(self):
        meal = FakeMeal("LOW_CARB", "LUNCH")
        tip = good_food_choice(meal)
        assert tip is not None

    def test_returns_tip_for_high_protein(self):
        meal = FakeMeal("HIGH_PROTEIN", "DINNER")
        tip = good_food_choice(meal)
        assert tip is not None

    def test_no_tip_for_high_carb(self):
        meal = FakeMeal("HIGH_CARB", "LUNCH")
        tip = good_food_choice(meal)
        assert tip is None

    def test_no_tip_for_sweets(self):
        meal = FakeMeal("SWEETS", "SNACK")
        tip = good_food_choice(meal)
        assert tip is None

    def test_positive_tone(self):
        meal = FakeMeal("LOW_CARB", "LUNCH")
        tip = good_food_choice(meal)
        # Should contain positive words
        positive_words = ["great", "good", "well", "keep", "nice", "healthy"]
        assert any(w in tip.lower() for w in positive_words)


# ---------------------------------------------------------------------------
# Rule 4: carb_glucose_correlation (needs 7+ days of data)
# ---------------------------------------------------------------------------

class TestCarbGlucoseCorrelation:
    def _make_data(self, days, high_carb_ratio=0.7):
        """Generate N days of correlated meal + reading data."""
        meals = []
        readings = []
        now = datetime.now(timezone.utc)
        for i in range(days):
            ts = now - timedelta(days=i)
            if i / days < high_carb_ratio:
                meals.append(FakeMeal("HIGH_CARB", "DINNER", ts))
                # High glucose 2h after high carb meal
                readings.append(FakeReading(
                    170, ts + timedelta(hours=2), status_flag="HIGH"
                ))
            else:
                meals.append(FakeMeal("LOW_CARB", "DINNER", ts))
                readings.append(FakeReading(
                    110, ts + timedelta(hours=2), status_flag="NORMAL"
                ))
        return meals, readings

    def test_returns_insight_with_7_plus_days(self):
        meals, readings = self._make_data(10)
        tip = carb_glucose_correlation(meals, readings)
        assert tip is not None

    def test_no_insight_with_less_than_7_days(self):
        meals, readings = self._make_data(3)
        tip = carb_glucose_correlation(meals, readings)
        assert tip is None

    def test_contains_disclaimer(self):
        meals, readings = self._make_data(10)
        tip = carb_glucose_correlation(meals, readings)
        assert tip is not None
        tip_lower = tip.lower()
        assert "doctor" in tip_lower or "awareness" in tip_lower or "pattern" in tip_lower

    def test_no_commanding_language(self):
        meals, readings = self._make_data(10)
        tip = carb_glucose_correlation(meals, readings)
        if tip:
            tip_lower = tip.lower()
            for word in ["must", "should", "do this", "you need to"]:
                assert word not in tip_lower

    def test_no_insight_when_no_correlation(self):
        """All low carb meals + normal glucose = no correlation to report."""
        meals, readings = self._make_data(10, high_carb_ratio=0.0)
        tip = carb_glucose_correlation(meals, readings)
        assert tip is None

    def test_no_insight_when_no_glucose_readings(self):
        """Meals exist but no glucose readings → None."""
        now = datetime.now(timezone.utc)
        meals = [FakeMeal("HIGH_CARB", "DINNER", now - timedelta(days=i)) for i in range(10)]
        tip = carb_glucose_correlation(meals, [])
        assert tip is None

    def test_no_insight_when_weak_correlation(self):
        """Heavy meals but glucose stays normal → pct < 40 → None."""
        now = datetime.now(timezone.utc)
        meals = []
        readings = []
        for i in range(10):
            ts = now - timedelta(days=i)
            meals.append(FakeMeal("HIGH_CARB", "DINNER", ts))
            # All glucose is normal (below 130) → no correlation
            readings.append(FakeReading(100, ts + timedelta(hours=2)))
        tip = carb_glucose_correlation(meals, readings)
        assert tip is None

    def test_reading_with_no_timestamp_skipped(self):
        """Readings without timestamp attribute are safely skipped."""
        now = datetime.now(timezone.utc)
        meals = [FakeMeal("HIGH_CARB", "DINNER", now - timedelta(days=i)) for i in range(10)]

        class NoTsReading:
            glucose_value = 170
            reading_type = "glucose"

        readings = [NoTsReading() for _ in range(10)]
        # Should not crash, should return None (can't compute delta)
        tip = carb_glucose_correlation(meals, readings)
        assert tip is None


# ---------------------------------------------------------------------------
# Rule 5: weekly_food_pattern
# ---------------------------------------------------------------------------

class TestWeeklyFoodPattern:
    def _make_week(self, categories):
        now = datetime.now(timezone.utc)
        return [
            FakeMeal(cat, "LUNCH", now - timedelta(days=i))
            for i, cat in enumerate(categories)
        ]

    def test_returns_summary_with_7_meals(self):
        meals = self._make_week(["HIGH_CARB"] * 5 + ["LOW_CARB"] * 2)
        tip = weekly_food_pattern(meals)
        assert tip is not None

    def test_no_summary_with_fewer_than_3_meals(self):
        meals = self._make_week(["HIGH_CARB", "LOW_CARB"])
        tip = weekly_food_pattern(meals)
        assert tip is None

    def test_contains_disclaimer(self):
        meals = self._make_week(["HIGH_CARB"] * 5 + ["LOW_CARB"] * 2)
        tip = weekly_food_pattern(meals)
        assert tip is not None
        tip_lower = tip.lower()
        assert "doctor" in tip_lower or "awareness" in tip_lower or "pattern" in tip_lower

    def test_no_commanding_language(self):
        meals = self._make_week(["HIGH_CARB"] * 5 + ["LOW_CARB"] * 2)
        tip = weekly_food_pattern(meals)
        if tip:
            tip_lower = tip.lower()
            for word in ["must", "should", "do this", "you need to"]:
                assert word not in tip_lower

    def test_mostly_good_meals_positive(self):
        meals = self._make_week(["LOW_CARB"] * 5 + ["HIGH_CARB"] * 2)
        tip = weekly_food_pattern(meals)
        assert tip is not None
        positive = ["great", "good", "well", "keep", "healthy", "balanced"]
        assert any(w in tip.lower() for w in positive)


# ---------------------------------------------------------------------------
# Orchestrator: generate_meal_insights
# ---------------------------------------------------------------------------

class TestGenerateMealInsights:
    def test_returns_list_of_strings(self):
        now = datetime.now(timezone.utc)
        meals = [FakeMeal("HIGH_CARB", "DINNER", now)]
        readings = [FakeReading(160, now + timedelta(hours=2))]
        insights = generate_meal_insights(meals, readings)
        assert isinstance(insights, list)
        assert all(isinstance(i, str) for i in insights)

    def test_empty_meals_returns_empty(self):
        insights = generate_meal_insights([], [])
        assert insights == []

    def test_all_tips_use_suggestive_language(self):
        """No tip from any rule should contain commanding language."""
        now = datetime.now(timezone.utc)
        meals = [
            FakeMeal("HIGH_CARB", "DINNER", now),
            FakeMeal("SWEETS", "SNACK", now - timedelta(hours=1)),
        ]
        readings = [FakeReading(170, now + timedelta(hours=2), status_flag="HIGH")]
        insights = generate_meal_insights(meals, readings)
        for tip in insights:
            tip_lower = tip.lower()
            for word in ["must", "should", "do this", "you need to"]:
                assert word not in tip_lower, f"Commanding '{word}' in: {tip}"

    def test_combines_multiple_rules(self):
        """A SWEETS + HIGH_CARB dinner should trigger multiple insights."""
        now = datetime.now(timezone.utc)
        meals = [
            FakeMeal("HIGH_CARB", "DINNER", now),
            FakeMeal("SWEETS", "SNACK", now - timedelta(hours=1)),
        ]
        readings = []
        insights = generate_meal_insights(meals, readings)
        # At minimum: high_carb_dinner + sweet_alert
        assert len(insights) >= 2

    def test_includes_correlation_when_enough_data(self):
        """With 10+ days of heavy meals + high glucose, correlation tip appears."""
        now = datetime.now(timezone.utc)
        meals = []
        readings = []
        for i in range(10):
            ts = now - timedelta(days=i)
            meals.append(FakeMeal("HIGH_CARB", "DINNER", ts))
            readings.append(FakeReading(170, ts + timedelta(hours=2), status_flag="HIGH"))
        insights = generate_meal_insights(meals, readings)
        # Should include correlation + weekly pattern
        assert any("pattern" in t.lower() or "awareness" in t.lower() for t in insights)

    def test_includes_weekly_pattern(self):
        """Weekly pattern tip included when 3+ meals."""
        now = datetime.now(timezone.utc)
        meals = [FakeMeal("LOW_CARB", "LUNCH", now - timedelta(days=i)) for i in range(5)]
        insights = generate_meal_insights(meals, [])
        assert any("week" in t.lower() for t in insights)
