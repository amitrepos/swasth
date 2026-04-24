"""Tests for email verification OTP flow."""
import hashlib
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from datetime import datetime, timedelta
from unittest.mock import patch

import models
from email_service import email_service


# ---------------------------------------------------------------------------
# Registration includes email_verified: false
# ---------------------------------------------------------------------------

class TestRegisterEmailVerified:
    def test_register_returns_email_verified_false(self, client):
        resp = client.post("/api/auth/register", json={
            "email": "verify_reg@test.com",
            "password": "Test@1234",
            "confirm_password": "Test@1234",
            "full_name": "Verify Reg",
            "phone_number": "9876543210",
        })
        assert resp.status_code == 201
        data = resp.json()
        assert data["email_verified"] is False

    def test_register_does_not_create_verification_otp(self, client, db):
        """Registration should NOT create verification OTP automatically.
        
        OTP is only sent when user explicitly clicks 'Verify Now' after login.
        """
        with patch.object(email_service, "send_welcome_email", return_value=True):
            resp = client.post("/api/auth/register", json={
                "email": "verify_otp_reg@test.com",
                "password": "Test@1234",
                "confirm_password": "Test@1234",
                "full_name": "OTP Reg",
                "phone_number": "9876543210",
            })
        assert resp.status_code == 201
        user_id = resp.json()["id"]
        
        # No OTP should be created during registration
        otp_record = db.query(models.EmailVerificationOTP).filter(
            models.EmailVerificationOTP.user_id == user_id,
        ).first()
        assert otp_record is None


# ---------------------------------------------------------------------------
# POST /send-email-verification
# ---------------------------------------------------------------------------

class TestSendEmailVerification:
    def test_send_verification_otp(self, client, auth_headers, db, test_user):
        with patch.object(email_service, "send_email_verification_otp", return_value=True) as mock_send:
            resp = client.post("/api/auth/send-email-verification", headers=auth_headers)
        assert resp.status_code == 200
        data = resp.json()
        assert data["message"] == "Verification OTP sent"
        assert data["expires_in_minutes"] == 10
        mock_send.assert_called_once()

    def test_send_verification_creates_otp_record(self, client, auth_headers, db, test_user):
        with patch.object(email_service, "send_email_verification_otp", return_value=True):
            client.post("/api/auth/send-email-verification", headers=auth_headers)

        otp_record = db.query(models.EmailVerificationOTP).filter(
            models.EmailVerificationOTP.user_id == test_user.id,
        ).first()
        assert otp_record is not None
        assert otp_record.email == test_user.email
        assert len(otp_record.otp_hash) == 64  # HMAC-SHA256 hex digest
        assert otp_record.is_used is False

    def test_send_verification_unauthenticated(self, client):
        resp = client.post("/api/auth/send-email-verification")
        assert resp.status_code == 401


# ---------------------------------------------------------------------------
# POST /verify-email
# ---------------------------------------------------------------------------

