"""AES-256-GCM field-level encryption + HMAC-SHA256 blind-indexes.

Two independent keys keep SPDI (health values) and PII (names/emails/phones)
separated so a compromise of one key does not expose the other domain.
  - ENCRYPTION_KEY       — SPDI: glucose, BP, SpO2, weight, notes
  - PII_ENCRYPTION_KEY   — PII: names, emails, phones, medical conditions,
                            and HMAC for email_hash / phone_hash / otp_hash.

Each encrypted value is stored as: base64(nonce ‖ ciphertext ‖ tag)
Each hex key is 64 chars (32 bytes). Generate with:
    python -c "import secrets; print(secrets.token_hex(32))"

HMAC blind-indexes (email_hash, phone_hash) allow server-side lookup without
decrypting every row. They are keyed (stolen DB alone can't be rainbow-tabled).

Usage:
    from encryption_service import (
        encrypt, decrypt, encrypt_float, decrypt_float,      # SPDI
        encrypt_pii, decrypt_pii,                            # PII
        encrypt_pii_list, decrypt_pii_list,                  # ARRAY PII
        hash_email, hash_phone, hash_otp,                    # blind indexes
        normalize_email, normalize_phone,                    # normalization
    )
"""

import base64
import binascii
import hashlib
import hmac
import json
import logging
import os
import re
from typing import Optional, List

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

from config import settings

logger = logging.getLogger(__name__)

_NONCE_SIZE = 12  # 96-bit nonce recommended for AES-GCM


# ---------------------------------------------------------------------------
# Key loading
# ---------------------------------------------------------------------------

def _load_hex_key(hex_key: Optional[str]) -> Optional[bytes]:
    """Parse a 64-char hex string into 32 bytes. Returns None on unset/invalid."""
    if not hex_key:
        return None
    try:
        raw = bytes.fromhex(hex_key)
    except ValueError:
        logger.error("encryption key is not valid hex; treating as unset")
        return None
    if len(raw) != 32:
        logger.error("encryption key must be 32 bytes (64 hex chars); got %d", len(raw))
        return None
    return raw


def _spdi_key() -> Optional[bytes]:
    return _load_hex_key(settings.ENCRYPTION_KEY)


def _pii_key() -> Optional[bytes]:
    return _load_hex_key(settings.PII_ENCRYPTION_KEY)


# ---------------------------------------------------------------------------
# Low-level encrypt / decrypt (parameterized by key)
# ---------------------------------------------------------------------------

def _encrypt_with_key(plaintext: str, key: Optional[bytes]) -> Optional[str]:
    if key is None:
        return None
    nonce = os.urandom(_NONCE_SIZE)
    aesgcm = AESGCM(key)
    ciphertext = aesgcm.encrypt(nonce, plaintext.encode("utf-8"), None)
    return base64.b64encode(nonce + ciphertext).decode("ascii")


def _decrypt_with_key(token: Optional[str], key: Optional[bytes]) -> Optional[str]:
    """Decrypt a token with the given key. Returns None on any failure.

    Failures covered: key unset, empty token, bad base64, truncated token,
    wrong key (rotated / domain mismatch), tampered ciphertext, non-utf8
    plaintext. Deliberately vague logging so we don't leak whether the
    token was ever valid.
    """
    if key is None or not token:
        return None
    try:
        raw = base64.b64decode(token, validate=True)
        if len(raw) <= _NONCE_SIZE:
            logger.warning("decrypt: token shorter than nonce size")
            return None
        nonce = raw[:_NONCE_SIZE]
        ciphertext = raw[_NONCE_SIZE:]
        aesgcm = AESGCM(key)
        return aesgcm.decrypt(nonce, ciphertext, None).decode("utf-8")
    except (binascii.Error, ValueError):
        logger.warning("decrypt: malformed base64 token")
        return None
    except InvalidTag:
        logger.warning("decrypt: authentication tag mismatch")
        return None
    except UnicodeDecodeError:
        logger.warning("decrypt: plaintext not valid utf-8")
        return None


# ---------------------------------------------------------------------------
# SPDI (health data) — existing public API, unchanged
# ---------------------------------------------------------------------------

def encrypt(plaintext: str) -> Optional[str]:
    """Encrypt SPDI (health data) with AES-256-GCM under ENCRYPTION_KEY."""
    return _encrypt_with_key(plaintext, _spdi_key())


def decrypt(token: str) -> Optional[str]:
    """Decrypt an SPDI token back to plaintext. None on any failure."""
    return _decrypt_with_key(token, _spdi_key())


def encrypt_float(value: float) -> Optional[str]:
    """Encrypt a float value (SPDI)."""
    return encrypt(str(value))


def decrypt_float(token: str) -> Optional[float]:
    """Decrypt an SPDI token back to float. None on failure."""
    plain = decrypt(token)
    if plain is None:
        return None
    try:
        return float(plain)
    except ValueError:
        logger.warning("decrypt_float: plaintext is not a float")
        return None


# ---------------------------------------------------------------------------
# PII — new public API (separate key)
# ---------------------------------------------------------------------------

