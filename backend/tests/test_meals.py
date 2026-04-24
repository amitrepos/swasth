"""Tests for Meal Logging feature — MealLog model, schemas, and API endpoints."""
import pytest
from datetime import datetime, timezone, timedelta
from unittest.mock import patch, MagicMock
import models


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


# ---------------------------------------------------------------------------
# API endpoint tests
# ---------------------------------------------------------------------------

def _get_profile_id(db, user_id):
    """Helper to get the test user's profile ID."""
    import models
    access = db.query(models.ProfileAccess).filter_by(user_id=user_id).first()
    return access.profile_id


class TestMealCreateEndpoint:
    """Test POST /meals"""

    def test_create_meal_quick_select(self, client, auth_headers, db, test_user):
        profile_id = _get_profile_id(db, test_user.id)
        resp = client.post("/api/meals", json={
            "profile_id": profile_id,
            "category": "HIGH_CARB",
            "glucose_impact": "HIGH",
            "meal_type": "DINNER",
            "input_method": "QUICK_SELECT",
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }, headers=auth_headers)
        assert resp.status_code == 201
        data = resp.json()
        assert data["category"] == "HIGH_CARB"
        assert data["input_method"] == "QUICK_SELECT"
        assert data["id"] is not None

    def test_create_meal_requires_auth(self, client):
        resp = client.post("/api/meals", json={
            "profile_id": 1,
            "category": "HIGH_CARB",
            "glucose_impact": "HIGH",
            "meal_type": "DINNER",
            "input_method": "QUICK_SELECT",
            "timestamp": datetime.now(timezone.utc).isoformat(),
        })
        assert resp.status_code == 401

    def test_create_meal_invalid_category(self, client, auth_headers, db, test_user):
        profile_id = _get_profile_id(db, test_user.id)
        resp = client.post("/api/meals", json={
            "profile_id": profile_id,
            "category": "JUNK_FOOD",
            "glucose_impact": "HIGH",
            "meal_type": "DINNER",
            "input_method": "QUICK_SELECT",
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }, headers=auth_headers)
        assert resp.status_code == 422


class TestMealListEndpoint:
    """Test GET /meals"""

    def test_list_meals_empty(self, client, auth_headers, db, test_user):
        profile_id = _get_profile_id(db, test_user.id)
        resp = client.get(f"/api/meals?profile_id={profile_id}", headers=auth_headers)
        assert resp.status_code == 200
        assert resp.json() == []

    def test_list_meals_returns_created(self, client, auth_headers, db, test_user):
        profile_id = _get_profile_id(db, test_user.id)
        # Create a meal first
        client.post("/api/meals", json={
            "profile_id": profile_id,
            "category": "LOW_CARB",
            "glucose_impact": "LOW",
            "meal_type": "LUNCH",
            "input_method": "QUICK_SELECT",
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }, headers=auth_headers)

        resp = client.get(f"/api/meals?profile_id={profile_id}", headers=auth_headers)
        assert resp.status_code == 200
        meals = resp.json()
        assert len(meals) >= 1
        assert meals[0]["category"] == "LOW_CARB"

    def test_list_meals_requires_auth(self, client):
        resp = client.get("/api/meals?profile_id=1")
        assert resp.status_code == 401


class TestMealTodayEndpoint:
    """Test GET /meals/today"""

    def test_today_meals(self, client, auth_headers, db, test_user):
        profile_id = _get_profile_id(db, test_user.id)
        # Create today's meal
        client.post("/api/meals", json={
            "profile_id": profile_id,
            "category": "SWEETS",
            "glucose_impact": "VERY_HIGH",
            "meal_type": "SNACK",
            "input_method": "QUICK_SELECT",
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }, headers=auth_headers)

        resp = client.get(f"/api/meals/today?profile_id={profile_id}", headers=auth_headers)
        assert resp.status_code == 200
        meals = resp.json()
        assert len(meals) >= 1


