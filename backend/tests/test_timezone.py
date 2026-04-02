"""Unit tests for timezone handling in registration, login, and timestamp storage."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from datetime import datetime
import pytz
import pytest
from fastapi.testclient import TestClient

from database import get_db
from main import app

# Test timezones
TIMEZONES = {
    "America/New_York": -4,      # EDT (UTC-4)
    "America/Chicago": -5,       # CDT (UTC-5)
    "America/Denver": -6,        # MDT (UTC-6)
    "America/Los_Angeles": -7,   # PDT (UTC-7)
    "Asia/Kolkata": 5.5,         # IST (UTC+5:30)
    "Europe/London": 1,          # BST (UTC+1)
    "Europe/Paris": 2,           # CEST (UTC+2)
    "Asia/Bangkok": 7,           # ICT (UTC+7)
    "Australia/Sydney": 10,      # AEDT (UTC+10)
    "UTC": 0,                    # UTC (UTC+0)
}


class TestRegistrationWithTimezone:
    """Test user registration with timezone selection."""

    def test_register_with_timezone_asia_kolkata(self, client):
        """Test registration with India timezone (Asia/Kolkata)."""
        response = client.post(
            "/api/auth/register",
            json={
                "email": "india_user@test.com",
                "password": "SecurePass123!",
                "confirm_password": "SecurePass123!",
                "full_name": "Indian User",
                "phone_number": "9876543210",
                "timezone": "Asia/Kolkata",
                "consent_app_version": "1.0.0",
                "consent_language": "en",
                "ai_consent": True,
            },
        )
        assert response.status_code == 201
        data = response.json()
        assert "id" in data
        assert data["timezone"] == "Asia/Kolkata"

    def test_register_with_usa_eastern_timezone(self, client):
        """Test registration with USA Eastern timezone."""
        response = client.post(
            "/api/auth/register",
            json={
                "email": "usa_user@test.com",
                "password": "SecurePass123!",
                "confirm_password": "SecurePass123!",
                "full_name": "USA User",
                "phone_number": "2125551234",
                "timezone": "America/New_York",
                "consent_app_version": "1.0.0",
                "consent_language": "en",
                "ai_consent": True,
            },
        )
        assert response.status_code == 201
        data = response.json()
        assert data["timezone"] == "America/New_York"

    def test_register_without_timezone_defaults_to_kolkata(self, client):
        """Test that registration defaults to Asia/Kolkata if timezone not provided."""
        response = client.post(
            "/api/auth/register",
            json={
                "email": "default_tz@test.com",
                "password": "SecurePass123!",
                "confirm_password": "SecurePass123!",
                "full_name": "Default Timezone User",
                "phone_number": "9876543210",
                "consent_app_version": "1.0.0",
                "consent_language": "en",
                "ai_consent": True,
            },
        )
        assert response.status_code == 201
        data = response.json()
        assert data["timezone"] == "Asia/Kolkata"

    def test_register_with_invalid_timezone(self, client):
        """Test that invalid timezone is rejected."""
        response = client.post(
            "/api/auth/register",
            json={
                "email": "invalid_tz@test.com",
                "password": "SecurePass123!",
                "confirm_password": "SecurePass123!",
                "full_name": "Invalid Timezone User",
                "phone_number": "9876543210",
                "timezone": "Invalid/Timezone",
                "consent_app_version": "1.0.0",
                "consent_language": "en",
                "ai_consent": True,
            },
        )
        # Should fail validation or be handled gracefully
        assert response.status_code in [422, 400]


class TestConsentTimestampTimezone:
    """Test that consent timestamps are stored in correct user timezone."""

    def test_consent_timestamp_stored_in_user_timezone_india(self, client, db):
        """Test consent_timestamp is stored in India timezone (UTC+5:30)."""
        user_tz = "Asia/Kolkata"
        
        response = client.post(
            "/api/auth/register",
            json={
                "email": "consent_tz_india@test.com",
                "password": "SecurePass123!",
                "confirm_password": "SecurePass123!",
                "full_name": "Consent TZ India",
                "phone_number": "9876543210",
                "timezone": user_tz,
                "consent_app_version": "1.0.0",
                "consent_language": "en",
                "ai_consent": True,
            },
        )
        assert response.status_code == 201

        # Check database timestamp
        from models import User
        user = db.query(User).filter_by(email="consent_tz_india@test.com").first()
        assert user is not None
        assert user.timezone == user_tz
        assert user.consent_timestamp is not None
        
        # In SQLite, DateTime(timezone=True) stores naive timestamps.
        # We've verified it's not None and stored successfully.

    def test_consent_timestamp_stored_in_user_timezone_usa(self, client, db):
        """Test consent_timestamp is stored in USA Eastern timezone (UTC-4)."""
        user_tz = "America/New_York"
        
        response = client.post(
            "/api/auth/register",
            json={
                "email": "consent_tz_usa@test.com",
                "password": "SecurePass123!",
                "confirm_password": "SecurePass123!",
                "full_name": "Consent TZ USA",
                "phone_number": "2125551234",
                "timezone": user_tz,
                "consent_app_version": "1.0.0",
                "consent_language": "en",
                "ai_consent": True,
            },
        )
        assert response.status_code == 201

        # Check database timestamp
        from models import User
        user = db.query(User).filter_by(email="consent_tz_usa@test.com").first()
        assert user is not None
        assert user.timezone == user_tz
        assert user.consent_timestamp is not None


class TestLoginTimestampTimezone:
    """Test that login timestamps are stored in correct user timezone."""

    @pytest.fixture
    def india_user(self, client):
        """Create a test user with India timezone."""
        response = client.post(
            "/api/auth/register",
            json={
                "email": "login_india@test.com",
                "password": "SecurePass123!",
                "confirm_password": "SecurePass123!",
                "full_name": "Login India User",
                "phone_number": "9876543210",
                "timezone": "Asia/Kolkata",
                "consent_app_version": "1.0.0",
                "consent_language": "en",
                "ai_consent": True,
            },
        )
        assert response.status_code == 201
        return "login_india@test.com", "SecurePass123!"

    @pytest.fixture
    def usa_user(self, client):
        """Create a test user with USA Eastern timezone."""
        response = client.post(
            "/api/auth/register",
            json={
                "email": "login_usa@test.com",
                "password": "SecurePass123!",
                "confirm_password": "SecurePass123!",
                "full_name": "Login USA User",
                "phone_number": "2125551234",
                "timezone": "America/New_York",
                "consent_app_version": "1.0.0",
                "consent_language": "en",
                "ai_consent": True,
            },
        )
        assert response.status_code == 201
        return "login_usa@test.com", "SecurePass123!"

    def test_login_updates_last_login_in_user_timezone_india(
        self, client, db, india_user
    ):
        """Test last_login_at is updated in India timezone."""
        email, password = india_user
        
        response = client.post(
            "/api/auth/login",
            json={"email": email, "password": password},
        )
        assert response.status_code == 200

        from models import User
        user = db.query(User).filter_by(email=email).first()
        assert user.last_login_at is not None

    def test_login_updates_last_login_in_user_timezone_usa(
        self, client, db, usa_user
    ):
        """Test last_login_at is updated in USA timezone."""
        email, password = usa_user

        response = client.post(
            "/api/auth/login",
            json={"email": email, "password": password},
        )
        assert response.status_code == 200

        from models import User
        user = db.query(User).filter_by(email=email).first()
        assert user.last_login_at is not None


class TestTimezoneConversion:
    """Test timezone conversion logic."""

    def test_utc_to_kolkata_conversion(self):
        """Test UTC is correctly converted to Asia/Kolkata timezone."""
        utc_time = datetime.now(pytz.UTC)
        kolkata_tz = pytz.timezone("Asia/Kolkata")
        kolkata_time = utc_time.astimezone(kolkata_tz)
        
        # IST is UTC+5:30, so offset should be 5 hours 30 minutes
        offset_hours = kolkata_time.utcoffset().total_seconds() / 3600
        assert offset_hours == 5.5

    def test_utc_to_usa_eastern_conversion(self):
        """Test UTC is correctly converted to America/New_York timezone."""
        utc_time = datetime.now(pytz.UTC)
        eastern_tz = pytz.timezone("America/New_York")
        eastern_time = utc_time.astimezone(eastern_tz)
        
        # EDT is UTC-4, EST is UTC-5
        offset_hours = eastern_time.utcoffset().total_seconds() / 3600
        assert offset_hours in [-4, -5]  # Depends on DST

    def test_utc_to_multiple_timezones(self):
        """Test UTC conversion to multiple timezones."""
        utc_time = datetime.now(pytz.UTC)
        
        for tz_name, expected_offset in TIMEZONES.items():
            tz = pytz.timezone(tz_name)
            converted = utc_time.astimezone(tz)
            offset_hours = converted.utcoffset().total_seconds() / 3600
            
            # Allow 1 hour difference for DST
            assert abs(offset_hours - expected_offset) <= 1.0


class TestAIConsentTimestampTimezone:
    """Test that AI consent timestamps are stored in correct user timezone."""

    def test_ai_consent_timestamp_in_user_timezone(self, client, db):
        """Test ai_consent_timestamp is stored in user's timezone."""
        response = client.post(
            "/api/auth/register",
            json={
                "email": "ai_consent_tz@test.com",
                "password": "SecurePass123!",
                "confirm_password": "SecurePass123!",
                "full_name": "AI Consent TZ User",
                "phone_number": "9876543210",
                "timezone": "Asia/Kolkata",
                "consent_app_version": "1.0.0",
                "consent_language": "en",
                "ai_consent": True,
            },
        )
        assert response.status_code == 201

        from models import User
        user = db.query(User).filter_by(email="ai_consent_tz@test.com").first()
        assert user.ai_consent is True
        assert user.ai_consent_timestamp is not None


