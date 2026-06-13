"""
Central AI service with multi-model fallback chain and audit logging.

Text chain: DeepSeek → Gemini → rule-based
Vision chain: Gemini (with key rotation) → Groq → DeepSeek text → None
Every call is logged to the ai_insight_logs table for compliance.
"""
import json
import logging
import re
import time
from typing import Optional
from sqlalchemy.orm import Session
from config import settings
import models

logger = logging.getLogger(__name__)


# ===========================================================================
# Deterministic AI safety + disclaimer guard (SWASTH-13 / SWASTH-14)
# ---------------------------------------------------------------------------
# This is patient-facing CLINICAL-SAFETY logic. It is intentionally pure,
# deterministic and offline (regex/keyword only) — NO extra LLM call, no API
# key. Every patient-facing return path routes through ``_apply_safety_guard``:
#   1. Disclaimer: append the NMC "salah, nuskha nahi" disclaimer if absent.
#   2. Red-flag guard: if the user's own message hits one of five high-risk
#      categories, the model output is REPLACED with a safe refuse/escalate
#      message (no diagnosis, no "stop meds"; crisis -> helpline; cardiac ->
#      emergency / 108).
#
# REQUIRES human sign-off (Dr. Rajesh + Legal/PHI) before merge.
# ===========================================================================

# Canonical NMC disclaimer — source: docs/LEGAL_COMPLIANCE_DOCTOR_PORTAL.md §6.3.
# The recognisable signature is the Hindi "salah ... nahi" pairing.
NMC_DISCLAIMER = (
    "Yeh salah hai, prescription nahi. Dawai mein koi badlav karne se "
    "pehle doctor se milein. (This is advice, not a prescription. Consult "
    "your doctor before changing any medication.)"
)

# Matches the "salah ... nahi" disclaimer signature (romanised or Devanagari)
# so we don't double-append when a model already produced it.
_DISCLAIMER_PRESENT_RE = re.compile(
    r"salah\b.{0,60}?\bnahi|सलाह.{0,60}?नह[ीi]",
    re.IGNORECASE | re.DOTALL,
)

# ---------------------------------------------------------------------------
# Red-flag categories. Each maps a deterministic keyword/regex classifier over
# the patient's OWN message to a safe, bilingual-friendly refuse/escalate
# reply. Order matters: life-threatening categories (suicide, cardiac) are
# checked first so they win over a co-occurring lower-risk keyword.
# ---------------------------------------------------------------------------

# Crisis helplines (India). Tele-MANAS 14416 is the Govt of India mental-health
# line; KIRAN 1800-599-0019 is the MoSJE 24x7 line.
_REFUSAL_SUICIDE = (
    "अभी 14416 पर कॉल करें (Tele-MANAS)\n"
    "आप अकेले नहीं हैं। किसी अपने से अभी बात करें।\n"
    "(You are not alone. Call the helpline 14416 now.)\n"
    "और मदद: KIRAN 1800-599-0019"
)

_REFUSAL_CARDIAC = (
    "🚨 अभी 108 पर कॉल करें\n"
    "सीने में दर्द — देर न करें।\n"
    "(Chest pain can be an emergency. Call the ambulance on 108 now.)\n"
    "दूसरा नंबर: 112"
)

# STROKE (FAST). Time-critical: a stroke is a life-threatening emergency, so —
# like cardiac — it leads Devanagari-first with 108 and carries NO NMC tail.
_REFUSAL_STROKE = (
    "🚨 अभी 108 पर कॉल करें\n"
    "लकवे के लक्षण — एक पल भी न गंवाएं।\n"
    "(Stroke signs are a medical emergency — call the ambulance on 108 right "
    "now. Every minute counts.)\n"
    "दूसरा नंबर: 112"
)

