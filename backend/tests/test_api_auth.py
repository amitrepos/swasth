"""Integration tests for the /api/auth/* endpoints using FastAPI TestClient."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from tests.conftest import (
    TEST_USER_EMAIL,
    TEST_USER_PASSWORD,
    TEST_USER_NAME,
    TEST_USER_PHONE,
)


# ---------------------------------------------------------------------------
# POST /api/auth/register
# ---------------------------------------------------------------------------

class TestRegister:
    REGISTER_URL = "/api/auth/register"

    def _payload(self, **overrides):
        data = {
            "email": "new@swasth.app",
            "password": "NewPass@123",
            "confirm_password": "NewPass@123",
            "full_name": "New User",
            "phone_number": "9000000001",
        }
        data.update(overrides)
        return data

    def test_register_success(self, client):
        resp = client.post(self.REGISTER_URL, json=self._payload())
        assert resp.status_code == 201
        body = resp.json()
        assert body["email"] == "new@swasth.app"
        assert body["full_name"] == "New User"
        assert "id" in body

    def test_register_duplicate_email(self, client, test_user):
        """Registering with an already-used email should fail."""
        resp = client.post(
            self.REGISTER_URL,
            json=self._payload(email=TEST_USER_EMAIL),
        )
        assert resp.status_code == 400
        assert "already registered" in resp.json()["detail"].lower()

    def test_register_weak_password(self, client):
        resp = client.post(
            self.REGISTER_URL,
            json=self._payload(password="weak", confirm_password="weak"),
        )
        assert resp.status_code == 422  # Pydantic validation error

    def test_register_password_mismatch(self, client):
        resp = client.post(
            self.REGISTER_URL,
            json=self._payload(confirm_password="Different@123"),
        )
        assert resp.status_code == 422


# ---------------------------------------------------------------------------
# POST /api/auth/login
# ---------------------------------------------------------------------------

class TestLogin:
    LOGIN_URL = "/api/auth/login"

    def test_login_success(self, client, test_user):
        resp = client.post(
            self.LOGIN_URL,
            json={"email": TEST_USER_EMAIL, "password": TEST_USER_PASSWORD},
        )
        assert resp.status_code == 200
        body = resp.json()
        assert "access_token" in body
        assert body["token_type"] == "bearer"

    def test_login_wrong_password(self, client, test_user):
        resp = client.post(
            self.LOGIN_URL,
            json={"email": TEST_USER_EMAIL, "password": "Wrong@Pass1"},
        )
        assert resp.status_code == 401
        assert "incorrect" in resp.json()["detail"].lower()

    def test_login_nonexistent_user(self, client):
        resp = client.post(
            self.LOGIN_URL,
            json={"email": "nobody@swasth.app", "password": "Any@Pass1"},
        )
        assert resp.status_code == 401


# ---------------------------------------------------------------------------
# GET /api/auth/me
# ---------------------------------------------------------------------------

class TestMe:
    ME_URL = "/api/auth/me"

    def test_me_with_valid_token(self, client, test_user, auth_headers):
        resp = client.get(self.ME_URL, headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert body["email"] == TEST_USER_EMAIL
        assert body["full_name"] == TEST_USER_NAME

    def test_me_with_invalid_token(self, client):
        resp = client.get(
            self.ME_URL,
            headers={"Authorization": "Bearer invalid.jwt.token"},
        )
        assert resp.status_code == 401

    def test_me_without_token(self, client):
        resp = client.get(self.ME_URL)
        assert resp.status_code == 401
