"""Meal Logging API Routes — Food photo classification and carb tracking."""
from fastapi import APIRouter, Depends, File, HTTPException, Query, Request, UploadFile, status
from fastapi.responses import Response
from sqlalchemy.orm import Session
from typing import Any, List, Optional
from datetime import datetime, date, timedelta, timezone
from slowapi import Limiter
from slowapi.util import get_remote_address
import os
import json
import re
import ai_service
import models
import schemas
from database import get_db
from dependencies import get_current_user, get_profile_access_or_403, get_profile_editor_or_403
from config import settings

_enabled = os.environ.get("TESTING", "").lower() != "true"
limiter = Limiter(key_func=get_remote_address, enabled=_enabled)

router = APIRouter()

# ---------------------------------------------------------------------------
# Food classification prompt — carb level only, NEVER food names
# Tip language: suggestive only ("may help", "consider") per Dr. Rajesh
# ---------------------------------------------------------------------------

FOOD_CLASSIFICATION_PROMPT = """You are a nutrition classifier for diabetic patients in India.

Look at this food photo and classify the OVERALL meal into exactly one category:
- HIGH_CARB (rice, roti, paratha, biryani, poha, noodles, bread, pasta, potatoes dominate)
- MODERATE_CARB (balanced meal — mix of carbs, protein, vegetables)
- LOW_CARB (mostly vegetables, sabzi, salad, dal without rice, sprouts)
- HIGH_PROTEIN (mostly eggs, chicken, fish, paneer, dal without carbs)
- SWEETS (mithai, desserts, gulab jamun, halwa, sugary drinks, chai with sugar)

IMPORTANT: Do NOT try to name or identify the specific food.
Only classify the carb level. We want category accuracy, not food naming.

For the health tips, use ONLY suggestive language:
- Say "may help", "consider", "could support" — NEVER "do this", "must", "should"
- Tips are for general wellness awareness, not medical advice

Respond ONLY in this exact JSON format, nothing else:
{
  "category": "HIGH_CARB",
  "glucose_impact": "HIGH",
  "tip_en": "A short walk after meals may help keep sugar levels stable.",
  "tip_hi": "खाने के बाद थोड़ी सैर करना शुगर को स्थिर रखने में मदद कर सकता है।",
  "confidence": 0.9
}"""

# ---------------------------------------------------------------------------
# Detailed Nutrition Analysis Prompt — full nutrient breakdown
# ---------------------------------------------------------------------------

NUTRITION_ANALYSIS_PROMPT = """You are a nutrition expert. Analyze this food image and return ONLY valid JSON with:
- foods: array of detected items with estimated weight in grams
- per_item: calories, carbs_g, protein_g, fat_g, fiber_g
- total: summed macros
- carb_level: "low" (<20g), "medium" (20–50g), or "high" (>50g)
- sugar_level: "low", "medium", or "high"
- micronutrients: iron_mg, calcium_mg, vitamin_c_mg estimates
- flags: is_vegan, is_vegetarian, is_gluten_free, is_high_protein booleans
- meal_score: health rating 1–10 with a one-line reason

Respond ONLY in this exact JSON format, nothing else:
{
  "foods": [
    {
      "name": "Brown Rice",
      "weight_grams": 150,
      "calories": 165,
      "carbs_g": 35,
      "protein_g": 4,
      "fat_g": 1.5,
      "fiber_g": 2
    }
  ],
  "total_calories": 450,
  "total_carbs_g": 65,
  "total_protein_g": 18,
  "total_fat_g": 12,
  "total_fiber_g": 8,
  "carb_level": "high",
  "sugar_level": "low",
  "iron_mg": 3.5,
  "calcium_mg": 120,
  "vitamin_c_mg": 15,
  "is_vegan": false,
  "is_vegetarian": true,
  "is_gluten_free": true,
  "is_high_protein": false,
  "meal_score": 7,
  "meal_score_reason": "Good fiber content with balanced macros"
}"""


# ---------------------------------------------------------------------------
# POST /meals — save a meal log
# ---------------------------------------------------------------------------

