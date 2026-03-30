"""
Central AI service with multi-model fallback chain and audit logging.

Chain: Gemini 2.5 Flash → DeepSeek V3 → None (caller uses rule-based fallback)
Every call is logged to the ai_insight_logs table for compliance.
"""
import time
from typing import Optional
from sqlalchemy.orm import Session
from config import settings
import models


def generate_health_insight(
    prompt: str,
    profile_id: int,
    db: Session,
    prompt_summary: Optional[str] = None,
) -> Optional[str]:
    """Try Gemini, then DeepSeek, then return None. Always logs to DB."""

    # 1. Try Gemini
    if settings.GEMINI_API_KEY:
        result = _try_gemini(prompt)
        if result["text"]:
            _log(db, profile_id, "gemini-2.5-flash", prompt_summary,
                 result["text"], None, result["tokens"], result["ms"])
            return result["text"]
        gemini_error = result["error"]
    else:
        gemini_error = "GEMINI_API_KEY not set"

    # 2. Try DeepSeek
    if settings.DEEPSEEK_API_KEY:
        result = _try_deepseek(prompt)
        if result["text"]:
            _log(db, profile_id, "deepseek-chat", prompt_summary,
                 result["text"], f"gemini failed: {gemini_error}",
                 result["tokens"], result["ms"])
            return result["text"]
        deepseek_error = result["error"]
    else:
        deepseek_error = "DEEPSEEK_API_KEY not set"

    # 3. Both failed — return None (caller will use rule-based fallback)
    # Log the failure so we have an audit trail
    _log(db, profile_id, "failed", prompt_summary,
         "AI unavailable — both models failed",
         f"gemini: {gemini_error}; deepseek: {deepseek_error}",
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
    """Analyze an image with Gemini Vision, fall back to DeepSeek (text-only), then None."""

    # 1. Try Gemini Vision
    if settings.GEMINI_API_KEY:
        result = _try_gemini_vision(prompt, image_bytes, mime_type)
        if result["text"]:
            _log(db, profile_id, "gemini-2.5-flash-vision", prompt_summary,
                 result["text"], None, result["tokens"], result["ms"])
            return result["text"]
        gemini_error = result["error"]
    else:
        gemini_error = "GEMINI_API_KEY not set"

    # 2. Fall back to DeepSeek (text-only — describe that an image was uploaded)
    if settings.DEEPSEEK_API_KEY:
        fallback_prompt = (
            f"{prompt}\n\n"
            "Note: The patient uploaded a medical image but image analysis is temporarily unavailable. "
            "Based on the text context above, provide what advice you can and recommend they consult their doctor "
            "for interpretation of the image."
        )
        result = _try_deepseek(fallback_prompt)
        if result["text"]:
            _log(db, profile_id, "deepseek-chat", prompt_summary,
                 result["text"], f"gemini vision failed: {gemini_error}",
                 result["tokens"], result["ms"])
            return result["text"]
        deepseek_error = result["error"]
    else:
        deepseek_error = "DEEPSEEK_API_KEY not set"

    # 3. Both failed
    _log(db, profile_id, "failed", prompt_summary,
         "AI unavailable — vision and text models both failed",
         f"gemini: {gemini_error}; deepseek: {deepseek_error}",
         None, None)
    return None


def _try_gemini_vision(prompt: str, image_bytes: bytes, mime_type: str) -> dict:
    """Attempt Gemini Vision with an image. Returns {text, error, tokens, ms}."""
    import time
    start = time.time()
    try:
        from google import genai
        from google.genai import types as genai_types

        client = genai.Client(api_key=settings.GEMINI_API_KEY)
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


def _try_gemini(prompt: str) -> dict:
    """Attempt Gemini 2.5 Flash. Returns {text, error, tokens, ms}."""
    start = time.time()
    try:
        from google import genai
        from google.genai import types as genai_types

        client = genai.Client(api_key=settings.GEMINI_API_KEY)
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt,
            config=genai_types.GenerateContentConfig(
                max_output_tokens=512,
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


def _try_deepseek(prompt: str) -> dict:
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
            max_tokens=256,
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