# SEVERE HYPOGLYCEMIA. This population is diabetic on meds; severe low sugar is
# an emergency. Devanagari-first, simple action (eat fast sugar NOW) + escalate
# to 108 if the person is becoming unconscious. Emergency -> NO NMC tail.
_REFUSAL_HYPO = (
    "⚠️ अभी मीठा खाएं — चीनी, ग्लूकोज़, जूस या शहद।\n"
    "शुगर बहुत कम हो सकती है — देर न करें।\n"
    "(Your sugar may be dangerously low. Eat or drink fast sugar — glucose, "
    "juice, sugar or honey — right now.)\n"
    "अगर बेहोशी जैसा लगे तो 108 पर कॉल करें।\n"
    "(If the person feels faint or cannot swallow, call 108.)"
)

_REFUSAL_STOP_MEDS = (
    "अपनी दवाई खुद बंद न करें।\n"
    "पहले डॉक्टर को दिखाएं।\n"
    "(Please do not change your medicine on your own. See your doctor first.)\n"
    + NMC_DISCLAIMER
)

_REFUSAL_DIAGNOSIS = (
    "मैं बीमारी नहीं बता सकता।\n"
    "डॉक्टर को दिखाएं और जांच कराएं।\n"
    "(I am an AI and cannot diagnose. Please see a doctor for proper tests.)\n"
    + NMC_DISCLAIMER
)

_REFUSAL_CHILD_DOSE = (
    "बच्चे की दवाई की मात्रा मैं नहीं बता सकता।\n"
    "डॉक्टर से पूछें।\n"
    "(I cannot give a child's dose. Please ask a doctor.)\n"
    + NMC_DISCLAIMER
)

