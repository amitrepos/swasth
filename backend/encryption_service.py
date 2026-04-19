"""AES-256-GCM field-level encryption for health data at rest.

Each encrypted value is stored as: base64(nonce ‖ ciphertext ‖ tag)
Key is loaded from ENCRYPTION_KEY env var (64-char hex = 32 bytes).

Usage:
    from encryption_service import encrypt, decrypt, encrypt_float, decrypt_float

    token = encrypt("sensitive text")
    plain = decrypt(token)

    token = encrypt_float(120.5)
    value = decrypt_float(token)   # -> 120.5
"""

import base64
import binascii
import logging
import os
from typing import Optional

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

from config import settings

logger = logging.getLogger(__name__)

_NONCE_SIZE = 12  # 96-bit nonce recommended for AES-GCM


def _get_key() -> Optional[bytes]:
    """Return the 32-byte AES key, or None if not configured."""
    hex_key = settings.ENCRYPTION_KEY
    if not hex_key:
        return None
    return bytes.fromhex(hex_key)


def encrypt(plaintext: str) -> Optional[str]:
    """Encrypt a string with AES-256-GCM. Returns base64-encoded token, or None if key not set."""
    key = _get_key()
    if key is None:
        return None
    nonce = os.urandom(_NONCE_SIZE)
    aesgcm = AESGCM(key)
    ciphertext = aesgcm.encrypt(nonce, plaintext.encode("utf-8"), None)
    return base64.b64encode(nonce + ciphertext).decode("ascii")


def decrypt(token: str) -> Optional[str]:
    """Decrypt an AES-256-GCM token back to plaintext string.

    Returns None if the key is unset, the token is empty, the token is not
    valid base64, or the ciphertext fails authentication (wrong key, rotated
    key, or tampered data). Failures are logged with a truncated detail so
    the caller can render a graceful fallback instead of crashing the query.
    """
    key = _get_key()
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
        # Wrong key, rotated key, or tampered ciphertext. Deliberately vague
        # in logs — we don't want to expose whether the token was ever valid.
        logger.warning("decrypt: authentication tag mismatch")
        return None
    except UnicodeDecodeError:
        logger.warning("decrypt: plaintext not valid utf-8")
        return None


def encrypt_float(value: float) -> Optional[str]:
    """Encrypt a float value."""
    return encrypt(str(value))


def decrypt_float(token: str) -> Optional[float]:
    """Decrypt a token back to float. Returns None if the token cannot be
    decrypted or the plaintext is not a valid float."""
    plain = decrypt(token)
    if plain is None:
        return None
    try:
        return float(plain)
    except ValueError:
        logger.warning("decrypt_float: plaintext is not a float")
        return None
