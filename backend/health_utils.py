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
