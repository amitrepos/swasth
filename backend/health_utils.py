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
