"""Meal Logging API Routes — Food photo classification and carb tracking."""
from fastapi import APIRouter, Depends, File, HTTPException, Query, Request, UploadFile, status
from fastapi.responses import Response
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime, date, timedelta, timezone
from slowapi import Limiter
from slowapi.util import get_remote_address
import os
import json
import re
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
        mime_type = file.content_type or "image/jpeg"
        if mime_type == "application/octet-stream":
            fname = (file.filename or "").lower()
            if fname.endswith(".png"):
                mime_type = "image/png"
            else:
                mime_type = "image/jpeg"

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
