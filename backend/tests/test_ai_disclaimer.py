"""SWASTH-14 [EV1] — NMC disclaimer audit (P0 compliance floor).

Spec: verify that EVERY ``backend/ai_service.py`` response path that returns
AI-facing text to a patient emits the NMC "salah, nuskha nahi" disclaimer
(advice, not a prescription — per NMC Telemedicine Guidelines).

Canonical disclaimer (source: ``docs/LEGAL_COMPLIANCE_DOCTOR_PORTAL.md`` §6.3):

    "Yeh salah hai, prescription nahi. Dawai mein koi badlav karne se
     pehle doctor se milein."
    (This is advice, not a prescription. Consult your doctor before
     changing any medication.)

The recognisable signature is the Hindi "salah ... nahi" pairing (advice, not
a prescription/nuskha). The regex below matches that phrasing flexibly so the
exact wording ("prescription nahi" / "nuskha nahi" / "dawai nahi") can vary.

IMPORTANT FINDING (read before "fixing" a failure):
``ai_service.py`` has NO disclaimer layer. Sibling ticket SWASTH-13 already
established it has no deterministic safety guard at all: it builds a prompt,
sends it raw to DeepSeek/Gemini/Groq, runs ``_clean_ai_response`` (pure JSON
formatting), and returns the model text VERBATIM. No response path appends or
guarantees the NMC disclaimer.

This audit is therefore EXPECTED to FAIL. The failure is the deliverable: it
pins, per response path, that the NMC disclaimer is not emitted. Do NOT weaken
these assertions to force green — when a real disclaimer injector lands in
``ai_service.py`` (or ``routes_chat.py``'s return path), these tests flip to
green and become the regression guard.

The model client is mocked so every path is deterministic, offline, and needs
no API key.
"""
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from unittest.mock import patch

import pytest

import ai_service


# ---------------------------------------------------------------------------
# Canonical NMC disclaimer regex
# ---------------------------------------------------------------------------
# Matches the "salah ... nahi" signature: the word "salah" (advice) followed,
# within the same sentence, by a negation "nahi" (e.g. "prescription nahi",
# "nuskha nahi", "dawai nahi"). Case-insensitive; tolerant of Devanagari or
# romanised script and of intervening words.
NMC_DISCLAIMER_RE = re.compile(
    r"salah\b.{0,60}?\bnahi|सलाह.{0,60}?नह[ीi]",
    re.IGNORECASE | re.DOTALL,
)


def emits_disclaimer(text) -> bool:
    """True iff ``text`` contains the NMC 'salah ... nahi' disclaimer."""
    if not text:
        return False
    return bool(NMC_DISCLAIMER_RE.search(text))


def assert_emits_disclaimer(text, path: str):
    assert text is not None, f"[{path}] returned None — no text to carry a disclaimer"
    assert emits_disclaimer(text), (
        f"[{path}] AI-facing response does NOT emit the NMC disclaimer "
        f"('salah ... nahi' / advice-not-prescription). Got:\n{text!r}"
    )


# Sanity check the regex itself recognises the canonical string (and Devanagari)
# so a green pass cannot be a false positive from a broken pattern.
def test_regex_recognises_canonical_disclaimer():
    canonical_roman = (
        "Yeh salah hai, prescription nahi. Dawai mein koi badlav karne se "
        "pehle doctor se milein."
    )
    canonical_nuskha = "Yeh salah hai, nuskha nahi."
    canonical_deva = "यह सलाह है, नुस्खा नहीं।"
    plain = "Your glucose is a bit high today. Try a short walk after lunch."
    assert emits_disclaimer(canonical_roman)
    assert emits_disclaimer(canonical_nuskha)
    assert emits_disclaimer(canonical_deva)
    assert not emits_disclaimer(plain)


# ---------------------------------------------------------------------------
# Deterministic model text. We mock each provider so the service runs its real
# code path (cleanup / audit log / fallback) without network or API key. The
# text below is a realistic, plain advisory reply WITHOUT the NMC disclaimer —
# representative of what the unguarded model returns today.
# ---------------------------------------------------------------------------

PLAIN_MODEL_TEXT = (
    "Your glucose readings look a little high this week. Try a short walk "
    "after meals and cut back on sugary drinks. Keep logging your numbers."
)

JSON_MODEL_TEXT = (
    '{"insight": "Your blood pressure trend is stable. Keep taking your '
    'medication as usual and stay hydrated."}'
)

NUTRITION_JSON_TEXT = (
    '{"meal_score": 7, "total_calories": 450, "total_protein_g": 20, '
    '"carb_level": "medium", "sugar_level": "low"}'
)


def _patch_settings(deepseek=None, gemini=None, gemini_keys=None, groq=None):
    """Context-manager helper returning a patched ai_service.settings mock."""
    m = patch.object(ai_service, "settings")
    mock_settings = m.start()
    mock_settings.DEEPSEEK_API_KEY = deepseek
    mock_settings.GEMINI_API_KEY = gemini
    mock_settings.GEMINI_API_KEYS = gemini_keys
    mock_settings.GROQ_API_KEY = groq
    return m, mock_settings


# ===========================================================================
# generate_health_insight — TEXT chain
# ===========================================================================

