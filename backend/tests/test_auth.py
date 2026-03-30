"""Unit tests for backend/auth.py — password hashing and JWT token functions."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from datetime import timedelta

from auth import (
    verify_password,
    get_password_hash,
    create_access_token,
    decode_access_token,
)


# ---------------------------------------------------------------------------
# verify_password
# ---------------------------------------------------------------------------

class TestVerifyPassword:
    def test_correct_password(self):
        hashed = get_password_hash("MySecretPass1!")
        assert verify_password("MySecretPass1!", hashed) is True

    def test_wrong_password(self):
        hashed = get_password_hash("MySecretPass1!")
        assert verify_password("WrongPass", hashed) is False

    def test_empty_password_rejected(self):
        hashed = get_password_hash("Something1!")
        assert verify_password("", hashed) is False


# ---------------------------------------------------------------------------
# get_password_hash
# ---------------------------------------------------------------------------

class TestGetPasswordHash:
    def test_returns_bcrypt_hash(self):
        h = get_password_hash("Test@1234")
        # bcrypt hashes start with $2b$ (or $2a$/$2y$)
        assert h.startswith("$2")

    def test_hash_verifies(self):
        pw = "AnotherPass9#"
        h = get_password_hash(pw)
        assert verify_password(pw, h)

    def test_different_calls_produce_different_hashes(self):
        h1 = get_password_hash("Same@Pass1")
        h2 = get_password_hash("Same@Pass1")
        # Salt should differ
        assert h1 != h2


# ---------------------------------------------------------------------------
# create_access_token
# ---------------------------------------------------------------------------

class TestCreateAccessToken:
    def test_returns_string(self):
        token = create_access_token(data={"sub": "user@example.com"})
        assert isinstance(token, str)
        # JWT has 3 dot-separated parts
        assert len(token.split(".")) == 3

    def test_contains_sub_claim(self):
        token = create_access_token(data={"sub": "user@example.com"})
        payload = decode_access_token(token)
        assert payload is not None
        assert payload["sub"] == "user@example.com"

    def test_custom_expiry(self):
        token = create_access_token(
            data={"sub": "user@example.com"},
            expires_delta=timedelta(hours=2),
        )
        payload = decode_access_token(token)
        assert payload is not None
        assert "exp" in payload


# ---------------------------------------------------------------------------
# decode_access_token
# ---------------------------------------------------------------------------

class TestDecodeAccessToken:
    def test_valid_token(self):
        token = create_access_token(data={"sub": "a@b.com", "extra": 42})
        payload = decode_access_token(token)
        assert payload is not None
        assert payload["sub"] == "a@b.com"
        assert payload["extra"] == 42

    def test_invalid_token_returns_none(self):
        assert decode_access_token("not.a.valid.jwt") is None

    def test_expired_token_returns_none(self):
        token = create_access_token(
            data={"sub": "a@b.com"},
            expires_delta=timedelta(seconds=-1),
        )
        assert decode_access_token(token) is None

    def test_tampered_token_returns_none(self):
        token = create_access_token(data={"sub": "a@b.com"})
        # Flip a character in the signature part
        parts = token.split(".")
        sig = parts[2]
        tampered_sig = sig[:-1] + ("A" if sig[-1] != "A" else "B")
        tampered = ".".join([parts[0], parts[1], tampered_sig])
        assert decode_access_token(tampered) is None