# Keyword/regex sets per category, evaluated against the lower-cased message.
_RF_SUICIDE = [
    r"\b(?:kill|hurt|harm)(?:ing)?\s+myself\b",
    r"\bsuicid(?:e|al)\b",
    r"\bend(?:ing)?\s+(?:my|it)\s+(?:life|all)\b",
    r"\b(?:don'?t|do not|dont)\s+want\s+to\s+(?:live|be alive|go on)\b",
    r"\bno\s+(?:reason|point)\s+to\s+live\b",
    r"\btake\s+my\s+(?:own\s+)?life\b",
    r"\bmar\s*(?:jaun|jaana|jana)\b",            # "mar jaun/jaana" (to die)
    r"\bjeena\s+nahi\s+chahta\b",                # "jeena nahi chahta"
    r"\bkhudkushi\b|\baatmahatya\b",            # khudkushi / aatmahatya
]
_RF_CARDIAC = [
    r"\bchest\s+pain\b",
    r"\bseene\s+(?:me|mein)\s+dard\b",
    r"\bheart\s+attack\b",
    r"\bleft\s+arm\b.{0,30}\b(?:numb|pain|tingl)",
    # Require the arm to be the thing that is numb/tingling — a symptom, not
    # any sentence mentioning an arm near the word "numb" (which over-matched,
    # e.g. "the number on my arm band"). Anchor to a body-symptom phrasing.
    r"\b(?:left|right)?\s*arm\s+(?:is\s+|feels\s+|going\s+)?(?:numb|tingl)",
    r"\bpressure\s+in\s+(?:my\s+)?chest\b",
    r"\b(?:can'?t|cannot|cant|trouble)\s+breath",
    # --- Devanagari HARD-cardiac forms. These MUST be in the cardiac MATCHING
    # list (not only in _RF_CARDIAC_HARD): _has_hard_cardiac_signal correctly
    # stops a Devanagari chest-pain message from being downgraded to hypo
    # (skip_cardiac=False), but if cardiac's own patterns don't match the
    # Devanagari form, the message falls through to hypoglycemia anyway. So a
    # message like "सीने में दर्द और शुगर बहुत कम" needs cardiac to actually fire
    # here. These mirror the romanised hard signals above, in Devanagari.
    r"सीने?\s+(?:में|मे)\s+दर्द",                 # chest pain
    r"छाती\s+(?:में|मे)\s+(?:दर्द|दबाव)",         # chest pain / pressure
    r"दिल\s+का\s+दौरा",                           # heart attack
    r"(?:बाँह|बांह|हाथ)\s+सुन्न",                 # arm numb
    r"साँस\s+(?:नहीं\s+आ\s+रही|फूल\s+रही|नहीं)",  # can't breathe / breathless
    # --- Colloquial Hindi / Bhojpuri symptom lexicon (how a real MI is
    # described in Bihar). Romanised + Devanagari forms. Tightened so benign
    # sentences don't fire: "ghabrahat" alone is anxiety, so we require a
    # chest/heart context OR a co-occurring sweating/breathlessness symptom.
    r"\bseene?\s+(?:pe|par|me|mein)\s+(?:bhaari?\s*pan|bhaaripan|bhaari|dabaav|dabav|jakdan)\b",
    r"सीने?\s+(?:पे|पर|में)\s+(?:भारीपन|भारी|दबाव|जकड़न)",
    # Sweating ("paseena"/"pasina") is cardiac ONLY when it co-occurs with a
    # chest/heart/breath context. Standalone sweating (heat, exertion) or
    # sweating tied to LOW SUGAR is NOT cardiac (the latter is hypoglycemia and
    # is handled with higher priority below). Cold-sweat-on-chest stays cardiac.
    r"\b(?:thand[ai]?\s+)?(?:paseena|pasina)\b.{0,30}\b(?:seene?|chest|dil|heart|saans|breath)\b",
    r"\b(?:seene?|chest|dil|heart|saans|breath)\b.{0,30}\b(?:thand[ai]?\s+)?(?:paseena|pasina)\b",
    r"(?:ठंडा\s+)?पसीना\b.{0,30}\b(?:सीने?|दिल|छाती|साँस)",
    r"\b(?:सीने?|दिल|छाती|साँस)\b.{0,30}(?:ठंडा\s+)?पसीना",
    r"\bsaans\b.{0,15}\b(?:phool|fool|phul|chadh|ukhad|nahi)\b",
    r"साँस\s+(?:फूल|चढ़|उखड़)",
    r"\bdum\s+ghut\b",
    r"दम\s+घुट",
    # "ghabrahat" only as cardiac when paired with chest/heart/sweat/breath.
    r"\bghabrahat\b.{0,30}\b(?:seene?|chest|dil|heart|paseena|pasina|saans)\b",
    r"\b(?:seene?|chest|dil|heart|paseena|pasina|saans)\b.{0,30}\bghabrahat\b",
    r"\bdil\s+(?:baith|doob|ghabra)",
    r"दिल\s+(?:बैठ|डूब|घबरा)",
]
# STROKE (FAST): face droop, arm weakness, slurred/lost speech, sudden
# one-sided weakness/numbness, sudden severe dizziness. Checked right after
# cardiac (both life-threatening). Romanised + Devanagari.
_RF_STROKE = [
    r"\bface\s+(?:droop|drooping|is\s+drooping|has\s+dropped)\b",
    r"\b(?:one\s+side|half)\s+of\s+(?:my\s+|the\s+)?face\b.{0,20}\b(?:droop|numb|weak|paralys)",
    r"\b(?:muh|munh|chehra)\s+(?:tedha|terha|tirchha|tircha|latak)\b",
    r"(?:मुँह|मुंह|चेहरा)\s+(?:टेढ़ा|तिरछा|लटक)",
    r"\barm\s+(?:weakness|is\s+weak|won'?t\s+lift|can'?t\s+(?:lift|raise|move))\b",
    r"\b(?:slurred|slurring)\s+speech\b",
    r"\b(?:can'?t|cannot|cant|trouble|difficulty|unable\s+to)\s+(?:speak|talk)",
    r"\b(?:lost|losing)\s+(?:my\s+)?speech\b",
    r"\bbol(?:ne)?\s+(?:me|mein)\s+(?:dikkat|dikat|takleef|pareshani)\b",
    r"बोल(?:ने)?\s+(?:में|मे)\s+(?:दिक्कत|तकलीफ)",
    r"\b(?:ek|एक)\s+(?:taraf|side)\b.{0,20}\b(?:kamzori|kamjori|sunn|sun|jhunjhuni|lakwa|paralys)\b",
    r"एक\s+तरफ\b.{0,20}(?:कमज़ोरी|कमजोरी|सुन्न|लकवा)",
    r"\bachanak\b.{0,20}\bchakkar\b",
    r"अचानक\b.{0,20}चक्कर",
    # "lakwa"/"लकवा" = paralysis (a stroke sign). Must NOT fire on the compound
    # "lakwapan" ("lakwapan se jude questions" is a benign topical question), so
    # we forbid an immediately-following letter. Romanised: \blakwa\b (the \b
    # blocks "lakwapan"). Devanagari "लकवा" ends in the vowel-sign matra "ा",
    # which has NO \w boundary after it, so \b can't anchor here — we instead use
    # a negative lookahead for any following Devanagari letter to block "लकवापन"
    # while still matching "लकवा मार गया" (real stroke).
    r"\blakwa\b|लकवा(?![ऀ-ॿ])",
]
# SEVERE HYPOGLYCEMIA: low sugar in a diabetic-on-meds population is an
# emergency. Require an explicit "low/kam" + sugar context, OR the classic
# adrenergic triad (shaking + sweating + confusion), OR a near-faint phrasing,
# so a plain "I feel a bit shaky" does not fire.
_RF_HYPO = [
    r"\b(?:sugar|glucose|bp\s+sugar)\b.{0,15}\b(?:too\s+low|very\s+low|is\s+low|bahut\s+kam|kam\s+ho|gir\s+gay|gir\s+gai|drop(?:ped|ping)?|gir\s+rah)\b",
    # "low/very-low SUGAR" but NOT a benign "low sugar diet/food/recipe" — a
    # diet question is logistics, not an emergency. Negative lookahead on the
    # diet/food vocabulary that follows.
    r"\b(?:too\s+low|very\s+low|bahut\s+kam)\b.{0,10}\b(?:sugar|glucose)\b(?!\s+(?:diet|food|meal|recipe|khana|khaana))",
    r"\bglucose\b.{0,15}\b(?:drop(?:ped|ping)?|gir\s+gay|crash)",
    r"\bhypoglycemi[ac]|hypoglycaemi[ac]\b",
    r"\b(?:sugar|glucose)\b.{0,20}\b(?:[1-9]|[1-4][0-9]|5[0-3])\s*(?:mg)?\b\s*(?:/?\s*dl)?\b.{0,15}\b(?:low|kam)\b",
    # A BARE glucose reading <54 mg/dL is, per ADA, level-2 (clinically
    # significant / severe) hypoglycemia in a diabetic-on-meds population — an
    # emergency on its own, no "low/kam" qualifier required. We anchor to an
    # explicit mg/dl unit so a stray number ("sugar at 7am", "53 steps") cannot
    # fire. 53 and below trigger; 54 does NOT (54 is not < 54).
    r"\b(?:sugar|glucose)\b.{0,20}\b(?:[1-9]|[1-4][0-9]|5[0-3])\s*mg\s*/?\s*dl\b",
    r"\bglucose\b.{0,10}\b(?:below|under|less\s+than|<)\s*5[0-4]\b",
    r"\b(?:shaking|shaky|kaanp|kaap|kamp)\w*\b.{0,30}\b(?:sweat|paseena|pasina|pasine)\w*\b.{0,30}\b(?:confus|chakkar|behosh|ghabra)",
    r"\b(?:paseena|pasina|pasine)\s+aur\s+(?:kaanpna|kaapna|kaanp|kaap|kampkampi)\b",
    # Devanagari sweating+shaking, ORDER-INDEPENDENT. The romanised sibling above
    # only matched "sweating then shaking"; a Devanagari patient who writes the
    # symptoms in the other order ("काँपना और पसीना") was silently missed. We do
    # NOT use ASCII \b here: Devanagari words ending in a vowel-sign matra (e.g.
    # "काँपना") have no \w/\W boundary after the matra, so \b fails to anchor.
    r"(?:पसीना|काँपना|कांपना|कंपकंपी)\s+और\s+(?:पसीना|काँपना|कांपना|कंपकंपी)",
    r"\b(?:sugar|shugar)\s+(?:bahut\s+)?kam\b",
    r"शुगर\s+(?:बहुत\s+)?कम",
    r"\bbehosh\s+jaisa|behosh\s+(?:ho|hone)\b",
    r"बेहोश\s+(?:जैसा|हो)",
]
# An EXPLICIT low-glucose signal: a sugar/glucose token paired with a
# low/falling token. When present, the message is hypoglycemia and must NOT be
# stolen by the cardiac category just because sweating/shaking co-occur — a
# severe-hypo patient routed to the cardiac message would miss the life-saving
# "eat fast sugar NOW" instruction. Suicide and true cardiac (chest pain / MI)
# still take precedence; this only de-prioritises cardiac relative to hypo.
_RF_HYPO_EXPLICIT_GLUCOSE = [
    r"\b(?:sugar|glucose|shugar)\b.{0,15}\b(?:too\s+low|very\s+low|is\s+low|low|bahut\s+kam|kam\s+ho|kam\s+lag|kam\b|gir\s+gay|gir\s+gai|gir\s+rah|drop(?:ped|ping)?|below|crash)",
    r"\b(?:too\s+low|very\s+low|bahut\s+kam|kam)\b.{0,15}\b(?:sugar|glucose|shugar)\b(?!\s+(?:diet|food|meal|recipe|khana|khaana))",
    r"\bhypoglycemi[ac]|hypoglycaemi[ac]\b",
    r"\b(?:sugar|shugar)\s+(?:bahut\s+)?kam\b",
    r"शुगर\s+(?:बहुत\s+)?कम",
    r"(?:सुगर|शुगर|ग्लूकोज़?)\b.{0,15}(?:कम|गिर|लो)",
]


