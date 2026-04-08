"""Tests for Meal Logging feature — MealLog model, schemas, and API endpoints."""
import pytest
from datetime import datetime, timezone


# ---------------------------------------------------------------------------
# Model tests
# ---------------------------------------------------------------------------

class TestMealLogModel:
    """Test MealLog SQLAlchemy model."""

    def test_create_meal_log_photo(self, db, test_user):
        """MealLog can be created with PHOTO_GEMINI input method."""
        import models

        # Get the test user's profile
        access = db.query(models.ProfileAccess).filter_by(user_id=test_user.id).first()
        profile_id = access.profile_id

        meal = models.MealLog(
            profile_id=profile_id,
            logged_by=test_user.id,
            category="HIGH_CARB",
            glucose_impact="HIGH",
            tip_en="High carb meal. Walk 15 minutes after eating.",
            tip_hi="ज़्यादा कार्ब वाला खाना। खाने के बाद 15 मिनट टहलें।",
            meal_type="DINNER",
            input_method="PHOTO_GEMINI",
            confidence=0.92,
            user_confirmed=True,
            timestamp=datetime.now(timezone.utc),
        )
        db.add(meal)
        db.flush()

        assert meal.id is not None
        assert meal.category == "HIGH_CARB"
        assert meal.glucose_impact == "HIGH"
        assert meal.input_method == "PHOTO_GEMINI"
        assert meal.confidence == 0.92

    def test_create_meal_log_quick_select(self, db, test_user):
        """MealLog can be created with QUICK_SELECT input method (no photo, no confidence)."""
        import models

        access = db.query(models.ProfileAccess).filter_by(user_id=test_user.id).first()

        meal = models.MealLog(
            profile_id=access.profile_id,
            logged_by=test_user.id,
            category="LOW_CARB",
            glucose_impact="LOW",
            meal_type="LUNCH",
            input_method="QUICK_SELECT",
            user_confirmed=True,
            timestamp=datetime.now(timezone.utc),
        )
        db.add(meal)
        db.flush()

        assert meal.id is not None
        assert meal.photo_path is None
        assert meal.confidence is None
        assert meal.tip_en is None

    def test_meal_log_user_correction(self, db, test_user):
        """User correction stores both original and corrected category."""
        import models

        access = db.query(models.ProfileAccess).filter_by(user_id=test_user.id).first()

        meal = models.MealLog(
            profile_id=access.profile_id,
            logged_by=test_user.id,
            category="MODERATE_CARB",
            glucose_impact="MODERATE",
            meal_type="DINNER",
            input_method="PHOTO_GEMINI",
            confidence=0.6,
            user_confirmed=True,
            user_corrected_category="HIGH_CARB",
            timestamp=datetime.now(timezone.utc),
        )
        db.add(meal)
        db.flush()

        assert meal.category == "MODERATE_CARB"  # Gemini's original
        assert meal.user_corrected_category == "HIGH_CARB"  # User's correction

    def test_meal_log_has_profile_foreign_key(self, db, test_user):
        """MealLog has a valid foreign key to profiles table."""
        import models

        access = db.query(models.ProfileAccess).filter_by(user_id=test_user.id).first()
        profile_id = access.profile_id

        meal = models.MealLog(
            profile_id=profile_id,
            logged_by=test_user.id,
            category="SWEETS",
            glucose_impact="VERY_HIGH",
            meal_type="SNACK",
            input_method="QUICK_SELECT",
            user_confirmed=True,
            timestamp=datetime.now(timezone.utc),
        )
        db.add(meal)
        db.flush()

        # Verify the FK relationship
        profile = db.query(models.Profile).get(profile_id)
        assert profile is not None
        assert meal.profile_id == profile.id


# ---------------------------------------------------------------------------
# Schema validation tests
# ---------------------------------------------------------------------------

class TestMealLogSchemas:
    """Test Pydantic schemas for meal logging."""

    def test_valid_meal_create(self):
        from schemas import MealLogCreate

        meal = MealLogCreate(
            profile_id=1,
            category="HIGH_CARB",
            glucose_impact="HIGH",
            meal_type="DINNER",
            input_method="PHOTO_GEMINI",
            confidence=0.9,
            tip_en="Walk after eating.",
            tip_hi="खाने के बाद टहलें।",
            timestamp=datetime.now(timezone.utc),
        )
        assert meal.category == "HIGH_CARB"

    def test_invalid_category_rejected(self):
        from schemas import MealLogCreate

        with pytest.raises(ValueError):
            MealLogCreate(
                profile_id=1,
                category="JUNK_FOOD",  # Invalid
                glucose_impact="HIGH",
                meal_type="DINNER",
                input_method="PHOTO_GEMINI",
                timestamp=datetime.now(timezone.utc),
            )

    def test_invalid_meal_type_rejected(self):
        from schemas import MealLogCreate

        with pytest.raises(ValueError):
            MealLogCreate(
                profile_id=1,
                category="HIGH_CARB",
                glucose_impact="HIGH",
                meal_type="MIDNIGHT_SNACK",  # Invalid
                input_method="PHOTO_GEMINI",
                timestamp=datetime.now(timezone.utc),
            )

    def test_invalid_input_method_rejected(self):
        from schemas import MealLogCreate

        with pytest.raises(ValueError):
            MealLogCreate(
                profile_id=1,
                category="HIGH_CARB",
                glucose_impact="HIGH",
                meal_type="DINNER",
                input_method="VOICE_COMMAND",  # Invalid
                timestamp=datetime.now(timezone.utc),
            )

    def test_quick_select_no_confidence_required(self):
        from schemas import MealLogCreate

        meal = MealLogCreate(
            profile_id=1,
            category="LOW_CARB",
            glucose_impact="LOW",
            meal_type="LUNCH",
            input_method="QUICK_SELECT",
            timestamp=datetime.now(timezone.utc),
        )
        assert meal.confidence is None
        assert meal.tip_en is None

    def test_food_classification_response(self):
        from schemas import FoodClassificationResponse

        resp = FoodClassificationResponse(
            category="HIGH_CARB",
            glucose_impact="HIGH",
            tip_en="Walk after eating.",
            tip_hi="खाने के बाद टहलें।",
            confidence=0.85,
        )
        assert resp.category == "HIGH_CARB"
        assert resp.confidence == 0.85

    def test_meal_response_from_orm(self):
        from schemas import MealLogResponse

        resp = MealLogResponse(
            id=1,
            profile_id=1,
            logged_by=1,
            category="MODERATE_CARB",
            glucose_impact="MODERATE",
            meal_type="LUNCH",
            input_method="PHOTO_GEMINI",
            confidence=0.8,
            user_confirmed=True,
            timestamp=datetime.now(timezone.utc),
            created_at=datetime.now(timezone.utc),
        )
        assert resp.id == 1
