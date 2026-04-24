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


# ---------------------------------------------------------------------------
# PII encryption — separate key, separate blast radius
# ---------------------------------------------------------------------------

class TestPIIEncryption:
    @patch("encryption_service.settings")
    def test_pii_roundtrip(self, mock_settings):
        import secrets
        mock_settings.ENCRYPTION_KEY = secrets.token_hex(32)
        mock_settings.PII_ENCRYPTION_KEY = secrets.token_hex(32)
        from encryption_service import encrypt_pii, decrypt_pii
        token = encrypt_pii("amit@example.com")
        assert token is not None
        assert decrypt_pii(token) == "amit@example.com"

    @patch("encryption_service.settings")
    def test_pii_none_input_returns_none(self, mock_settings):
        import secrets
        mock_settings.PII_ENCRYPTION_KEY = secrets.token_hex(32)
        from encryption_service import encrypt_pii
        assert encrypt_pii(None) is None
        assert encrypt_pii("") is None

    @patch("encryption_service.settings")
    def test_pii_returns_none_when_key_missing(self, mock_settings):
        mock_settings.PII_ENCRYPTION_KEY = None
        from encryption_service import encrypt_pii, decrypt_pii
        assert encrypt_pii("anything") is None
        assert decrypt_pii("anything") is None

    @patch("encryption_service.settings")
    def test_pii_and_spdi_keys_are_independent(self, mock_settings):
        """A PII token must not decrypt with the SPDI key and vice versa."""
        import secrets
        spdi_k = secrets.token_hex(32)
        pii_k = secrets.token_hex(32)
        mock_settings.ENCRYPTION_KEY = spdi_k
        mock_settings.PII_ENCRYPTION_KEY = pii_k
        from encryption_service import encrypt, decrypt, encrypt_pii, decrypt_pii
        pii_token = encrypt_pii("secret name")
        spdi_token = encrypt("120")
        # Cross-decrypt must fail (returns None, not raise)
        assert decrypt(pii_token) is None
        assert decrypt_pii(spdi_token) is None
        # Correct-key decrypt still works
        assert decrypt_pii(pii_token) == "secret name"
        assert decrypt(spdi_token) == "120"

    @patch("encryption_service.settings")
    def test_pii_rejects_invalid_hex_key(self, mock_settings):
        mock_settings.PII_ENCRYPTION_KEY = "not-valid-hex"
        from encryption_service import encrypt_pii
        assert encrypt_pii("test") is None

    @patch("encryption_service.settings")
    def test_pii_rejects_wrong_length_key(self, mock_settings):
        # Valid hex but only 16 bytes (32 chars) — AES-256-GCM needs 32 bytes
        mock_settings.PII_ENCRYPTION_KEY = "a" * 32
        from encryption_service import encrypt_pii
        assert encrypt_pii("test") is None


class TestPIIListEncryption:
    @patch("encryption_service.settings")
    def test_list_roundtrip(self, mock_settings):
        import secrets
        mock_settings.PII_ENCRYPTION_KEY = secrets.token_hex(32)
        from encryption_service import encrypt_pii_list, decrypt_pii_list
        original = ["diabetes", "hypertension", "asthma"]
        token = encrypt_pii_list(original)
        assert token is not None
        assert decrypt_pii_list(token) == original

    @patch("encryption_service.settings")
    def test_empty_list_roundtrip(self, mock_settings):
        import secrets
        mock_settings.PII_ENCRYPTION_KEY = secrets.token_hex(32)
        from encryption_service import encrypt_pii_list, decrypt_pii_list
        token = encrypt_pii_list([])
        assert token is not None
        assert decrypt_pii_list(token) == []

    @patch("encryption_service.settings")
    def test_none_list_returns_none(self, mock_settings):
        import secrets
        mock_settings.PII_ENCRYPTION_KEY = secrets.token_hex(32)
        from encryption_service import encrypt_pii_list
        assert encrypt_pii_list(None) is None

    @patch("encryption_service.settings")
    def test_decrypt_list_handles_tampered(self, mock_settings):
        import secrets
        mock_settings.PII_ENCRYPTION_KEY = secrets.token_hex(32)
        from encryption_service import encrypt_pii_list, decrypt_pii_list
        token = encrypt_pii_list(["x"])
        tampered = token[:20] + ("A" if token[20] != "A" else "B") + token[21:]
        assert decrypt_pii_list(tampered) is None