def _has_explicit_low_glucose(low: str) -> bool:
    """True if ``low`` (already lower-cased) carries an explicit low-glucose
    signal. Used to give hypoglycemia priority over cardiac so a low-sugar
    message with sweating/shaking is not misrouted."""
    return any(re.search(p, low) for p in _RF_HYPO_EXPLICIT_GLUCOSE)


# A HARD cardiac signal is a symptom that — on its own — is a possible
# myocardial infarction (MI) and must NEVER be downgraded to hypoglycemia, even
# when an explicit low-glucose token also appears. The hypo-wins rule
# (skip_cardiac) was only ever meant to fix the SOFT case: the adrenergic
# picture (sweating/shaking) co-occurring with low sugar, WITHOUT any genuine
# chest/MI symptom. A real MI ("chest pain", "seene me dard", "heart attack",
# "left arm numb/tingling", "pressure in chest", "can't breathe") must win.
# This is a curated SUBSET of _RF_CARDIAC — only the unambiguous MI signals,
# NOT the soft sweating/ghabrahat patterns (those are the ones that legitimately
# defer to hypoglycemia).
_RF_CARDIAC_HARD = [
    r"\bchest\s+pain\b",
    r"\bseene\s+(?:me|mein)\s+dard\b",
    r"सीने?\s+(?:में|मे)\s+दर्द",                 # chest pain (Devanagari)
    r"छाती\s+(?:में|मे)\s+(?:दर्द|दबाव)",         # chest pain / pressure (Devanagari)
    r"\bheart\s+attack\b",
    r"\bdil\s+ka\s+daura\b",
    r"दिल\s+का\s+दौरा",                           # heart attack (Devanagari)
    r"\bleft\s+arm\b.{0,30}\b(?:numb|tingl)",
    r"\b(?:left|right)?\s*arm\s+(?:is\s+|feels\s+|going\s+)?(?:numb|tingl)",
    r"(?:बाँह|बांह|हाथ)\s+सुन्न",                 # arm numb (Devanagari)
    r"\bpressure\s+in\s+(?:my\s+)?chest\b",
    r"\b(?:can'?t|cannot|cant|trouble)\s+breath",
    r"साँस\s+(?:नहीं\s+आ\s+रही|फूल\s+रही|नहीं)",  # can't breathe / breathless (Devanagari)
]


