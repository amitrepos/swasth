"""
Central AI service with multi-model fallback chain and audit logging.

Text chain: DeepSeek → Gemini → rule-based
Vision chain: Gemini (with key rotation) → Groq → DeepSeek text → None
Every call is logged to the ai_insight_logs table for compliance.
"""
import json
import logging
import time
from typing import Optional
from sqlalchemy.orm import Session
from config import settings
import models

logger = logging.getLogger(__name__)


def _clean_ai_response(response_text: str) -> str:
    """Clean up AI response to ensure it's human-readable.
    
    If the response is JSON, convert it to a readable format.
    Otherwise, return the text as-is.
    """
    # DEBUG: Log raw response
    logger.debug(f"Raw AI response (first 300 chars): {response_text[:300]}")
    
    # Strip markdown code blocks if present
    cleaned_text = response_text.strip()
    if cleaned_text.startswith('```'):
        # Remove opening ```json or ```
        first_newline = cleaned_text.find('\n')
        if first_newline != -1:
            cleaned_text = cleaned_text[first_newline:].strip()
        # Remove closing ```
        if cleaned_text.endswith('```'):
            cleaned_text = cleaned_text[:-3].strip()
        logger.info(f"Stripped markdown code blocks")
    
    try:
        # Try to parse as JSON
        data = json.loads(cleaned_text)
        
        logger.info(f"Detected JSON response, keys: {list(data.keys()) if isinstance(data, dict) else 'not a dict'}")
        
        # If it's a nutrition analysis result, format it nicely
        if isinstance(data, dict):
            # Check if this looks like a nutrition analysis
            if 'total_calories' in data or 'meal_score' in data:
                formatted = _format_nutrition_json(data, response_text)
                logger.info(f"Formatted nutrition JSON to: {formatted[:200]}")
                return formatted
            # For other JSON, try to extract meaningful text
            # Look for common text fields
            for key in ['insight', 'summary', 'recommendation', 'advice', 'text', 'message']:
                if key in data and isinstance(data[key], str):
                    logger.info(f"Extracted text from '{key}' field")
                    return data[key]
            
            # If no obvious text field, format the JSON nicely
            # But prefer to return a summary
            formatted_parts = []
            for key, value in data.items():
                if value is not None and value != '':
                    # Format key for display
                    display_key = key.replace('_', ' ').title()
                    if isinstance(value, bool):
                        formatted_parts.append(f"{display_key}: {'Yes' if value else 'No'}")
                    elif isinstance(value, (int, float)):
                        formatted_parts.append(f"{display_key}: {value}")
                    elif isinstance(value, str):
                        formatted_parts.append(f"{display_key}: {value}")
            
            if formatted_parts:
                result = '\n'.join(formatted_parts)
                logger.info(f"Formatted generic JSON to: {result[:200]}")
                return result
        
        # If it's a list or other JSON type, try to format it
        if not isinstance(data, dict):
            # For arrays or other JSON types, return cleaned text
            logger.info(f"JSON parsed but not a dict (type: {type(data).__name__}), returning cleaned text")
            return cleaned_text
        
        logger.info("Response is not JSON, returning as-is")
        return cleaned_text
    except (json.JSONDecodeError, TypeError, ValueError) as e:
        # Not JSON, return as-is
        logger.info(f"JSON parse failed ({e}), returning as-is")
        return cleaned_text


