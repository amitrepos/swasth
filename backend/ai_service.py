"""
Central AI service with multi-model fallback chain and audit logging.

Text chain: DeepSeek → Gemini → rule-based
Vision chain: Gemini (with key rotation) → Groq → DeepSeek text → None
Every call is logged to the ai_insight_logs table for compliance.
"""
import time
from typing import Optional
from sqlalchemy.orm import Session
from config import settings
import models


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
            _log(db, profile_id, "deepseek-chat", prompt_summary,
                 result["text"], None, result["tokens"], result["ms"])
            return result["text"]
        deepseek_error = result["error"]
    else:
        deepseek_error = "DEEPSEEK_API_KEY not set"

    # 2. Fallback to Gemini
    if settings.GEMINI_API_KEY:
        result = _try_gemini(prompt, max_tokens=max_tokens)
        if result["text"]:
            _log(db, profile_id, "gemini-2.5-flash", prompt_summary,
                 result["text"], f"deepseek failed: {deepseek_error}",
                 result["tokens"], result["ms"])
            return result["text"]
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
    """Analyze image with Gemini Vision (with key rotation). Gemini-only for accuracy."""

    keys = _get_gemini_keys()
    if not keys:
        _log(db, profile_id, "failed", prompt_summary,
             "No Gemini API keys configured", None, None, None)
        return None

    result = _try_gemini_vision(prompt, image_bytes, mime_type)
    if result["text"]:
        _log(db, profile_id, "gemini-2.5-flash-vision", prompt_summary,
             result["text"], None, result["tokens"], result["ms"])
        return result["text"]

    _log(db, profile_id, "failed", prompt_summary,
         "Gemini Vision failed to analyze image",
         result["error"], None, result["ms"])
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