def _has_hard_cardiac_signal(low: str) -> bool:
    """True if ``low`` (already lower-cased) carries a HARD cardiac (possible
    MI) signal that must never be downgraded to hypoglycemia. See
    ``_RF_CARDIAC_HARD``."""
    return any(re.search(p, low) for p in _RF_CARDIAC_HARD)


_RF_STOP_MEDS = [
    r"\bstop\b.{0,30}\b(?:meds|medication|medicine|medicines|pills|tablets|dawai|dawa)\b",
    r"\bquit\b.{0,20}\b(?:meds|medication|medicine|dawai)\b",
    r"\bdiscontinue\b.{0,20}\b(?:meds|medication|medicine)\b",
    r"\b(?:dawai|dawa)\b.{0,20}\b(?:band|chhod|chhodna|bandh)\b",
    r"\bskip\b.{0,20}\b(?:my\s+)?(?:meds|medication|medicine|dose|doses)\b",
]
# Disease / condition vocabulary that turns a "do I have ..." question into a
# diagnosis request rather than a benign logistics question ("do I have to ...").
_DISEASE_TERMS = (
    r"(?:diabet(?:es|ic)|sugar|hypertensi(?:on|ve)|high\s+bp|blood\s+pressure|"
    r"cancer|tumou?r|anaemi[ac]|anemi[ac]|thyroid|asthma|covid|infection|"
    r"disease|condition|cholesterol|stroke|kidney|liver|heart\s+(?:disease|"
    r"condition|problem)|a\s+heart\s+attack)"
)
_RF_DIAGNOSIS = [
    r"\bam\s+i\s+(?:diabetic|pre[- ]?diabetic|hypertensive|anaemic|anemic)\b",
    # Require a disease term after "do I have" so "do I have to take this twice?"
    # (a logistics question) does NOT trigger a refusal.
    r"\bdo\s+i\s+have\b.{0,30}\b" + _DISEASE_TERMS,
    r"\bam\s+i\s+having\s+a\b.{0,20}\b(?:heart\s+attack|stroke|seizure)\b",
    r"\bwhat'?s?\s+(?:wrong|the\s+disease)\s+with\s+me\b",
    r"\bkya\s+mujhe\b.{0,30}\b(?:hai|diabetes|sugar|bp)\b",   # "kya mujhe ... hai"
    r"\bis\s+this\s+(?:cancer|diabetes|a\s+tumou?r)\b",
    r"\bdiagnos(?:e|is)\b",
]
_RF_CHILD_DOSE = [
    r"\b(?:how\s+much|kitni|kitna)\b.{0,40}\b(?:child|baby|toddler|infant|bachch?e?|bacche)\b",
    r"\b(?:dose|dosage|maatra|matra)\b.{0,40}\b(?:child|baby|toddler|infant|bachch?e?|year[- ]?old|saal)\b",
    r"\b(?:give|de(?:na|do)?)\b.{0,40}\b(?:my\s+)?(?:child|baby|toddler|\d+[- ]?(?:year|month|saal|mahine)[- ]?old)\b",
    r"\b(?:paracetamol|ibuprofen|antibiotic|crocin|calpol|dawai)\b.{0,40}\b(?:child|baby|toddler|bachch?e?|\d+[- ]?(?:year|month|saal))\b",
]

