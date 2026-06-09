"""Encrypted storage helpers for medication package photos."""

from __future__ import annotations

import base64
import os
from pathlib import Path
from typing import Tuple

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

from config import settings

_NONCE_SIZE = 12
_MAX_PHOTOS_PER_PROFILE = 50
_UPLOAD_ROOT = Path(__file__).resolve().parent / "uploads" / "medication_photos"


def _encryption_key() -> bytes:
    key_hex = settings.ENCRYPTION_KEY
    if not key_hex:
        raise ValueError("ENCRYPTION_KEY is required for medication photo encryption")
    try:
        key = bytes.fromhex(key_hex)
    except ValueError as exc:
        raise ValueError("ENCRYPTION_KEY is not valid hex") from exc
    if len(key) != 32:
        raise ValueError("ENCRYPTION_KEY must be 32 bytes (64 hex chars)")
    return key


def _encrypt_bytes(payload: bytes) -> bytes:
    nonce = os.urandom(_NONCE_SIZE)
    aes = AESGCM(_encryption_key())
    return nonce + aes.encrypt(nonce, payload, None)


def _decrypt_bytes(payload: bytes) -> bytes:
    if len(payload) <= _NONCE_SIZE:
        raise ValueError("Encrypted medication photo payload is too short")
    nonce = payload[:_NONCE_SIZE]
    ciphertext = payload[_NONCE_SIZE:]
    aes = AESGCM(_encryption_key())
    return aes.decrypt(nonce, ciphertext, None)


def _sanitize_mime_type(mime_type: str) -> str:
    allowed = set(settings.ALLOWED_IMAGE_MIME_TYPES or [])
    if mime_type in allowed:
        return mime_type
    return "application/octet-stream"


def save_medication_photo(
    *,
    profile_id: int,
    medication_id: int,
    image_bytes: bytes,
    mime_type: str,
) -> str:
    """Encrypt and persist a medication photo; return relative path."""
    profile_dir = _UPLOAD_ROOT / str(profile_id)
    profile_dir.mkdir(parents=True, exist_ok=True)
    existing = list(profile_dir.glob("*.enc"))
    if len(existing) >= _MAX_PHOTOS_PER_PROFILE:
        raise ValueError(
            f"Profile {profile_id} exceeds medication photo limit ({_MAX_PHOTOS_PER_PROFILE})"
        )

    file_name = f"{medication_id}_{base64.urlsafe_b64encode(os.urandom(12)).decode('ascii').rstrip('=')}.enc"
    absolute_path = profile_dir / file_name

    safe_mime = _sanitize_mime_type(mime_type)
    payload = safe_mime.encode("utf-8") + b"\n" + image_bytes
    absolute_path.write_bytes(_encrypt_bytes(payload))

    return str(Path("uploads") / "medication_photos" / str(profile_id) / file_name)


def _resolve_upload_path(relative_path: str) -> Path:
    absolute_path = (Path(__file__).resolve().parent / relative_path).resolve()
    upload_root = _UPLOAD_ROOT.resolve()
    if absolute_path != upload_root and upload_root not in absolute_path.parents:
        raise ValueError("Invalid medication photo path")
    return absolute_path


def load_medication_photo(relative_path: str) -> Tuple[bytes, str]:
    """Load + decrypt medication photo bytes from a relative upload path."""
    absolute_path = _resolve_upload_path(relative_path)
    if not absolute_path.exists() or not absolute_path.is_file():
        raise FileNotFoundError("Medication photo not found")

    decrypted = _decrypt_bytes(absolute_path.read_bytes())
    sep = decrypted.find(b"\n")
    if sep <= 0:
        raise ValueError("Invalid medication photo payload")
    mime = decrypted[:sep].decode("utf-8", errors="replace")
    return decrypted[sep + 1 :], mime


def delete_medication_photo(relative_path: str | None) -> None:
    if not relative_path:
        return
    try:
        absolute_path = _resolve_upload_path(relative_path)
    except ValueError:
        return
    if absolute_path.exists() and absolute_path.is_file():
        absolute_path.unlink()
