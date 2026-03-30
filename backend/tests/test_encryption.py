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