def _format_nutrition_json(data: dict, response_text: str = "") -> str:
    """Format nutrition analysis JSON into human-readable text."""
    lines = []
    
    # Add meal score if available
    if 'meal_score' in data:
        score = data['meal_score']
        reason = data.get('meal_score_reason', '')
        if reason:
            lines.append(f"Meal Score: {score}/10 - {reason}")
        else:
            lines.append(f"Meal Score: {score}/10")
    
    # Add total nutrition info
    totals = []
    if 'total_calories' in data:
        totals.append(f"{int(data['total_calories'])} cal")
    if 'total_protein_g' in data:
        totals.append(f"{data['total_protein_g']}g protein")
    if 'total_carbs_g' in data:
        totals.append(f"{data['total_carbs_g']}g carbs")
    if 'total_fat_g' in data:
        totals.append(f"{data['total_fat_g']}g fat")
    if 'total_fiber_g' in data:
        totals.append(f"{data['total_fiber_g']}g fiber")
    
    if totals:
        lines.append("Nutrition: " + ", ".join(totals))
    
    # Add carb and sugar levels
    if 'carb_level' in data:
        lines.append(f"Carb Level: {data['carb_level'].upper()}")
    if 'sugar_level' in data:
        lines.append(f"Sugar Level: {data['sugar_level'].upper()}")
    
    # Add dietary flags
    flags = []
    if data.get('is_vegan'):
        flags.append("Vegan")
    if data.get('is_vegetarian'):
        flags.append("Vegetarian")
    if data.get('is_gluten_free'):
        flags.append("Gluten-free")
    if data.get('is_high_protein'):
        flags.append("High-protein")
    
    if flags:
        lines.append("Diet: " + ", ".join(flags))
    
    # Add detected foods if available
    if 'foods' in data and isinstance(data['foods'], list) and data['foods']:
        food_names = [food.get('name', 'Unknown') for food in data['foods'][:3]]  # Limit to 3
        lines.append("Foods: " + ", ".join(food_names))
    
    return '\n'.join(lines) if lines else response_text


def _get_gemini_keys() -> list:
    """Get all available Gemini API keys for rotation."""
    keys = []
    if settings.GEMINI_API_KEYS:
        keys = [k.strip() for k in settings.GEMINI_API_KEYS.split(",") if k.strip()]
    if settings.GEMINI_API_KEY and settings.GEMINI_API_KEY not in keys:
        keys.insert(0, settings.GEMINI_API_KEY)
    return keys


def generate_health_insight(
    prompt: str,
    profile_id: int,
    db: Session,
    prompt_summary: Optional[str] = None,
    max_tokens: int = 300,
) -> Optional[str]:
    """Try DeepSeek first (cheap, no rate limit), then Gemini, then return None.

    DeepSeek-first saves Gemini's free quota for image scanning where it's needed.
    """

    # 1. Try DeepSeek first (cheap, reliable, no rate limit)
    if settings.DEEPSEEK_API_KEY:
        result = _try_deepseek(prompt, max_tokens=max_tokens)
        if result["text"]:
            # Clean up JSON responses to make them human-readable
            cleaned_text = _clean_ai_response(result["text"])
            _log(db, profile_id, "deepseek-chat", prompt_summary,
                 cleaned_text, None, result["tokens"], result["ms"])
            return cleaned_text
        deepseek_error = result["error"]
    else:
        deepseek_error = "DEEPSEEK_API_KEY not set"

    # 2. Fallback to Gemini
    if settings.GEMINI_API_KEY:
        result = _try_gemini(prompt, max_tokens=max_tokens)
        if result["text"]:
            # Clean up JSON responses to make them human-readable
            cleaned_text = _clean_ai_response(result["text"])
            _log(db, profile_id, "gemini-2.5-flash", prompt_summary,
                 cleaned_text, f"deepseek failed: {deepseek_error}",
                 result["tokens"], result["ms"])
            return cleaned_text
        gemini_error = result["error"]
    else:
        gemini_error = "GEMINI_API_KEY not set"

    # 3. Both failed — return None (caller will use rule-based fallback)
    _log(db, profile_id, "failed", prompt_summary,
         "AI unavailable — both models failed",
         f"deepseek: {deepseek_error}; gemini: {gemini_error}",
         None, None)
    return None


def generate_vision_insight(
    prompt: str,
    image_bytes: bytes,
    profile_id: int,
    db: Session,
    prompt_summary: Optional[str] = None,
    mime_type: str = "image/jpeg",
) -> Optional[str]:
    """Analyze image with Gemini Vision first, fallback to Groq Vision.
    
    Vision chain: Gemini (with key rotation) → Groq → None
    
    NOTE: Returns RAW response (not cleaned) for nutrition analysis.
    The caller (routes_meals.py) handles JSON parsing and formatting.
    """

    # 1. Try Gemini Vision first (with key rotation)
    keys = _get_gemini_keys()
    if keys:
        result = _try_gemini_vision(prompt, image_bytes, mime_type)
        if result["text"]:
            # Return RAW text for nutrition analysis (caller will parse JSON)
            _log(db, profile_id, "gemini-2.5-flash-vision", prompt_summary,
                 result["text"], None, result["tokens"], result["ms"])
            return result["text"]
        gemini_error = result["error"]
    else:
        gemini_error = "No Gemini API keys configured"

    # 2. Fallback to Groq Vision
    if settings.GROQ_API_KEY:
        result = _try_groq_vision(prompt, image_bytes, mime_type)
        if result["text"]:
            # Return RAW text for nutrition analysis (caller will parse JSON)
            _log(db, profile_id, "groq-llama-vision", prompt_summary,
                 result["text"], f"gemini failed: {gemini_error}",
                 result["tokens"], result["ms"])
            return result["text"]
        groq_error = result["error"]
    else:
        groq_error = "GROQ_API_KEY not set"

    # 3. Both failed
    _log(db, profile_id, "failed", prompt_summary,
         "Vision AI unavailable — both models failed",
         f"gemini: {gemini_error}; groq: {groq_error}", None, None)
    return None