# Evaluated in priority order (most life-threatening first). The list order IS
# the priority: the FIRST category whose patterns match wins, so a co-occurring
# lower-risk keyword can never down-rank an emergency.
#   1. suicide   — highest; a crisis call-to-action must never be diluted.
#   2. cardiac   — possible MI; checked before stroke, so a message that hits
#                  BOTH cardiac and stroke (e.g. "my face is drooping and I have
#                  severe chest pain") resolves to CARDIAC (the chest/MI signal
#                  leads). cardiac is conditionally SKIPPED only for the soft
#                  hypo case — see skip_cardiac in _classify_red_flag.
#   3. stroke    — FAST signs; life-threatening, just below cardiac.
#   4. hypoglycemia — severe low sugar in a diabetic-on-meds population.
#   5+. stop_meds / child_dose / self_diagnosis — non-emergency refusals.
_RED_FLAG_RULES = [
    # Life-threatening first (suicide, cardiac, stroke, hypo) so a co-occurring
    # lower-risk keyword can't mis-route an emergency.
    ("suicide", _RF_SUICIDE, _REFUSAL_SUICIDE),
    ("cardiac", _RF_CARDIAC, _REFUSAL_CARDIAC),
    ("stroke", _RF_STROKE, _REFUSAL_STROKE),
    ("hypoglycemia", _RF_HYPO, _REFUSAL_HYPO),
    ("stop_meds", _RF_STOP_MEDS, _REFUSAL_STOP_MEDS),
    ("child_dose", _RF_CHILD_DOSE, _REFUSAL_CHILD_DOSE),
    ("self_diagnosis", _RF_DIAGNOSIS, _REFUSAL_DIAGNOSIS),
]