class TestVerifyEmail:
    def _create_otp(self, db, user, otp="123456", expired=False):
        """Helper to insert a verification OTP record. Model __init__ hashes the OTP."""
        if expired:
            expires_at = datetime.utcnow() - timedelta(minutes=1)
        else:
            expires_at = datetime.utcnow() + timedelta(minutes=10)
        record = models.EmailVerificationOTP(
            user_id=user.id,
            email=user.email,
            otp=otp,  # raw OTP — __init__ hashes via HMAC(PII_KEY)
            expires_at=expires_at,
        )
        db.add(record)
        db.flush()
        return record

    def test_verify_correct_otp(self, client, auth_headers, db, test_user):
        self._create_otp(db, test_user, otp="654321")
        resp = client.post("/api/auth/verify-email", json={"otp": "654321"}, headers=auth_headers)
        assert resp.status_code == 200
        assert resp.json()["message"] == "Email verified successfully"
        db.refresh(test_user)
        assert test_user.email_verified is True
        assert test_user.email_verified_at is not None

    def test_verify_wrong_otp(self, client, auth_headers, db, test_user):
        self._create_otp(db, test_user, otp="654321")
        resp = client.post("/api/auth/verify-email", json={"otp": "000000"}, headers=auth_headers)
        assert resp.status_code == 400
        assert "Invalid or expired OTP" in resp.json()["detail"]

    def test_verify_expired_otp(self, client, auth_headers, db, test_user):
        self._create_otp(db, test_user, otp="654321", expired=True)
        resp = client.post("/api/auth/verify-email", json={"otp": "654321"}, headers=auth_headers)
        assert resp.status_code == 400
        assert "Invalid or expired OTP" in resp.json()["detail"]

    def test_verify_already_used_otp(self, client, auth_headers, db, test_user):
        record = self._create_otp(db, test_user, otp="654321")
        record.is_used = True
        db.flush()
        resp = client.post("/api/auth/verify-email", json={"otp": "654321"}, headers=auth_headers)
        assert resp.status_code == 400

    def test_verify_idempotent_when_already_verified(self, client, auth_headers, db, test_user):
        test_user.email_verified = True
        test_user.email_verified_at = datetime.utcnow()
        db.flush()
        # No OTP needed — should return success
        resp = client.post("/api/auth/verify-email", json={"otp": "000000"}, headers=auth_headers)
        assert resp.status_code == 200
        assert resp.json()["message"] == "Email verified successfully"

    def test_verify_marks_otp_used(self, client, auth_headers, db, test_user):
        record = self._create_otp(db, test_user, otp="654321")
        client.post("/api/auth/verify-email", json={"otp": "654321"}, headers=auth_headers)
        db.refresh(record)
        assert record.is_used is True

    def test_verify_unauthenticated(self, client):
        resp = client.post("/api/auth/verify-email", json={"otp": "123456"})
        assert resp.status_code == 401


# ---------------------------------------------------------------------------
# Resend OTP — old OTPs invalidated
# ---------------------------------------------------------------------------

class TestResendOTP:
    def test_resend_invalidates_old_otps(self, client, auth_headers, db, test_user):
        # Create first OTP manually (__init__ hashes the raw OTP)
        first = models.EmailVerificationOTP(
            user_id=test_user.id,
            email=test_user.email,
            otp="111111",
            expires_at=datetime.utcnow() + timedelta(minutes=10),
        )
        db.add(first)
        db.flush()

        # Resend via endpoint — should invalidate old OTPs
        with patch.object(email_service, "send_email_verification_otp", return_value=True):
            resp = client.post("/api/auth/send-email-verification", headers=auth_headers)
        assert resp.status_code == 200

        # Old OTP should be marked as used
        db.refresh(first)
        assert first.is_used is True

        # Old OTP should NOT work for verification
        resp = client.post("/api/auth/verify-email", json={"otp": "111111"}, headers=auth_headers)
        assert resp.status_code == 400


# ---------------------------------------------------------------------------
# GET /email-verification-status
# ---------------------------------------------------------------------------

class TestEmailVerificationStatus:
    def test_status_unverified(self, client, auth_headers, test_user):
        resp = client.get("/api/auth/email-verification-status", headers=auth_headers)
        assert resp.status_code == 200
        assert resp.json()["email_verified"] is False

    def test_status_verified(self, client, auth_headers, db, test_user):
        test_user.email_verified = True
        test_user.email_verified_at = datetime.utcnow()
        db.flush()
        resp = client.get("/api/auth/email-verification-status", headers=auth_headers)
        assert resp.status_code == 200
        assert resp.json()["email_verified"] is True

    def test_status_unauthenticated(self, client):
        resp = client.get("/api/auth/email-verification-status")
        assert resp.status_code == 401


# ---------------------------------------------------------------------------
# Login works regardless of email_verified status
# ---------------------------------------------------------------------------

class TestLoginRegardlessOfVerification:
    def test_login_works_when_unverified(self, client, test_user):
        resp = client.post("/api/auth/login", json={
            "email": test_user.email,
            "password": "Test@1234",
        })
        assert resp.status_code == 200
        assert "access_token" in resp.json()

    def test_login_works_when_verified(self, client, db, test_user):
        test_user.email_verified = True
        db.flush()
        resp = client.post("/api/auth/login", json={
            "email": test_user.email,
            "password": "Test@1234",
        })
        assert resp.status_code == 200
        assert "access_token" in resp.json()
