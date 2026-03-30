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
import os
from typing import Optional

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

from config import settings

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
    """Decrypt an AES-256-GCM token back to plaintext string."""
    key = _get_key()
    if key is None or not token:
        return None
    raw = base64.b64decode(token)
    nonce = raw[:_NONCE_SIZE]
    ciphertext = raw[_NONCE_SIZE:]
    aesgcm = AESGCM(key)
    return aesgcm.decrypt(nonce, ciphertext, None).decode("utf-8")


def encrypt_float(value: float) -> Optional[str]:
    """Encrypt a float value."""
    return encrypt(str(value))


def decrypt_float(token: str) -> Optional[float]:
    """Decrypt a token back to float."""
    plain = decrypt(token)
    return float(plain) if plain is not None else None
