"""Tests for forgot-password / verify-otp / reset-password flow."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from unittest.mock import patch
from datetime import datetime, timedelta
from tests.conftest import TEST_USER_EMAIL, TEST_USER_PASSWORD
import models


class TestForgotPassword:
    URL = "/api/auth/forgot-password"

    @patch("routes.email_service.send_otp_email", return_value=True)
    def test_forgot_password_sends_otp(self, mock_send, client, test_user):
        resp = client.post(self.URL, json={"email": TEST_USER_EMAIL})
        assert resp.status_code == 200
        assert "OTP sent" in resp.json()["message"]
        mock_send.assert_called_once()

    def test_forgot_password_nonexistent_email(self, client):
        resp = client.post(self.URL, json={"email": "nobody@swasth.app"})
        assert resp.status_code == 404

    def test_forgot_password_invalid_email(self, client):
        resp = client.post(self.URL, json={"email": "not-an-email"})
        assert resp.status_code == 422

    @patch("routes.email_service.send_otp_email", return_value=False)
    def test_forgot_password_email_failure(self, mock_send, client, test_user):
        resp = client.post(self.URL, json={"email": TEST_USER_EMAIL})
        assert resp.status_code == 500
        assert "Failed to send" in resp.json()["detail"]


class TestVerifyOTP:
    URL = "/api/auth/verify-otp"

    def test_verify_valid_otp(self, client, test_user, db):
        otp = models.PasswordResetOTP(
            email=TEST_USER_EMAIL,
            otp="123456",
            expires_at=datetime.utcnow() + timedelta(minutes=10),
        )
        db.add(otp)
        db.flush()

        resp = client.post(self.URL, json={
            "email": TEST_USER_EMAIL,
            "otp": "123456",
        })
        assert resp.status_code == 200
        assert "verified" in resp.json()["message"].lower()

    def test_verify_wrong_otp(self, client, test_user, db):
        otp = models.PasswordResetOTP(
            email=TEST_USER_EMAIL,
            otp="123456",
            expires_at=datetime.utcnow() + timedelta(minutes=10),
        )
        db.add(otp)
        db.flush()

        resp = client.post(self.URL, json={
            "email": TEST_USER_EMAIL,
            "otp": "999999",
        })
        assert resp.status_code == 400

    def test_verify_expired_otp(self, client, test_user, db):
        otp = models.PasswordResetOTP(
            email=TEST_USER_EMAIL,
            otp="123456",
            expires_at=datetime.utcnow() - timedelta(minutes=1),
        )
        db.add(otp)
        db.flush()

        resp = client.post(self.URL, json={
            "email": TEST_USER_EMAIL,
            "otp": "123456",
        })
        assert resp.status_code == 400


class TestResetPassword:
    URL = "/api/auth/reset-password"

    def test_reset_password_success(self, client, test_user, db):
        otp = models.PasswordResetOTP(
            email=TEST_USER_EMAIL,
            otp="654321",
            expires_at=datetime.utcnow() + timedelta(minutes=10),
        )
        db.add(otp)
        db.flush()

        resp = client.post(self.URL, json={
            "email": TEST_USER_EMAIL,
            "otp": "654321",
            "new_password": "NewPass@999",
            "confirm_password": "NewPass@999",
        })
        assert resp.status_code == 200
        assert "reset successfully" in resp.json()["message"].lower()

        # Verify new password works for login
        login_resp = client.post("/api/auth/login", json={
            "email": TEST_USER_EMAIL,
            "password": "NewPass@999",
        })
        assert login_resp.status_code == 200

    def test_reset_password_invalid_otp(self, client, test_user):
        resp = client.post(self.URL, json={
            "email": TEST_USER_EMAIL,
            "otp": "000000",
            "new_password": "NewPass@999",
            "confirm_password": "NewPass@999",
        })
        assert resp.status_code == 400

    def test_reset_password_weak_password(self, client, test_user, db):
        otp = models.PasswordResetOTP(
            email=TEST_USER_EMAIL,
            otp="111111",
            expires_at=datetime.utcnow() + timedelta(minutes=10),
        )
        db.add(otp)
        db.flush()

        resp = client.post(self.URL, json={
            "email": TEST_USER_EMAIL,
            "otp": "111111",
            "new_password": "weak",
            "confirm_password": "weak",
        })
        assert resp.status_code == 422