def _try_gemini_vision(prompt: str, image_bytes: bytes, mime_type: str) -> dict:
    """Attempt Gemini Vision with key rotation. Returns {text, error, tokens, ms}."""
    keys = _get_gemini_keys()
    if not keys:
        return {"text": None, "error": "No Gemini API keys configured", "tokens": None, "ms": 0}

    last_error = None
    for api_key in keys:
        result = _try_gemini_vision_with_key(prompt, image_bytes, mime_type, api_key)
        if result["text"]:
            return result
        last_error = result["error"]
        if "429" not in str(last_error) and "RESOURCE_EXHAUSTED" not in str(last_error):
            return result
    return {"text": None, "error": last_error, "tokens": None, "ms": 0}


def _try_gemini_vision_with_key(prompt: str, image_bytes: bytes, mime_type: str, api_key: str) -> dict:
    """Attempt Gemini Vision with a specific API key."""
    import time
    start = time.time()
    try:
        from google import genai
        from google.genai import types as genai_types

        client = genai.Client(api_key=api_key)
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=[
                genai_types.Content(parts=[
                    genai_types.Part.from_text(text=prompt),
                    genai_types.Part.from_bytes(data=image_bytes, mime_type=mime_type),
                ]),
            ],
            config=genai_types.GenerateContentConfig(
                max_output_tokens=1024,
                temperature=0.4,
                thinking_config=genai_types.ThinkingConfig(thinking_budget=0),
            ),
        )

        text = None
        for candidate in response.candidates:
            for part in candidate.content.parts:
                if hasattr(part, "text") and part.text:
                    text = part.text.strip()
                    break
            if text:
                break

        ms = int((time.time() - start) * 1000)
        tokens = getattr(response, "usage_metadata", None)
        token_count = None
        if tokens:
            token_count = (getattr(tokens, "total_token_count", None) or
                          (getattr(tokens, "prompt_token_count", 0) +
                           getattr(tokens, "candidates_token_count", 0)))

        if not text:
            return {"text": None, "error": "Empty response", "tokens": None, "ms": ms}
        return {"text": text, "error": None, "tokens": token_count, "ms": ms}

    except Exception as e:
        ms = int((time.time() - start) * 1000)
        return {"text": None, "error": str(e)[:200], "tokens": None, "ms": ms}


def _try_gemini(prompt: str, max_tokens: int = 300) -> dict:
    """Attempt Gemini 2.5 Flash with key rotation. Returns {text, error, tokens, ms}."""
    keys = _get_gemini_keys()
    if not keys:
        return {"text": None, "error": "No Gemini API keys configured", "tokens": None, "ms": 0}

    last_error = None
    for api_key in keys:
        result = _try_gemini_with_key(prompt, api_key, max_tokens=max_tokens)
        if result["text"]:
            return result
        last_error = result["error"]
        if "429" not in str(last_error) and "RESOURCE_EXHAUSTED" not in str(last_error):
            return result  # Non-rate-limit error, don't try other keys
    return {"text": None, "error": last_error, "tokens": None, "ms": 0}


