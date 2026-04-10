"""Pure utility functions for health metric classification and scoring.

These are extracted from route handlers and Flutter-side logic so they can be
unit-tested independently of the database or HTTP layer.
"""


def calculate_health_score(
    has_today_readings: bool,
    today_all_normal: bool,
    critical_count: int,
    high_count: int,
    week_all_normal: bool,
    streak_days: int,
) -> tuple[int, str]:
    """Compute the 0-100 health score and color label.

    Returns:
        (score, color) where color is "green", "orange", or "red".
    """
    score = 50

    if has_today_readings:
        score += 15  # logged today
        if today_all_normal:
            score += 15  # all normal today
        score -= min(critical_count * 25, 25)
        score -= min(high_count * 10, 20)

    if week_all_normal:
        score += 10

    if streak_days >= 3:
        score += 5
    if streak_days >= 7:
        score += 5

    score = max(0, min(100, score))

    if score >= 70:
        color = "green"
    elif score >= 40:
        color = "orange"
    else:
        color = "red"

    return score, color


def classify_bp(sys: float, dia: float) -> str:
    """Classify a blood pressure reading.

    Mirrors the Flutter ``_bpStatus`` function in
    ``reading_confirmation_screen.dart``.
    """
    if sys > 140 or dia > 90:
        return "HIGH - STAGE 2"
    if sys > 131 or dia > 86:
        return "HIGH - STAGE 1"
    if sys < 90 or dia < 60:
        return "LOW"
    return "NORMAL"


def classify_spo2(value: float) -> str:
    """Classify an SpO2 reading (percentage).

    Clinical thresholds:
    - >= 95%: NORMAL
    - 90-94%: LOW (hypoxemia — needs monitoring)
    - < 90%: CRITICAL (severe hypoxemia — medical attention)
    """
    if value >= 95:
        return "NORMAL"
    if value >= 90:
        return "LOW"
    return "CRITICAL"


def classify_glucose(value: float) -> str:
    """Classify a glucose reading (mg/dL).

    Mirrors the Flutter ``_glucoseStatus`` function in
    ``reading_confirmation_screen.dart``.
    """
    if value < 70:
        return "LOW"
    if value <= 130:
        return "NORMAL"
    if value <= 180:
        return "HIGH"
    return "CRITICAL"


# ---------------------------------------------------------------------------
# Age-contextual notes (ESC/ESH 2023 + ICMR + ADA 2024)
# ---------------------------------------------------------------------------

def age_context_bp(systolic: float, diastolic: float, status: str, age: int | None) -> str | None:
    """Return an age-contextual note for a BP reading, or None if not applicable."""
    if age is None:
        return None

    # Elderly (65+): treatment target is <140/90 per ESC 2023 & Indian guidelines
    if age >= 65 and status in ("HIGH - STAGE 1",):
        if systolic <= 139 and diastolic <= 89:
            return (
                f"For age {age}, guidelines (ESC 2023, Indian IHG-II) consider "
                f"BP below 140/90 an acceptable treatment target. "
                f"Your reading is within this range — discuss with your doctor."
            )
    if age >= 80 and status in ("HIGH - STAGE 1", "HIGH - STAGE 2"):
        if systolic <= 149 and diastolic <= 89:
            return (
                f"For age {age}, guidelines allow a treatment target below 150/90. "
                f"Your reading is within this relaxed range — consult your doctor."
            )

    # Young adults (<30): even Stage 1 deserves extra attention
    if age < 30 and "HIGH" in (status or ""):
        return (
            "Elevated BP at a young age warrants attention. "
            "Lifestyle changes (diet, exercise, salt reduction) are especially effective now."
        )

    return None


def age_context_glucose(value: float, status: str, age: int | None, sample_type: str | None = None) -> str | None:
    """Return an age-contextual note for a glucose reading, or None."""
    if age is None:
        return None

    # Elderly (65+): HbA1c targets are relaxed; daily readings can be slightly higher
    if age >= 65 and status == "HIGH" and value <= 180:
        return (
            f"For age {age}, diabetes management guidelines (ADA/ICMR) allow "
            f"slightly relaxed glucose targets to avoid hypoglycemia risk. "
            f"Your doctor may consider this acceptable."
        )

    # Prediabetic range awareness for 30+ (ICMR recommends screening from age 30)
    if age >= 30 and sample_type and "fasting" in sample_type.lower():
        if 100 <= value <= 125:
            return (
                "This fasting reading is in the prediabetic range (100-125 mg/dL). "
                "ICMR recommends active screening from age 30 for Indians. "
                "Diet and exercise can often reverse prediabetes."
            )

    return None


