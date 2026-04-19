"""Tests for encryption_service.py — AES-256-GCM field-level encryption."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from unittest.mock import patch


class TestEncryptDecryptRoundTrip:
    """Encrypt → decrypt returns the original value."""

    @patch("encryption_service.settings")
    def test_string_roundtrip(self, mock_settings):
        import secrets
        mock_settings.ENCRYPTION_KEY = secrets.token_hex(32)
        from encryption_service import encrypt, decrypt
        token = encrypt("Hello, patient!")
        assert token is not None
        assert decrypt(token) == "Hello, patient!"

    @patch("encryption_service.settings")
    def test_float_roundtrip(self, mock_settings):
        import secrets
        mock_settings.ENCRYPTION_KEY = secrets.token_hex(32)
        from encryption_service import encrypt_float, decrypt_float
        token = encrypt_float(120.5)
        assert token is not None
        assert decrypt_float(token) == 120.5

    @patch("encryption_service.settings")
    def test_float_precision(self, mock_settings):
        import secrets
        mock_settings.ENCRYPTION_KEY = secrets.token_hex(32)
        from encryption_service import encrypt_float, decrypt_float
        assert decrypt_float(encrypt_float(99.99)) == 99.99
        assert decrypt_float(encrypt_float(0.0)) == 0.0

    @patch("encryption_service.settings")
    def test_different_nonces(self, mock_settings):
        """Two encryptions of the same plaintext produce different ciphertext."""
        import secrets
        mock_settings.ENCRYPTION_KEY = secrets.token_hex(32)
        from encryption_service import encrypt
        t1 = encrypt("same")
        t2 = encrypt("same")
        assert t1 != t2  # Random nonce ensures different output


class TestEncryptionKeyNotSet:
    """When ENCRYPTION_KEY is not configured, functions return None."""

    @patch("encryption_service.settings")
    def test_encrypt_returns_none(self, mock_settings):
        mock_settings.ENCRYPTION_KEY = None
        from encryption_service import encrypt
        assert encrypt("test") is None

    @patch("encryption_service.settings")
    def test_decrypt_returns_none(self, mock_settings):
        mock_settings.ENCRYPTION_KEY = None
        from encryption_service import decrypt
        assert decrypt("anything") is None

    @patch("encryption_service.settings")
    def test_encrypt_float_returns_none(self, mock_settings):
        mock_settings.ENCRYPTION_KEY = None
        from encryption_service import encrypt_float
        assert encrypt_float(120.0) is None


class TestDecryptFailureModes:
    """decrypt() must return None (not raise) on any malformed input.

    Legacy rows encrypted with a rotated key, corrupted bytes, or truncated
    base64 must not crash the /api/readings query — the whole endpoint would
    return 500 and the patient would lose access to their history.
    """

    @patch("encryption_service.settings")
    def test_bad_base64_returns_none(self, mock_settings):
        import secrets
        mock_settings.ENCRYPTION_KEY = secrets.token_hex(32)
        from encryption_service import decrypt
        # Not valid base64 at all
        assert decrypt("this is not base64!!!") is None

    @patch("encryption_service.settings")
    def test_short_token_returns_none(self, mock_settings):
        import secrets
        mock_settings.ENCRYPTION_KEY = secrets.token_hex(32)
        from encryption_service import decrypt
        # 3 bytes of valid base64 — shorter than the 12-byte nonce
        assert decrypt("YWFh") is None

    @patch("encryption_service.settings")
    def test_empty_token_returns_none(self, mock_settings):
        import secrets
        mock_settings.ENCRYPTION_KEY = secrets.token_hex(32)
        from encryption_service import decrypt
        assert decrypt("") is None

    @patch("encryption_service.settings")
    def test_wrong_key_returns_none(self, mock_settings):
        # Encrypt with key A, attempt decrypt with key B — should return None,
        # not raise InvalidTag. Simulates key rotation without re-encrypting
        # the backfill.
        import secrets
        from encryption_service import encrypt, decrypt
        mock_settings.ENCRYPTION_KEY = secrets.token_hex(32)
        token = encrypt("patient-secret")
        mock_settings.ENCRYPTION_KEY = secrets.token_hex(32)  # rotate
        assert decrypt(token) is None

    @patch("encryption_service.settings")
    def test_tampered_ciphertext_returns_none(self, mock_settings):
        import secrets
        from encryption_service import encrypt, decrypt
        mock_settings.ENCRYPTION_KEY = secrets.token_hex(32)
        token = encrypt("patient-secret")
        # Flip a byte in the middle of the token
        tampered = token[:20] + ("A" if token[20] != "A" else "B") + token[21:]
        assert decrypt(tampered) is None

    @patch("encryption_service.settings")
    def test_decrypt_float_handles_non_numeric_plaintext(self, mock_settings):
        import secrets
        from encryption_service import encrypt, decrypt_float
        mock_settings.ENCRYPTION_KEY = secrets.token_hex(32)
        token = encrypt("not-a-number")
        assert decrypt_float(token) is None

    @patch("encryption_service.settings")
    def test_decrypt_float_handles_bad_base64(self, mock_settings):
        import secrets
        mock_settings.ENCRYPTION_KEY = secrets.token_hex(32)
        from encryption_service import decrypt_float
        assert decrypt_float("not-base64!!!") is None