def _classify_red_flag(message: Optional[str]) -> Optional[tuple]:
    """Return ``(category, refusal_text)`` if the patient's message hits a
    red-flag category, else ``None``. Pure/deterministic — no LLM."""
    if not message:
        return None
    low = message.lower()
    # Hypo-vs-cardiac disambiguation. If the message carries an EXPLICIT
    # low-glucose signal, hypoglycemia SHOULD win over cardiac — BUT only for the
    # SOFT case (sweating/shaking + low sugar, no genuine MI symptom). A message
    # with a HARD cardiac signal (chest pain / seene me dard / heart attack /
    # left|right arm numb-or-tingling / pressure in chest / can't breathe) is a
    # possible MI and must NEVER be downgraded, even if a low-glucose token also
    # appears ("chest pain and my sugar is low" -> CARDIAC, MI not missed).
    # Suicide stays highest. skip_cardiac fires ONLY when low-glucose is explicit
    # AND there is NO hard cardiac signal.
    skip_cardiac = (
        _has_explicit_low_glucose(low) and not _has_hard_cardiac_signal(low)
    )
    for category, patterns, refusal in _RED_FLAG_RULES:
        if category == "cardiac" and skip_cardiac:
            continue
        if any(re.search(p, low) for p in patterns):
            return category, refusal
    return None


def _looks_like_structured_json(text: str) -> bool:
    """True if ``text`` is a raw JSON object/array (e.g. nutrition analysis the
    caller parses downstream). We must NOT append free text to it — doing so
    would break JSON parsing in routes_meals. Such structured payloads are not
    patient-facing prose, so the disclaimer is added by the formatting layer."""
    s = text.strip()
    if not (s.startswith("{") or s.startswith("[") or s.startswith("```")):
        return False
    # Strip a ``` / ```json code-fence: remove leading/trailing backticks, then
    # the literal ``json`` language hint and the newline that follows it. Using
    # removeprefix here (not str.strip, which removes a CHARACTER SET — e.g.
    # "json" would also eat a leading 'j'/'s'/'o'/'n' of real content).
    candidate = s.strip("`")
    candidate = candidate.removeprefix("json").lstrip("\r\n").strip()
    try:
        json.loads(candidate)
        return True
    except (json.JSONDecodeError, TypeError, ValueError):
        return False


def _ensure_disclaimer(text: str) -> str:
    """Append the NMC disclaimer if the text doesn't already carry it."""
    if not text:
        return text
    if _DISCLAIMER_PRESENT_RE.search(text):
        return text
    if _looks_like_structured_json(text):
        return text
    return f"{text.rstrip()}\n\n{NMC_DISCLAIMER}"