class TestMealDeleteEndpoint:
    """Test DELETE /meals/{id}"""

    def test_delete_meal(self, client, auth_headers, db, test_user):
        profile_id = _get_profile_id(db, test_user.id)
        # Create then delete
        create_resp = client.post("/api/meals", json={
            "profile_id": profile_id,
            "category": "HIGH_PROTEIN",
            "glucose_impact": "LOW",
            "meal_type": "BREAKFAST",
            "input_method": "QUICK_SELECT",
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }, headers=auth_headers)
        meal_id = create_resp.json()["id"]

        del_resp = client.delete(f"/api/meals/{meal_id}", headers=auth_headers)
        assert del_resp.status_code == 204

    def test_delete_nonexistent_meal(self, client, auth_headers):
        resp = client.delete("/api/meals/99999", headers=auth_headers)
        assert resp.status_code == 404


class TestMealParseImage:
    """Test POST /meals/parse-image"""

    @patch("ai_service.generate_vision_insight")
    @patch("routes_meals.settings")
    def test_parse_image_success(self, mock_settings, mock_vision, client, auth_headers, db, test_user):
        mock_settings.GEMINI_API_KEY = "fake-key"
        mock_settings.DEEPSEEK_API_KEY = ""
        mock_settings.ALLOWED_IMAGE_MIME_TYPES = ["image/jpeg", "image/png", "image/webp"]
        mock_settings.MAX_UPLOAD_SIZE_BYTES = 10_485_760
        mock_vision.return_value = '{"category": "HIGH_CARB", "glucose_impact": "HIGH", "tip_en": "A short walk after meals may help keep sugar levels stable.", "tip_hi": "खाने के बाद थोड़ी सैर करना शुगर को स्थिर रखने में मदद कर सकता है।", "confidence": 0.88}'

        profile_id = _get_profile_id(db, test_user.id)
        import io
        fake_image = io.BytesIO(b"\xff\xd8\xff\xe0" + b"\x00" * 100)

        resp = client.post(
            f"/api/meals/parse-image?profile_id={profile_id}",
            files={"file": ("food.jpg", fake_image, "image/jpeg")},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["category"] == "HIGH_CARB"
        assert data["confidence"] == 0.88

    @patch("ai_service.generate_vision_insight")
    def test_parse_image_returns_error_on_failure(self, mock_vision, client, auth_headers, db, test_user):
        mock_vision.return_value = None  # Gemini failed

        profile_id = _get_profile_id(db, test_user.id)
        import io
        fake_image = io.BytesIO(b"\xff\xd8\xff\xe0" + b"\x00" * 100)

        resp = client.post(
            f"/api/meals/parse-image?profile_id={profile_id}",
            files={"file": ("food.jpg", fake_image, "image/jpeg")},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        assert "error" in resp.json()

    def test_parse_image_requires_auth(self, client):
        import io
        fake_image = io.BytesIO(b"\xff\xd8\xff\xe0" + b"\x00" * 100)
        resp = client.post(
            "/api/meals/parse-image?profile_id=1",
            files={"file": ("food.jpg", fake_image, "image/jpeg")},
        )
        assert resp.status_code == 401


class TestMealAnalyzeNutrition:
    """Test POST /meals/analyze-nutrition"""

    @patch("ai_service.generate_vision_insight")
    @patch("routes_meals.settings")
    def test_analyze_nutrition_success(self, mock_settings, mock_vision, client, auth_headers, db, test_user):
        """Successful nutrition analysis returns full breakdown."""
        mock_settings.GEMINI_API_KEY = "fake-key"
        mock_settings.ALLOWED_IMAGE_MIME_TYPES = ["image/jpeg", "image/png", "image/webp"]
        mock_settings.MAX_UPLOAD_SIZE_BYTES = 10_485_760
        mock_vision.return_value = '''
        {
            "foods": [
                {"name": "Rice", "weight_grams": 200, "calories": 260, "carbs_g": 58, "protein_g": 5, "fat_g": 0.5, "fiber_g": 1}
            ],
            "total_calories": 260,
            "total_carbs_g": 58,
            "total_protein_g": 5,
            "total_fat_g": 0.5,
            "total_fiber_g": 1,
            "carb_level": "high",
            "sugar_level": "medium",
            "iron_mg": 2.5,
            "calcium_mg": 30,
            "vitamin_c_mg": 0,
            "is_vegan": true,
            "is_vegetarian": true,
            "is_gluten_free": true,
            "is_high_protein": false,
            "meal_score": 7,
            "meal_score_reason": "Good fiber content with balanced macros"
        }
        '''

        profile_id = _get_profile_id(db, test_user.id)
        import io
        fake_image = io.BytesIO(b"\xff\xd8\xff\xe0" + b"\x00" * 100)

        resp = client.post(
            f"/api/meals/analyze-nutrition?profile_id={profile_id}",
            files={"file": ("food.jpg", fake_image, "image/jpeg")},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.json()
        assert "foods" in data
        assert len(data["foods"]) == 1
        assert data["foods"][0]["name"] == "Rice"
        assert data["total_calories"] == 260
        assert data["carb_level"] == "high"
        assert data["sugar_level"] == "medium"
        assert data["iron_mg"] == 2.5
        assert data["is_vegan"] is True
        assert data["meal_score"] == 7

    @patch("ai_service.generate_vision_insight")
    def test_analyze_nutrition_returns_error_on_failure(self, mock_vision, client, auth_headers, db, test_user):
        """When AI fails, returns 502 error."""
        from config import settings as real_settings
        with patch("routes_meals.settings") as mock_settings:
            mock_settings.GEMINI_API_KEY = real_settings.GEMINI_API_KEY or "fake-key"
            mock_settings.ALLOWED_IMAGE_MIME_TYPES = ["image/jpeg", "image/png", "image/webp"]
            mock_settings.MAX_UPLOAD_SIZE_BYTES = 10_485_760
            mock_vision.return_value = None  # Gemini failed

            profile_id = _get_profile_id(db, test_user.id)
            import io
            fake_image = io.BytesIO(b"\xff\xd8\xff\xe0" + b"\x00" * 100)

            resp = client.post(
                f"/api/meals/analyze-nutrition?profile_id={profile_id}",
                files={"file": ("food.jpg", fake_image, "image/jpeg")},
                headers=auth_headers,
            )
            assert resp.status_code == 502  # Should return 502 for AI failures

    @patch("routes_meals.settings")
    def test_analyze_nutrition_no_api_key(self, mock_settings, client, auth_headers, db, test_user):
        """Returns error when no Gemini API key configured."""
        mock_settings.GEMINI_API_KEY = ""
        mock_settings.ALLOWED_IMAGE_MIME_TYPES = ["image/jpeg", "image/png", "image/webp"]
        mock_settings.MAX_UPLOAD_SIZE_BYTES = 10_485_760

        profile_id = _get_profile_id(db, test_user.id)
        import io
        fake_image = io.BytesIO(b"\xff\xd8\xff\xe0" + b"\x00" * 100)

        resp = client.post(
            f"/api/meals/analyze-nutrition?profile_id={profile_id}",
            files={"file": ("food.jpg", fake_image, "image/jpeg")},
            headers=auth_headers,
        )
        assert resp.status_code == 503  # Now returns proper HTTP error
        assert "No Gemini API key" in resp.json()["detail"]

    @patch("ai_service.generate_vision_insight")
    @patch("routes_meals.settings")
    def test_analyze_nutrition_invalid_json(self, mock_settings, mock_vision, client, auth_headers, db, test_user):
        """Returns error when AI returns non-JSON."""
        mock_settings.GEMINI_API_KEY = "fake-key"
        mock_settings.ALLOWED_IMAGE_MIME_TYPES = ["image/jpeg", "image/png", "image/webp"]
        mock_settings.MAX_UPLOAD_SIZE_BYTES = 10_485_760
        mock_vision.return_value = "This is not JSON at all"

        profile_id = _get_profile_id(db, test_user.id)
        import io
        fake_image = io.BytesIO(b"\xff\xd8\xff\xe0" + b"\x00" * 100)

        resp = client.post(
            f"/api/meals/analyze-nutrition?profile_id={profile_id}",
            files={"file": ("food.jpg", fake_image, "image/jpeg")},
            headers=auth_headers,
        )
        assert resp.status_code == 502  # Now returns proper HTTP error

    @patch("ai_service.generate_vision_insight")
    @patch("routes_meals.settings")
    def test_analyze_nutrition_missing_foods_field(self, mock_settings, mock_vision, client, auth_headers, db, test_user):
        """Returns error when AI response missing required 'foods' field."""
        mock_settings.GEMINI_API_KEY = "fake-key"
        mock_settings.ALLOWED_IMAGE_MIME_TYPES = ["image/jpeg", "image/png", "image/webp"]
        mock_settings.MAX_UPLOAD_SIZE_BYTES = 10_485_760
        mock_vision.return_value = '{"total_calories": 100}'

        profile_id = _get_profile_id(db, test_user.id)
        import io
        fake_image = io.BytesIO(b"\xff\xd8\xff\xe0" + b"\x00" * 100)

        resp = client.post(
            f"/api/meals/analyze-nutrition?profile_id={profile_id}",
            files={"file": ("food.jpg", fake_image, "image/jpeg")},
            headers=auth_headers,
        )
        assert resp.status_code == 502  # Now returns proper HTTP error

    @patch("ai_service.generate_vision_insight")
    @patch("routes_meals.settings")
    def test_analyze_nutrition_exception_does_not_leak_details(self, mock_settings, mock_vision, client, auth_headers, db, test_user):
        """Exception handler returns generic message, not raw exception."""
        mock_settings.GEMINI_API_KEY = "fake-key"
        mock_settings.ALLOWED_IMAGE_MIME_TYPES = ["image/jpeg", "image/png", "image/webp"]
        mock_settings.MAX_UPLOAD_SIZE_BYTES = 10_485_760
        mock_vision.side_effect = Exception("DatabaseError: connection refused at 10.0.0.5:5432")

        profile_id = _get_profile_id(db, test_user.id)
        import io
        fake_image = io.BytesIO(b"\xff\xd8\xff\xe0" + b"\x00" * 100)

        resp = client.post(
            f"/api/meals/analyze-nutrition?profile_id={profile_id}",
            files={"file": ("food.jpg", fake_image, "image/jpeg")},
            headers=auth_headers,
        )
        assert resp.status_code == 500  # Now returns proper HTTP error
        error_msg = resp.json()["detail"]
        assert "Nutrition analysis failed" in error_msg
        # Ensure no internal details leaked
        assert "DatabaseError" not in error_msg
        assert "10.0.0.5" not in error_msg
        assert "5432" not in error_msg

    def test_analyze_nutrition_requires_auth(self, client):
        import io
        fake_image = io.BytesIO(b"\xff\xd8\xff\xe0" + b"\x00" * 100)
        resp = client.post(
            "/api/meals/analyze-nutrition?profile_id=1",
            files={"file": ("food.jpg", fake_image, "image/jpeg")},
        )
        assert resp.status_code == 401

    def test_analyze_nutrition_cross_user_denied(self, client, db, test_user, auth_headers):
        """User A cannot call analyze-nutrition with User B's profile_id."""
        from auth import get_password_hash, create_access_token
        from utils.phone import normalize_phone

        # Create a second user with their own profile
        user_b = models.User(
            email="userb@swasth.app",
            password_hash=get_password_hash("UserB@1234"),
            full_name="User B",
            phone_number=normalize_phone("9876500099"),
        )
        db.add(user_b)
        db.flush()

        profile_b = models.Profile(
            name="User B Profile",
            phone_number=normalize_phone("9876500099"),
        )
        db.add(profile_b)
        db.flush()

        access_b = models.ProfileAccess(
            user_id=user_b.id,
            profile_id=profile_b.id,
            access_level="owner",
        )
        db.add(access_b)
        db.flush()

        # User A (test_user) tries to analyze nutrition for User B's profile
        import io
        fake_image = io.BytesIO(b"\xff\xd8\xff\xe0" + b"\x00" * 100)

        resp = client.post(
            f"/api/meals/analyze-nutrition?profile_id={profile_b.id}",
            files={"file": ("food.jpg", fake_image, "image/jpeg")},
            headers=auth_headers,  # User A's auth token
        )
        # Should be denied — either 403 or 404 (profile not accessible)
        assert resp.status_code in [403, 404]

    @patch("routes_meals.settings")
    def test_analyze_nutrition_file_too_large(self, mock_settings, client, auth_headers, db, test_user):
        """Returns 413 when file exceeds MAX_UPLOAD_SIZE_BYTES."""
        mock_settings.GEMINI_API_KEY = "fake-key"
        mock_settings.ALLOWED_IMAGE_MIME_TYPES = ["image/jpeg", "image/png", "image/webp"]
        mock_settings.MAX_UPLOAD_SIZE_BYTES = 50  # Very small limit for testing

        profile_id = _get_profile_id(db, test_user.id)
        import io
        # Create a file larger than 50 bytes
        large_image = io.BytesIO(b"\xff\xd8\xff\xe0" + b"\x00" * 100)

        resp = client.post(
            f"/api/meals/analyze-nutrition?profile_id={profile_id}",
            files={"file": ("food.jpg", large_image, "image/jpeg")},
            headers=auth_headers,
        )
        assert resp.status_code == 413
        assert "File too large" in resp.json()["detail"]

    @patch("routes_meals.settings")
    def test_analyze_nutrition_unsupported_mime_type(self, mock_settings, client, auth_headers, db, test_user):
        """Returns 415 when file MIME type is not allowed."""
        mock_settings.GEMINI_API_KEY = "fake-key"
        mock_settings.ALLOWED_IMAGE_MIME_TYPES = ["image/jpeg", "image/png", "image/webp"]
        mock_settings.MAX_UPLOAD_SIZE_BYTES = 10_485_760

        profile_id = _get_profile_id(db, test_user.id)
        import io
        fake_image = io.BytesIO(b"\xff\xd8\xff\xe0" + b"\x00" * 100)

        resp = client.post(
            f"/api/meals/analyze-nutrition?profile_id={profile_id}",
            files={"file": ("food.gif", fake_image, "image/gif")},
            headers=auth_headers,
        )
        assert resp.status_code == 415
        assert "Unsupported file type" in resp.json()["detail"]

    @patch("routes_meals.settings")
    def test_analyze_nutrition_octet_stream_rejected(self, mock_settings, client, auth_headers, db, test_user):
        """Returns 415 when file MIME type is application/octet-stream."""
        mock_settings.GEMINI_API_KEY = "fake-key"
        mock_settings.ALLOWED_IMAGE_MIME_TYPES = ["image/jpeg", "image/png", "image/webp"]
        mock_settings.MAX_UPLOAD_SIZE_BYTES = 10_485_760

        profile_id = _get_profile_id(db, test_user.id)
        import io
        fake_image = io.BytesIO(b"\xff\xd8\xff\xe0" + b"\x00" * 100)

        resp = client.post(
            f"/api/meals/analyze-nutrition?profile_id={profile_id}",
            files={"file": ("food.bin", fake_image, "application/octet-stream")},
            headers=auth_headers,
        )
        assert resp.status_code == 415
        assert "Unknown file type" in resp.json()["detail"]


class TestSafeFloat:
    """Test _safe_float utility function edge cases."""

    def test_safe_float_with_na_string(self):
        """_safe_float handles 'N/A' string correctly."""
        from routes_meals import _safe_float
        assert _safe_float("N/A") == 0.0
        assert _safe_float("N/A", default=1.5) == 1.5

    def test_safe_float_with_unit_string(self):
        """_safe_float extracts number from strings with units like '150 kcal'."""
        from routes_meals import _safe_float
        assert _safe_float("150 kcal") == 150.0
        assert _safe_float("58g") == 58.0
        assert _safe_float("2.5 mg") == 2.5
        assert _safe_float("100 cal") == 100.0
        assert _safe_float("50 kj") == 50.0

    def test_safe_float_with_empty_string(self):
        """_safe_float handles empty string correctly."""
        from routes_meals import _safe_float
        assert _safe_float("") == 0.0
        assert _safe_float("  ") == 0.0

    def test_safe_float_with_none(self):
        """_safe_float handles None correctly."""
        from routes_meals import _safe_float
        assert _safe_float(None) == 0.0
        assert _safe_float(None, default=5.0) == 5.0

    def test_safe_float_with_numeric_types(self):
        """_safe_float handles int and float correctly."""
        from routes_meals import _safe_float
        assert _safe_float(42) == 42.0
        assert _safe_float(3.14) == 3.14
        assert _safe_float(0) == 0.0

    def test_safe_float_with_invalid_string(self):
        """_safe_float returns default for non-numeric strings."""
        from routes_meals import _safe_float
        assert _safe_float("abc") == 0.0
        assert _safe_float("high", default=2.0) == 2.0