# ---------------------------------------------------------------------------
# Meal–glucose insight rules (Step 3: Food AI insights)
#
# ALL tip language is suggestive only: "may help", "consider", "could".
# NEVER: "must", "should", "do this", "you need to".
# Correlation disclaimers required per Dr. Rajesh (#3, #5, #8).
# ---------------------------------------------------------------------------

def high_carb_dinner_warning(meal) -> str | None:
    """Rule: warn (gently) when a HIGH_CARB meal is logged at dinner."""
    if meal.category == "HIGH_CARB" and meal.meal_type == "DINNER":
        return (
            "A short walk after dinner may help keep sugar levels stable. "
            "Even 10 minutes could make a difference."
        )
    return None


def sweet_alert(meal) -> str | None:
    """Rule: gentle nudge when SWEETS are logged."""
    if meal.category == "SWEETS":
        return (
            "You had sweets today. Consider checking your sugar in about 2 hours — "
            "it may help you understand how your body responds."
        )
    return None


def good_food_choice(meal) -> str | None:
    """Rule: positive reinforcement for LOW_CARB or HIGH_PROTEIN meals."""
    if meal.category in ("LOW_CARB", "HIGH_PROTEIN"):
        return "Great choice! Lighter meals like this may help keep your sugar steady."
    return None


def carb_glucose_correlation(meals: list, readings: list) -> str | None:
    """Rule: report meal–glucose pattern when 7+ days of data exist.

    Looks for correlation between HIGH_CARB/SWEETS meals and elevated
    glucose readings (>130 mg/dL) within 3 hours after the meal.
    Returns insight only if a meaningful pattern is found.
    """
    if len(meals) < 7:
        return None

    glucose_readings = [
        r for r in readings
        if getattr(r, "reading_type", "glucose") == "glucose"
        and getattr(r, "glucose_value", None) is not None
    ]
    if not glucose_readings:
        return None

    # Count how many HIGH_CARB/SWEETS meals had elevated glucose within 3h
    high_after_heavy = 0
    heavy_count = 0
    for meal in meals:
        if meal.category not in ("HIGH_CARB", "SWEETS"):
            continue
        heavy_count += 1
        meal_ts = meal.timestamp
        for r in glucose_readings:
            r_ts = getattr(r, "reading_timestamp", getattr(r, "timestamp", None))
            if r_ts is None:
                continue
            delta = (r_ts - meal_ts).total_seconds()
            if 0 < delta <= 10800 and r.glucose_value > 130:  # within 3 hours
                high_after_heavy += 1
                break  # one match per meal is enough

    if heavy_count < 3:
        return None

    pct = round(high_after_heavy / heavy_count * 100)
    if pct < 40:
        return None  # not a strong enough pattern

    return (
        f"Over the past week, {pct}% of heavy meals were followed by elevated sugar. "
        "These patterns are for awareness only — always follow your doctor's diet advice."
    )


def weekly_food_pattern(meals: list) -> str | None:
    """Rule: weekly summary of meal categories (needs 3+ meals)."""
    if len(meals) < 3:
        return None

    from collections import Counter
    counts = Counter(m.category for m in meals)
    total = sum(counts.values())

    heavy = counts.get("HIGH_CARB", 0) + counts.get("SWEETS", 0)
    light = counts.get("LOW_CARB", 0) + counts.get("HIGH_PROTEIN", 0)

    if light >= heavy:
        return (
            f"This week you logged {total} meals — mostly balanced or light choices. "
            "Great pattern! Keeping it up may help maintain healthy sugar levels. "
            "Always follow your doctor's advice for your diet."
        )
    else:
        heavy_pct = round(heavy / total * 100)
        return (
            f"This week, {heavy_pct}% of your {total} logged meals were heavy or sweet. "
            "Mixing in lighter options like sabzi or dal may help with sugar patterns. "
            "These patterns are for awareness — always follow your doctor's diet advice."
        )


def generate_meal_insights(meals: list, readings: list) -> list[str]:
    """Orchestrate all meal insight rules. Returns list of tip strings.

    Called by routes_health.py to augment AI insights with food-aware rules.
    """
    if not meals:
        return []

    insights: list[str] = []

    # Per-meal rules (most recent meals only)
    for meal in meals:
        tip = high_carb_dinner_warning(meal)
        if tip:
            insights.append(tip)

        tip = sweet_alert(meal)
        if tip:
            insights.append(tip)

        tip = good_food_choice(meal)
        if tip:
            insights.append(tip)

    # Multi-day rules
    tip = carb_glucose_correlation(meals, readings)
    if tip:
        insights.append(tip)

    tip = weekly_food_pattern(meals)
    if tip:
        insights.append(tip)

    return insights