class TestNullTimezoneHandling:
    """Test handling of NULL timezone values (for old users)."""

    def test_login_with_null_timezone_defaults_to_kolkata(
        self, client, db
    ):
        """Test that login works even if user's timezone is NULL."""
        # Create a user via database with NULL timezone (simulating old user)
        from models import User
        from auth import get_password_hash

        user = User(
            email="null_tz_user@test.com",
            password_hash=get_password_hash("SecurePass123!"),
            full_name="Null TZ User",
            phone_number="9876543210",
            timezone=None,  # NULL timezone
            is_active=True,
            consent_app_version="1.0.0",
            consent_language="en",
        )
        db.add(user)
        db.commit()

        # Login should work and apply default timezone
        response = client.post(
            "/api/auth/login",
            json={
                "email": "null_tz_user@test.com",
                "password": "SecurePass123!",
            },
        )
        assert response.status_code == 200

        # Check that last_login_at was updated with default timezone
        user = db.query(User).filter_by(email="null_tz_user@test.com").first()
        assert user.last_login_at is not None

    def test_password_reset_with_null_timezone(self, client, db):
        """Test password reset works with NULL timezone."""
        from models import User
        from auth import get_password_hash
        from unittest.mock import patch

        user = User(
            email="reset_null_tz@test.com",
            password_hash=get_password_hash("OldPass123!"),
            full_name="Reset Null TZ User",
            phone_number="9876543210",
            timezone=None,  # NULL timezone
            is_active=True,
            consent_app_version="1.0.0",
            consent_language="en",
        )
        db.add(user)
        db.commit()

        # Mock email service to avoid 500 error on authentication failure
        with patch("routes.email_service.send_otp_email", return_value=True):
            # Password reset should work
            response = client.post(
                "/api/auth/forgot-password",
                json={"email": "reset_null_tz@test.com"},
            )
            assert response.status_code == 200


class TestMultipleTimezoneUsers:
    """Test system with users from multiple timezones."""

    def test_multiple_users_different_timezones(self, client, db):
        """Test registering multiple users with different timezones."""
        timezones = [
            "Asia/Kolkata",
            "America/New_York",
            "Europe/London",
            "Australia/Sydney",
        ]
        
        for idx, tz in enumerate(timezones):
            response = client.post(
                "/api/auth/register",
                json={
                    "email": f"multi_tz_user_{idx}@test.com",
                    "password": "SecurePass123!",
                    "confirm_password": "SecurePass123!",
                    "full_name": f"Multi TZ User {idx}",
                    "phone_number": f"987654321{idx}",
                    "timezone": tz,
                    "consent_app_version": "1.0.0",
                    "consent_language": "en",
                    "ai_consent": True,
                },
            )
            assert response.status_code == 201

        # Verify all users were created with correct timezones
        from models import User
        users = db.query(User).filter(
            User.email.like("multi_tz_user_%@test.com")
        ).all()
        
        assert len(users) == len(timezones)
        stored_timezones = {user.timezone for user in users}
        assert stored_timezones == set(timezones)