@router.post("/meals", status_code=status.HTTP_201_CREATED)
@limiter.limit("20/minute")
async def create_meal(
    request: Request,
    meal_data: schemas.MealLogCreate,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """Save a meal log from photo classification or quick select."""
    get_profile_access_or_403(meal_data.profile_id, user, db)

    meal = models.MealLog(
        profile_id=meal_data.profile_id,
        logged_by=user.id,
        category=meal_data.category,
        glucose_impact=meal_data.glucose_impact,
        tip_en=meal_data.tip_en,
        tip_hi=meal_data.tip_hi,
        meal_type=meal_data.meal_type,
        input_method=meal_data.input_method,
        confidence=meal_data.confidence,
        user_confirmed=meal_data.user_confirmed,
        user_corrected_category=meal_data.user_corrected_category,
        timestamp=meal_data.timestamp,
    )
    db.add(meal)
    db.commit()
    db.refresh(meal)

    return schemas.MealLogResponse.model_validate(meal)


# ---------------------------------------------------------------------------
# GET /meals — list meals for a profile
# ---------------------------------------------------------------------------

@router.get("/meals", response_model=List[schemas.MealLogResponse])
@limiter.limit("20/minute")
async def list_meals(
    request: Request,
    profile_id: int = Query(...),
    days: int = Query(30, ge=1, le=365),
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """List meals for a profile within the given date range."""
    access = get_profile_access_or_403(profile_id, user, db)

    since = datetime.now(timezone.utc) - timedelta(days=days)
    meals = (
        db.query(models.MealLog)
        .filter(
            models.MealLog.profile_id == profile_id,
            models.MealLog.timestamp >= since,
        )
        .order_by(models.MealLog.timestamp.desc())
        .all()
    )

    results = []
    for m in meals:
        resp = schemas.MealLogResponse.model_validate(m)
        # Viewers cannot see photo paths (Rajesh #4 — photo privacy)
        if access.access_level == "viewer":
            resp.photo_path = None
        results.append(resp)
    return results


# ---------------------------------------------------------------------------
# GET /meals/today — today's meals for dashboard summary
# ---------------------------------------------------------------------------

@router.get("/meals/today", response_model=List[schemas.MealLogResponse], deprecated=True)
@limiter.limit("20/minute")
async def today_meals(
    request: Request,
    profile_id: int = Query(...),
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """Deprecated: use GET /meals?days=1 instead."""
    get_profile_access_or_403(profile_id, user, db)

    today_start = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
    meals = (
        db.query(models.MealLog)
        .filter(
            models.MealLog.profile_id == profile_id,
            models.MealLog.timestamp >= today_start,
        )
        .order_by(models.MealLog.timestamp.asc())
        .all()
    )
    return [schemas.MealLogResponse.model_validate(m) for m in meals]


# ---------------------------------------------------------------------------
# DELETE /meals/{id}
# ---------------------------------------------------------------------------

@router.delete("/meals/{meal_id}", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit("20/minute")
async def delete_meal(
    request: Request,
    meal_id: int,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """Delete a meal log. Requires access to the profile."""
    meal = db.query(models.MealLog).filter(models.MealLog.id == meal_id).first()
    if not meal:
        raise HTTPException(status_code=404, detail="Meal not found")

    get_profile_access_or_403(meal.profile_id, user, db)

    db.delete(meal)
    db.commit()
    return Response(status_code=204)


# ---------------------------------------------------------------------------
# POST /meals/parse-image — Gemini Vision food classification
# ---------------------------------------------------------------------------

@router.post("/meals/parse-image")
@limiter.limit("20/minute")
async def parse_food_image(
    request: Request,
    profile_id: int = Query(...),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """Classify food photo by carb level using Gemini Vision.

    Returns classification JSON. Never raises 500 — returns
    {"error": "..."} so Flutter can fall back to Quick Select.
    """
    get_profile_access_or_403(profile_id, user, db)

    if not settings.GEMINI_API_KEY and not settings.DEEPSEEK_API_KEY:
        return {"error": "No AI API key configured"}

    try:
        image_bytes = await file.read()
        if len(image_bytes) > settings.MAX_UPLOAD_SIZE_BYTES:
            return {"error": f"File too large. Max size: {settings.MAX_UPLOAD_SIZE_BYTES // (1024*1024)} MB"}
        mime_type = file.content_type or "image/jpeg"
        
        # Defence-in-depth: validate MIME type against allowlist
        if mime_type == "application/octet-stream":
            fname = (file.filename or "").lower()
            if fname.endswith(".png"):
                mime_type = "image/png"
            elif fname.endswith(".webp"):
                mime_type = "image/webp"
            else:
                mime_type = "image/jpeg"
        
        if mime_type not in settings.ALLOWED_IMAGE_MIME_TYPES:
            return {"error": f"Unsupported file type. Allowed: {', '.join(settings.ALLOWED_IMAGE_MIME_TYPES)}"}

        import ai_service
        result_text = ai_service.generate_vision_insight(
            FOOD_CLASSIFICATION_PROMPT, image_bytes, profile_id, db,
            prompt_summary="food-classification",
            mime_type=mime_type,
        )

        if not result_text:
            return {"error": "AI could not process the image. Please use Quick Select."}

        json_match = re.search(r"\{[^{}]+\}", result_text, re.DOTALL)
        if not json_match:
            return {"error": "AI returned unexpected format. Please use Quick Select."}

        parsed = json.loads(json_match.group())

        category = parsed.get("category", "").upper()
        if category not in schemas.MEAL_CATEGORIES:
            return {"error": "AI returned invalid category. Please use Quick Select."}

        glucose_impact = parsed.get("glucose_impact", "MODERATE").upper()
        if glucose_impact not in schemas.GLUCOSE_IMPACT_OPTIONS:
            glucose_impact = "MODERATE"

        confidence = parsed.get("confidence", 0.5)
        if not isinstance(confidence, (int, float)):
            confidence = 0.5

        return {
            "category": category,
            "glucose_impact": glucose_impact,
            "tip_en": parsed.get("tip_en", ""),
            "tip_hi": parsed.get("tip_hi", ""),
            "confidence": round(float(confidence), 2),
        }

    except (json.JSONDecodeError, KeyError):
        return {"error": "AI returned unexpected format. Please use Quick Select."}
    except Exception:
        return {"error": "Food classification failed. Please use Quick Select."}


# ---------------------------------------------------------------------------
# POST /meals/analyze-nutrition — detailed nutrition analysis
# ---------------------------------------------------------------------------


def _safe_float(value: Any, default: float = 0.0) -> float:
    """Safely convert a value to float, handling N/A, null, strings with units, etc."""
    if value is None:
        return default
    if isinstance(value, (int, float)):
        return float(value)
    # Try to extract numeric value from string (e.g., "150 kcal" -> 150.0)
    if isinstance(value, str):
        # Remove common units and whitespace
        cleaned = value.strip().lower()
        # Remove common suffixes (longer suffixes first to avoid partial matches)
        for suffix in ['kcal', 'cal', 'mg', 'kj', 'g']:
            cleaned = cleaned.replace(suffix, '').strip()
        try:
            return float(cleaned)
        except (ValueError, TypeError):
            return default
    return default


@router.post(
    "/meals/analyze-nutrition",
    status_code=status.HTTP_200_OK,
    response_model=schemas.NutritionAnalysisResult,
)
@limiter.limit("3/minute")
async def analyze_nutrition(
    request: Request,
    profile_id: int = Query(..., gt=0),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    """Analyze food photo for detailed nutrition breakdown using Gemini Vision."""
    get_profile_access_or_403(profile_id, user, db)

    # DeepSeek does not support vision — Gemini is the only supported provider here.
    if not settings.GEMINI_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="No Gemini API key configured",
        )

    try:
        # Validate MIME type before reading file
        mime_type = file.content_type
        if mime_type == "application/octet-stream":
            # Reject unknown types instead of defaulting to JPEG
            raise HTTPException(
                status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
                detail="Unknown file type. Please upload a valid image (JPEG, PNG, or WebP).",
            )
        
        if not mime_type or mime_type not in settings.ALLOWED_IMAGE_MIME_TYPES:
            raise HTTPException(
                status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
                detail=f"Unsupported file type. Allowed: {', '.join(settings.ALLOWED_IMAGE_MIME_TYPES)}",
            )

        # Read and validate file size
        image_bytes = await file.read()
        if len(image_bytes) > settings.MAX_UPLOAD_SIZE_BYTES:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail=f"File too large. Max size: {settings.MAX_UPLOAD_SIZE_BYTES // (1024*1024)} MB",
            )

        result_text = ai_service.generate_vision_insight(
            NUTRITION_ANALYSIS_PROMPT, image_bytes, profile_id, db,
            prompt_summary="nutrition-analysis",
            mime_type=mime_type,
        )

        if not result_text:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="AI could not process the image. Please try again.",
            )

        json_match = re.search(r"\{[\s\S]*\}", result_text, re.DOTALL)
        if not json_match:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="AI returned unexpected format. Please try again.",
            )

        parsed = json.loads(json_match.group())

        # Validate required fields
        if "foods" not in parsed or not isinstance(parsed["foods"], list):
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Invalid food data returned",
            )

        # Validate and clean food items
        validated_foods = []
        for food in parsed["foods"]:
            validated_foods.append({
                "name": str(food.get("name", "Unknown")),
                "weight_grams": float(food.get("weight_grams", 0)),
                "calories": float(food.get("calories", 0)),
                "carbs_g": float(food.get("carbs_g", 0)),
                "protein_g": float(food.get("protein_g", 0)),
                "fat_g": float(food.get("fat_g", 0)),
                "fiber_g": float(food.get("fiber_g", 0)),
            })

        # Build response with validation
        carb_level = parsed.get("carb_level", "medium")
        if carb_level not in ("low", "medium", "high"):
            carb_level = "medium"
        
        sugar_level = parsed.get("sugar_level", "medium")
        if sugar_level not in ("low", "medium", "high"):
            sugar_level = "medium"
        
        meal_score = parsed.get("meal_score")
        if meal_score is not None:
            try:
                meal_score = max(1, min(10, int(meal_score)))
            except (ValueError, TypeError):
                meal_score = None
        
        response = {
            "foods": validated_foods,
            "total_calories": _safe_float(parsed.get("total_calories", 0)),
            "total_carbs_g": _safe_float(parsed.get("total_carbs_g", 0)),
            "total_protein_g": _safe_float(parsed.get("total_protein_g", 0)),
            "total_fat_g": _safe_float(parsed.get("total_fat_g", 0)),
            "total_fiber_g": _safe_float(parsed.get("total_fiber_g", 0)),
            "carb_level": carb_level,
            "sugar_level": sugar_level,
        }

        # Optional fields
        if "iron_mg" in parsed:
            response["iron_mg"] = _safe_float(parsed["iron_mg"])
        if "calcium_mg" in parsed:
            response["calcium_mg"] = _safe_float(parsed["calcium_mg"])
        if "vitamin_c_mg" in parsed:
            response["vitamin_c_mg"] = _safe_float(parsed["vitamin_c_mg"])
        if "is_vegan" in parsed:
            response["is_vegan"] = bool(parsed["is_vegan"])
        if "is_vegetarian" in parsed:
            response["is_vegetarian"] = bool(parsed["is_vegetarian"])
        if "is_gluten_free" in parsed:
            response["is_gluten_free"] = bool(parsed["is_gluten_free"])
        if "is_high_protein" in parsed:
            response["is_high_protein"] = bool(parsed["is_high_protein"])
        if meal_score is not None:
            response["meal_score"] = meal_score
        if "meal_score_reason" in parsed:
            # Trim verbose responses to prevent payload bloat
            reason = str(parsed["meal_score_reason"])[:200]
            response["meal_score_reason"] = reason

        return response

    except HTTPException:
        raise
    except (json.JSONDecodeError, KeyError):
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="AI returned unexpected format. Please try again.",
        )
    except Exception as e:
        import logging
        logger = logging.getLogger(__name__)
        logger.error(f"Nutrition analysis failed: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Nutrition analysis failed. Please try again.",
        )
