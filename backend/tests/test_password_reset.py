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
    GENERIC_MSG_FRAGMENT = "If an account"

    @patch("routes.email_service.send_otp_email", return_value=True)
    def test_forgot_password_sends_otp_for_registered_user(self, mock_send, client, test_user):
        resp = client.post(self.URL, json={"email": TEST_USER_EMAIL})
        assert resp.status_code == 200
        assert self.GENERIC_MSG_FRAGMENT in resp.json()["message"]
        mock_send.assert_called_once()

    def test_forgot_password_nonexistent_email_returns_generic_response(self, client):
        # Anti-enumeration: unknown emails must return the same 200 + message
        # as a valid registered email. Returning 404 previously let attackers
        # discover which emails are registered, violating DPDPA.
        resp = client.post(self.URL, json={"email": "nobody@swasth.app"})
        assert resp.status_code == 200
        assert self.GENERIC_MSG_FRAGMENT in resp.json()["message"]

    def test_forgot_password_response_identical_for_known_and_unknown(self, client, test_user):
        # The response body for a known vs unknown email must be byte-for-byte
        # identical — any difference (message, field order, extra keys) leaks
        # account existence.
        with patch("routes.email_service.send_otp_email", return_value=True):
            known = client.post(self.URL, json={"email": TEST_USER_EMAIL})
        unknown = client.post(self.URL, json={"email": "nobody@swasth.app"})
        assert known.status_code == unknown.status_code == 200
        assert known.json() == unknown.json()

    def test_forgot_password_invalid_email(self, client):
        resp = client.post(self.URL, json={"email": "not-an-email"})
        assert resp.status_code == 422

    @patch("routes.email_service.send_otp_email", return_value=False)
    def test_forgot_password_email_send_failure_hidden_from_client(self, mock_send, client, test_user):
        # If SMTP is down, the client still gets the generic 200 response —
        # otherwise a differential (500 for registered, 200 for unknown) would
        # also enumerate accounts.
        resp = client.post(self.URL, json={"email": TEST_USER_EMAIL})
        assert resp.status_code == 200
        assert self.GENERIC_MSG_FRAGMENT in resp.json()["message"]

    def test_forgot_password_email_dispatched_via_background_task(
        self, client, test_user
    ):
        # Timing parity: the SMTP send must happen AFTER the response is
        # written so the wall-clock time of a known-email request matches
        # an unknown-email request (closes the timing side-channel Security
        # flagged in PR #139). TestClient runs BackgroundTasks to completion
        # before returning from .post(), so by then the mock has been called.
        with patch("routes.email_service.send_otp_email", return_value=True) as mock_send:
            resp = client.post(self.URL, json={"email": TEST_USER_EMAIL})
            assert resp.status_code == 200
            assert self.GENERIC_MSG_FRAGMENT in resp.json()["message"]
            mock_send.assert_called_once()

    def test_forgot_password_unknown_email_does_not_dispatch_email(
        self, client
    ):
        # An unknown email must NOT trigger send_otp_email — that would
        # both leak existence and waste an SMTP round-trip.
        with patch("routes.email_service.send_otp_email", return_value=True) as mock_send:
            resp = client.post(self.URL, json={"email": "nobody@swasth.app"})
            assert resp.status_code == 200
            mock_send.assert_not_called()


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