class TestBlindIndexHashes:
    @patch("encryption_service.settings")
    def test_email_hash_deterministic(self, mock_settings):
        import secrets
        mock_settings.PII_ENCRYPTION_KEY = secrets.token_hex(32)
        from encryption_service import hash_email
        h1 = hash_email("amit@example.com")
        h2 = hash_email("amit@example.com")
        assert h1 == h2

    @patch("encryption_service.settings")
    def test_email_hash_case_insensitive(self, mock_settings):
        import secrets
        mock_settings.PII_ENCRYPTION_KEY = secrets.token_hex(32)
        from encryption_service import hash_email
        assert hash_email("Amit@Example.COM") == hash_email("amit@example.com")

    @patch("encryption_service.settings")
    def test_email_hash_trims_whitespace(self, mock_settings):
        import secrets
        mock_settings.PII_ENCRYPTION_KEY = secrets.token_hex(32)
        from encryption_service import hash_email
        assert hash_email("  amit@example.com  ") == hash_email("amit@example.com")

    @patch("encryption_service.settings")
    def test_email_hash_different_keys_produce_different_hashes(self, mock_settings):
        import secrets
        from encryption_service import hash_email
        mock_settings.PII_ENCRYPTION_KEY = secrets.token_hex(32)
        h1 = hash_email("amit@example.com")
        mock_settings.PII_ENCRYPTION_KEY = secrets.token_hex(32)
        h2 = hash_email("amit@example.com")
        assert h1 != h2

    @patch("encryption_service.settings")
    def test_email_hash_none_when_key_missing(self, mock_settings):
        mock_settings.PII_ENCRYPTION_KEY = None
        from encryption_service import hash_email
        assert hash_email("amit@example.com") is None

    @patch("encryption_service.settings")
    def test_email_hash_none_for_empty(self, mock_settings):
        import secrets
        mock_settings.PII_ENCRYPTION_KEY = secrets.token_hex(32)
        from encryption_service import hash_email
        assert hash_email(None) is None
        assert hash_email("") is None

    @patch("encryption_service.settings")
    def test_phone_hash_normalizes_e164(self, mock_settings):
        import secrets
        mock_settings.PII_ENCRYPTION_KEY = secrets.token_hex(32)
        from encryption_service import hash_phone
        # All these should produce the same hash
        variants = [
            "7001234567",
            "+917001234567",
            "+91 70012 34567",
            "917001234567",
            "07001234567",
            "+91-7001234567",
        ]
        hashes = [hash_phone(v) for v in variants]
        assert all(h == hashes[0] for h in hashes), f"phone hashes diverged: {hashes}"

    @patch("encryption_service.settings")
    def test_phone_hash_different_numbers_differ(self, mock_settings):
        import secrets
        mock_settings.PII_ENCRYPTION_KEY = secrets.token_hex(32)
        from encryption_service import hash_phone
        assert hash_phone("7001234567") != hash_phone("7001234568")


class TestOTPHashing:
    @patch("encryption_service.settings")
    def test_otp_hash_deterministic(self, mock_settings):
        import secrets
        mock_settings.PII_ENCRYPTION_KEY = secrets.token_hex(32)
        from encryption_service import hash_otp
        assert hash_otp("123456") == hash_otp("123456")

    @patch("encryption_service.settings")
    def test_otp_hash_different_inputs_differ(self, mock_settings):
        import secrets
        mock_settings.PII_ENCRYPTION_KEY = secrets.token_hex(32)
        from encryption_service import hash_otp
        assert hash_otp("123456") != hash_otp("123457")

    @patch("encryption_service.settings")
    def test_otp_hash_keyed_differs_from_sha256(self, mock_settings):
        """With PII key set, hash must be HMAC not raw sha256 — defense against
        rainbow-table attacks on the 6-digit OTP space."""
        import hashlib
        import secrets
        mock_settings.PII_ENCRYPTION_KEY = secrets.token_hex(32)
        from encryption_service import hash_otp
        plain_sha = hashlib.sha256(b"123456").hexdigest()
        assert hash_otp("123456") != plain_sha

    @patch("encryption_service.settings")
    def test_otp_hash_falls_back_to_sha256_when_key_missing(self, mock_settings):
        """Dev bootstrap: key unset → plain sha256. Still one-way, caller warned."""
        import hashlib
        mock_settings.PII_ENCRYPTION_KEY = None
        from encryption_service import hash_otp
        assert hash_otp("123456") == hashlib.sha256(b"123456").hexdigest()

    @patch("encryption_service.settings")
    def test_otp_hash_empty_returns_none(self, mock_settings):
        import secrets
        mock_settings.PII_ENCRYPTION_KEY = secrets.token_hex(32)
        from encryption_service import hash_otp
        assert hash_otp(None) is None
        assert hash_otp("") is None


class TestNormalization:
    def test_normalize_email(self):
        from encryption_service import normalize_email
        assert normalize_email("Amit@Example.COM") == "amit@example.com"
        assert normalize_email("  amit@example.com  ") == "amit@example.com"
        assert normalize_email(None) == ""
        assert normalize_email("") == ""

    def test_normalize_phone(self):
        from encryption_service import normalize_phone
        assert normalize_phone("7001234567") == "+917001234567"
        assert normalize_phone("+917001234567") == "+917001234567"
        assert normalize_phone("+91 70012 34567") == "+917001234567"
        assert normalize_phone("07001234567") == "+917001234567"
        assert normalize_phone("917001234567") == "+917001234567"
        assert normalize_phone(None) == ""
        assert normalize_phone("") == ""