def _apply_safety_guard(text: Optional[str], *, user_message: Optional[str]) -> Optional[str]:
    """Single post-processing guard every patient-facing AI path routes through.

    1. If the patient's own ``user_message`` hits a red-flag category, REPLACE
       the model output with a safe refuse/escalate message (which already
       carries the disclaimer).
    2. Otherwise, ensure the NMC disclaimer is appended to the model output.

    CONTRACT: ``user_message`` is REQUIRED and explicit. It is the patient's
    OWN free-text message — never the system prompt. The red-flag classifier
    only ever runs over a real patient message; system-generated paths (weekly
    reports, auto-insights, meal-photo scans with no caption) MUST pass
    ``user_message=None``. There is NO silent fallback to scanning the prompt —
    scanning the system prompt for red flags is both useless (the patient's
    message often isn't in it) and unsafe (false positives on instructional
    text). When ``user_message`` is None the guard runs in disclaimer-only mode
    and logs that the red-flag classifier was skipped, so the degraded behaviour
    is explicit rather than silent.

    Deterministic and offline — no extra model call, no API key.
    """
    if text is None:
        return None
    if user_message is None:
        # System-generated path: no patient free-text to classify. Append the
        # disclaimer only; the red-flag classifier is deliberately NOT run.
        logger.info(
            "AI safety guard: no user_message — red-flag classifier skipped "
            "(disclaimer-only mode)")
        return _ensure_disclaimer(text)
    flag = _classify_red_flag(user_message)
    if flag is not None:
        category, refusal = flag
        logger.warning("AI safety guard triggered: red-flag category=%s", category)
        return refusal
    return _ensure_disclaimer(text)


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
    user_message: Optional[str] = None,
) -> Optional[str]:
    """Try DeepSeek first (cheap, no rate limit), then Gemini, then return None.

    DeepSeek-first saves Gemini's free quota for image scanning where it's needed.

    ``user_message`` is the patient's OWN raw question, fed to the safety guard's
    red-flag classifier. Callers MUST pass it explicitly when a real patient
    message exists, or pass ``None`` for system-generated insights (weekly
    reports, auto-generated dashboards). The guard NEVER scans ``prompt`` for
    red flags — see ``_apply_safety_guard``'s contract. There is no silent
    fallback to the system prompt.
    """
    # 1. Try DeepSeek first (cheap, reliable, no rate limit)
    if settings.DEEPSEEK_API_KEY:
        result = _try_deepseek(prompt, max_tokens=max_tokens)
        if result["text"]:
            # Clean up JSON responses, then apply the safety + disclaimer guard.
            cleaned_text = _apply_safety_guard(
                _clean_ai_response(result["text"]), user_message=user_message)
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
            # Clean up JSON responses, then apply the safety + disclaimer guard.
            cleaned_text = _apply_safety_guard(
                _clean_ai_response(result["text"]), user_message=user_message)
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
    user_message: Optional[str] = None,
) -> Optional[str]:
    """Analyze image or PDF with Gemini Vision first, fallback to Groq Vision (images only).

    Vision chain: Gemini (with key rotation) → Groq (images only) → None
    Gemini 2.5 Flash natively handles multi-page PDFs via mime_type="application/pdf".
    Groq Vision is image-only, so PDFs skip the Groq fallback.

    Every non-None patient-facing return routes through ``_apply_safety_guard``
    (disclaimer + red-flag). Structured nutrition JSON is left intact by the
    guard so routes_meals.py can still parse it; the disclaimer is then added by
    the formatting layer.
    """
    is_pdf = mime_type == "application/pdf"

    # 1. Try Gemini Vision first (handles both images and PDFs)
    keys = _get_gemini_keys()
    if keys:
        result = _try_gemini_vision(prompt, image_bytes, mime_type)
        if result["text"]:
            guarded = _apply_safety_guard(result["text"], user_message=user_message)
            _log(db, profile_id, "gemini-2.5-flash-vision", prompt_summary,
                 guarded, None, result["tokens"], result["ms"])
            return guarded
        gemini_error = result["error"]
    else:
        gemini_error = "No Gemini API keys configured"

    # 2. Fallback to Groq Vision — IMAGES ONLY (Groq does not support PDF input)
    if is_pdf:
        groq_error = "Groq Vision does not support PDF input — skipped"
    elif settings.GROQ_API_KEY:
        result = _try_groq_vision(prompt, image_bytes, mime_type)
        if result["text"]:
            guarded = _apply_safety_guard(result["text"], user_message=user_message)
            _log(db, profile_id, "groq-llama-vision", prompt_summary,
                 guarded, f"gemini failed: {gemini_error}",
                 result["tokens"], result["ms"])
            return guarded
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