def encrypt_pii(plaintext: Optional[str]) -> Optional[str]:
    """Encrypt a PII string under PII_ENCRYPTION_KEY. None/empty → None."""
    if plaintext is None or plaintext == "":
        return None
    return _encrypt_with_key(plaintext, _pii_key())


def decrypt_pii(token: Optional[str]) -> Optional[str]:
    """Decrypt a PII token back to plaintext. None on any failure."""
    return _decrypt_with_key(token, _pii_key())


def encrypt_pii_list(values: Optional[List[str]]) -> Optional[str]:
    """Encrypt a list of strings as a single JSON blob, under PII key.

    Pattern for `medical_conditions` (ARRAY in Postgres). Store the ciphertext
    in a Text column. None input returns None so the column stays NULL.
    """
    if values is None:
        return None
    payload = json.dumps(values, separators=(",", ":"), ensure_ascii=False)
    return encrypt_pii(payload)


def decrypt_pii_list(token: Optional[str]) -> Optional[List[str]]:
    """Decrypt a PII-list token. Returns the list, or None on any failure."""
    plain = decrypt_pii(token)
    if plain is None:
        return None
    try:
        val = json.loads(plain)
    except (ValueError, TypeError):
        logger.warning("decrypt_pii_list: plaintext is not valid JSON")
        return None
    if not isinstance(val, list):
        logger.warning("decrypt_pii_list: plaintext JSON is not a list")
        return None
    return val


# ---------------------------------------------------------------------------
# Normalization (stable input for blind indexes)
# ---------------------------------------------------------------------------

def normalize_email(email: Optional[str]) -> str:
    """Lowercase + strip. Empty input returns ''."""
    if not email:
        return ""
    return email.strip().lower()


_PHONE_NON_DIGIT = re.compile(r"[^\d+]")


def normalize_phone(phone: Optional[str]) -> str:
    """Normalize a phone number to E.164-ish form. Empty → ''.

    Rules:
      - Strip all non-digit / non-'+' chars.
      - Leading '+' preserved as-is (international already).
      - Leading '0' stripped (local trunk prefix).
      - 10-digit → prefix '+91' (Indian mobile default for pilot).
      - 12-digit starting '91' → prefix '+'.
      - Fallback: prefix '+' (best-effort; caller should pre-format ideally).
    """
    if not phone:
        return ""
    cleaned = _PHONE_NON_DIGIT.sub("", phone.strip())
    if not cleaned:
        return ""
    if cleaned.startswith("+"):
        return cleaned
    if cleaned.startswith("0"):
        cleaned = cleaned[1:]
    if len(cleaned) == 10:
        return "+91" + cleaned
    if len(cleaned) == 12 and cleaned.startswith("91"):
        return "+" + cleaned
    return "+" + cleaned


# ---------------------------------------------------------------------------
# Blind indexes (HMAC-SHA256 under PII key)
# ---------------------------------------------------------------------------

def hash_email(email: Optional[str]) -> Optional[str]:
    """HMAC-SHA256(normalized_email) using PII key. Deterministic, indexable.

    Returns None if key is unset or email is empty — caller must treat None as
    "cannot look up" (for login, should become 401 not 500).
    """
    key = _pii_key()
    if key is None or not email:
        return None
    data = normalize_email(email).encode("utf-8")
    if not data:
        return None
    return hmac.new(key, data, hashlib.sha256).hexdigest()


def hash_phone(phone: Optional[str]) -> Optional[str]:
    """HMAC-SHA256(normalized_phone) using PII key."""
    key = _pii_key()
    if key is None or not phone:
        return None
    data = normalize_phone(phone).encode("utf-8")
    if not data:
        return None
    return hmac.new(key, data, hashlib.sha256).hexdigest()


def hash_nmc(nmc_number: Optional[str]) -> Optional[str]:
    """HMAC-SHA256(upper(trim(nmc_number))) using PII key.

    NMC registration numbers are alphanumeric with regional prefixes
    (e.g. "KA12345"). Uppercase+trim normalization matches what doctors
    typically enter in different casings.
    """
    key = _pii_key()
    if key is None or not nmc_number:
        return None
    data = nmc_number.strip().upper().encode("utf-8")
    if not data:
        return None
    return hmac.new(key, data, hashlib.sha256).hexdigest()


# ---------------------------------------------------------------------------
# OTP hashing (E4) — HMAC under PII key so a DB dump can't rainbow the 6-digit space
# ---------------------------------------------------------------------------

def hash_otp(otp: Optional[str]) -> Optional[str]:
    """HMAC-SHA256(otp) using PII key. Deterministic — compare hex digests.

    Falls back to plain sha256 only if PII_ENCRYPTION_KEY is unset (dev
    bootstrap). In prod, Settings validation should ensure the key is set.
    """
    if not otp:
        return None
    key = _pii_key()
    if key is None:
        # Dev fallback — still one-way, just not keyed.
        return hashlib.sha256(otp.encode("utf-8")).hexdigest()
    return hmac.new(key, otp.encode("utf-8"), hashlib.sha256).hexdigest()