class TestHealthInsightTextPaths:
    """Every return path of generate_health_insight must emit the disclaimer."""

    def test_deepseek_success_path(self, db):
        """Path 1: DeepSeek returns text → cleaned → returned to patient."""
        m, _ = _patch_settings(deepseek="fake-key", gemini=None)
        try:
            with patch.object(
                ai_service, "_try_deepseek",
                return_value={"text": PLAIN_MODEL_TEXT, "error": None,
                              "tokens": 40, "ms": 100},
            ):
                resp = ai_service.generate_health_insight(
                    "How is my sugar?", profile_id=1, db=db,
                    prompt_summary="ev1-deepseek",
                )
        finally:
            m.stop()
        assert_emits_disclaimer(resp, "generate_health_insight:deepseek-success")

    def test_deepseek_json_insight_path(self, db):
        """Path 1b: DeepSeek returns JSON → _clean_ai_response extracts text."""
        m, _ = _patch_settings(deepseek="fake-key", gemini=None)
        try:
            with patch.object(
                ai_service, "_try_deepseek",
                return_value={"text": JSON_MODEL_TEXT, "error": None,
                              "tokens": 40, "ms": 100},
            ):
                resp = ai_service.generate_health_insight(
                    "How is my BP?", profile_id=1, db=db,
                    prompt_summary="ev1-deepseek-json",
                )
        finally:
            m.stop()
        assert_emits_disclaimer(resp, "generate_health_insight:deepseek-json")

    def test_gemini_fallback_path(self, db):
        """Path 2: DeepSeek fails → Gemini succeeds → returned to patient."""
        m, _ = _patch_settings(deepseek="fake-key", gemini="fake-gemini")
        try:
            with patch.object(
                ai_service, "_try_deepseek",
                return_value={"text": None, "error": "boom",
                              "tokens": None, "ms": 5},
            ), patch.object(
                ai_service, "_try_gemini",
                return_value={"text": PLAIN_MODEL_TEXT, "error": None,
                              "tokens": 40, "ms": 120},
            ):
                resp = ai_service.generate_health_insight(
                    "How is my sugar?", profile_id=1, db=db,
                    prompt_summary="ev1-gemini",
                )
        finally:
            m.stop()
        assert_emits_disclaimer(resp, "generate_health_insight:gemini-fallback")

    def test_both_models_fail_returns_none(self, db):
        """Path 3: both fail → service returns None.

        The disclaimer obligation then shifts to the CALLER's hardcoded
        fallback string (see TestRoutesChatFallback). The service itself
        emits no patient-facing text here, so there is nothing to carry a
        disclaimer — this path is documented, not asserted on the service.
        """
        m, _ = _patch_settings(deepseek="fake-key", gemini="fake-gemini")
        try:
            with patch.object(
                ai_service, "_try_deepseek",
                return_value={"text": None, "error": "boom", "tokens": None, "ms": 5},
            ), patch.object(
                ai_service, "_try_gemini",
                return_value={"text": None, "error": "boom", "tokens": None, "ms": 5},
            ):
                resp = ai_service.generate_health_insight(
                    "How is my sugar?", profile_id=1, db=db,
                    prompt_summary="ev1-bothfail",
                )
        finally:
            m.stop()
        assert resp is None, "expected None when both text models fail"


# ===========================================================================
# generate_vision_insight — VISION chain (returns RAW text to caller)
# ===========================================================================

class TestVisionInsightPaths:
    """Every non-None return path of generate_vision_insight must emit it."""

    def test_gemini_vision_success_path(self, db):
        """Path 1: Gemini Vision returns text (raw, uncleaned) → patient."""
        m, _ = _patch_settings(gemini="fake-gemini", gemini_keys=None, groq=None)
        try:
            with patch.object(
                ai_service, "_try_gemini_vision",
                return_value={"text": PLAIN_MODEL_TEXT, "error": None,
                              "tokens": 80, "ms": 200},
            ):
                resp = ai_service.generate_vision_insight(
                    "Analyse this report", b"\xff\xd8fakejpeg", profile_id=1, db=db,
                    prompt_summary="ev1-vision-gemini", mime_type="image/jpeg",
                )
        finally:
            m.stop()
        assert_emits_disclaimer(resp, "generate_vision_insight:gemini-vision")

    def test_groq_vision_fallback_path(self, db):
        """Path 2: Gemini Vision fails → Groq Vision succeeds → patient."""
        m, _ = _patch_settings(gemini="fake-gemini", gemini_keys="k1,k2", groq="fake-groq")
        try:
            with patch.object(
                ai_service, "_try_gemini_vision",
                return_value={"text": None, "error": "boom", "tokens": None, "ms": 5},
            ), patch.object(
                ai_service, "_try_groq_vision",
                return_value={"text": PLAIN_MODEL_TEXT, "error": None,
                              "tokens": 80, "ms": 220},
            ):
                resp = ai_service.generate_vision_insight(
                    "Analyse this image", b"\xff\xd8fakejpeg", profile_id=1, db=db,
                    prompt_summary="ev1-vision-groq", mime_type="image/jpeg",
                )
        finally:
            m.stop()
        assert_emits_disclaimer(resp, "generate_vision_insight:groq-vision")


# ===========================================================================
# routes_chat.py — the hardcoded "AI unavailable" fallback string the patient
# actually sees when generate_* returns None (ai_service.py:367).
# ===========================================================================

class TestRoutesChatFallback:
    """The patient-facing fallback string in routes_chat must carry it too."""

    def test_connection_error_fallback_string(self):
        """The literal fallback shown when AI is unavailable.

        Mirrors ``routes_chat.send_chat_message``'s hardcoded:
            "I'm sorry, I'm having trouble connecting right now..."
        That string is patient-facing AI-channel text and must also emit the
        NMC disclaimer.
        """
        # Mirrors routes_chat.send_chat_message's hardcoded fallback, which now
        # appends ai_service.NMC_DISCLAIMER (single source of truth).
        fallback = (
            "I'm sorry, I'm having trouble connecting right now. Please try "
            "again in a moment, or consult your doctor for urgent concerns. "
            + ai_service.NMC_DISCLAIMER
        )
        assert_emits_disclaimer(fallback, "routes_chat:connection-fallback")