def _try_gemini_with_key(prompt: str, api_key: str, max_tokens: int = 300) -> dict:
    """Attempt Gemini with a specific API key."""
    start = time.time()
    try:
        from google import genai
        from google.genai import types as genai_types

        client = genai.Client(api_key=api_key)
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt,
            config=genai_types.GenerateContentConfig(
                max_output_tokens=max_tokens,
                temperature=0.4,
                thinking_config=genai_types.ThinkingConfig(thinking_budget=0),
            ),
        )

        text = None
        for candidate in response.candidates:
            for part in candidate.content.parts:
                if hasattr(part, "text") and part.text:
                    text = part.text.strip()
                    break
            if text:
                break

        ms = int((time.time() - start) * 1000)
        tokens = getattr(response, "usage_metadata", None)
        token_count = None
        if tokens:
            token_count = (getattr(tokens, "total_token_count", None) or
                          (getattr(tokens, "prompt_token_count", 0) +
                           getattr(tokens, "candidates_token_count", 0)))

        if not text:
            return {"text": None, "error": "Empty response", "tokens": None, "ms": ms}
        return {"text": text, "error": None, "tokens": token_count, "ms": ms}

    except Exception as e:
        ms = int((time.time() - start) * 1000)
        return {"text": None, "error": str(e)[:200], "tokens": None, "ms": ms}



def _try_groq_vision(prompt: str, image_bytes: bytes, mime_type: str) -> dict:
    """Attempt Groq Vision (Llama 4 Scout) via OpenAI-compatible API.
    
    Returns {text, error, tokens, ms}
    """
    start = time.time()
    try:
        from openai import OpenAI
        import base64

        client = OpenAI(
            api_key=settings.GROQ_API_KEY,
            base_url="https://api.groq.com/openai/v1",
        )
        
        # Convert image bytes to base64 for Groq API
        # Note: Groq has a 4MB limit for base64 encoded images
        image_base64 = base64.b64encode(image_bytes).decode('utf-8')
        
        # Check if image is within Groq's 4MB limit for base64
        if len(image_base64) > 4 * 1024 * 1024:  # 4MB
            return {
                "text": None,
                "error": f"Image too large for Groq (max 4MB for base64)",
                "tokens": None,
                "ms": 0
            }
        
        response = client.chat.completions.create(
            model="meta-llama/llama-4-scout-17b-16e-instruct",
            messages=[
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": prompt},
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:{mime_type};base64,{image_base64}"
                            }
                        }
                    ]
                }
            ],
            max_tokens=1024,
            temperature=0.4,
        )

        ms = int((time.time() - start) * 1000)
        text = response.choices[0].message.content.strip() if response.choices else None
        tokens = (response.usage.total_tokens if response.usage else None)

        if not text:
            return {"text": None, "error": "Empty response", "tokens": None, "ms": ms}
        return {"text": text, "error": None, "tokens": tokens, "ms": ms}

    except Exception as e:
        ms = int((time.time() - start) * 1000)
        return {"text": None, "error": str(e)[:200], "tokens": None, "ms": ms}


def _try_deepseek(prompt: str, max_tokens: int = 300) -> dict:
    """Attempt DeepSeek V3 via OpenAI-compatible API. Returns {text, error, tokens, ms}."""
    start = time.time()
    try:
        from openai import OpenAI

        client = OpenAI(
            api_key=settings.DEEPSEEK_API_KEY,
            base_url="https://api.deepseek.com",
        )
        response = client.chat.completions.create(
            model="deepseek-chat",
            messages=[{"role": "user", "content": prompt}],
            max_tokens=max_tokens,
            temperature=0.4,
        )

        ms = int((time.time() - start) * 1000)
        text = response.choices[0].message.content.strip() if response.choices else None
        tokens = (response.usage.total_tokens if response.usage else None)

        if not text:
            return {"text": None, "error": "Empty response", "tokens": None, "ms": ms}
        return {"text": text, "error": None, "tokens": tokens, "ms": ms}

    except Exception as e:
        ms = int((time.time() - start) * 1000)
        return {"text": None, "error": str(e)[:200], "tokens": None, "ms": ms}


def _log(
    db: Session,
    profile_id: int,
    model_used: str,
    prompt_summary: Optional[str],
    response_text: str,
    fallback_reason: Optional[str],
    tokens_used: Optional[int],
    latency_ms: Optional[int],
):
    """Write an audit row to ai_insight_logs."""
    try:
        log = models.AiInsightLog(
            profile_id=profile_id,
            model_used=model_used,
            prompt_summary=prompt_summary,
            response_text=response_text,
            fallback_reason=fallback_reason,
            tokens_used=tokens_used,
            latency_ms=latency_ms,
        )
        db.add(log)
        db.commit()
    except Exception:
        db.rollback()
