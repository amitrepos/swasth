"""Tests for POST /api/admin/users (G6 admin-creates-user)."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import json

import pytest
from pydantic import ValidationError

import models
import schemas
from auth import get_password_hash, create_access_token
from encryption_service import hash_email


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture()
def admin_user(db):
    user = models.User(
        email="admin-acu@swasth.app",
        password_hash=get_password_hash("Admin@1234"),
        full_name="Admin User",
        phone_number="9876500001",
        is_admin=True,
    )
    db.add(user)
    db.flush()
    return user


@pytest.fixture()
def admin_headers(admin_user):
    token = create_access_token(data={"sub": admin_user.email})
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture()
def non_admin_user(db):
    user = models.User(
        email="patient-acu@swasth.app",
        password_hash=get_password_hash("Patient@1234"),
        full_name="Normal Patient",
        phone_number="9876500002",
        is_admin=False,
    )
    db.add(user)
    db.flush()
    return user


@pytest.fixture()
def non_admin_headers(non_admin_user):
    token = create_access_token(data={"sub": non_admin_user.email})
    return {"Authorization": f"Bearer {token}"}


def _valid_patient_payload(**overrides) -> dict:
    payload = {
        "email": "newpatient@test.com",
        "password": "ValidPass1!",
        "full_name": "Sunita Devi",
        "phone_number": "9876543210",
        "role": "patient",
    }
    payload.update(overrides)
    return payload


# ---------------------------------------------------------------------------
# Endpoint tests — happy paths, authz, validation, audit log
# ---------------------------------------------------------------------------


class TestAdminCreateUserEndpoint:
    URL = "/api/admin/users"

    def test_admin_creates_patient_happy_path(
        self, client, admin_user, admin_headers, db
    ):
        resp = client.post(
            self.URL, headers=admin_headers, json=_valid_patient_payload()
        )
        assert resp.status_code == 201, resp.text
        body = resp.json()
        assert body["role"] == "patient"
        assert body["email"] == "newpatient@test.com"
        assert "doctor_code" not in body or body.get("doctor_code") is None

        # DB side-effects
        created = (
            db.query(models.User)
            .filter(models.User.email_hash == hash_email("newpatient@test.com"))
            .first()
        )
        assert created is not None
        assert created.role == models.UserRole.patient
        assert created.is_active is True
        assert created.password_hash != "ValidPass1!"  # hashed
        assert created.created_at is not None
        # Note: can't assert tz-awareness here because SQLite strips tzinfo
        # on write-back; the fix (datetime.now(timezone.utc)) is validated
        # by the lack of DeprecationWarning for datetime.utcnow in this
        # handler and by the ORM round-trip on PostgreSQL in production.

    def test_admin_create_user_writes_audit_log(
        self, client, admin_user, admin_headers, db
    ):
        resp = client.post(
            self.URL, headers=admin_headers, json=_valid_patient_payload()
        )
        assert resp.status_code == 201
        created_id = resp.json()["id"]
        log = (
            db.query(models.AdminAuditLog)
            .filter_by(action_type="ADMIN_CREATE_USER", target_user_id=created_id)
            .first()
        )
        assert log is not None
        details = json.loads(log.details)
        assert details["role"] == "patient"
        assert details["email"] == "newpatient@test.com"
        # NMC must NOT appear in audit details (PII redaction)
        assert "nmc_number" not in details

    def test_admin_create_user_rejects_doctor_role_with_501(
        self, client, admin_user, admin_headers, db
    ):
        resp = client.post(
            self.URL,
            headers=admin_headers,
            json=_valid_patient_payload(
                role="doctor",
                nmc_number="BMCR/123456",
                specialty="General Physician",
            ),
        )
        assert resp.status_code == 501
        # No user should be created
        assert (
            db.query(models.User).filter(models.User.email_hash == hash_email("newpatient@test.com")).first()
            is None
        )

    def test_admin_create_user_rejects_non_admin(
        self, client, non_admin_user, non_admin_headers, db
    ):
        resp = client.post(
            self.URL, headers=non_admin_headers, json=_valid_patient_payload()
        )
        assert resp.status_code == 403

    def test_admin_create_user_rejects_unauthenticated(self, client):
        resp = client.post(self.URL, json=_valid_patient_payload())
        assert resp.status_code in (401, 403)

    def test_admin_create_user_rejects_duplicate_email(
        self, client, admin_user, admin_headers, db
    ):
        client.post(
            self.URL, headers=admin_headers, json=_valid_patient_payload()
        )
        resp = client.post(
            self.URL, headers=admin_headers, json=_valid_patient_payload()
        )
        assert resp.status_code == 400
        assert "already" in resp.json()["detail"].lower()

    def test_admin_create_user_rejects_invalid_role(
        self, client, admin_user, admin_headers
    ):
        resp = client.post(
            self.URL,
            headers=admin_headers,
            json=_valid_patient_payload(role="superuser"),
        )
        assert resp.status_code == 422

    def test_admin_create_user_rejects_weak_password(
        self, client, admin_user, admin_headers
    ):
        resp = client.post(
            self.URL,
            headers=admin_headers,
            json=_valid_patient_payload(password="abc"),
        )
        assert resp.status_code == 422


# ---------------------------------------------------------------------------
# Schema tests — Tier-1 schemas get 95% coverage target
# ---------------------------------------------------------------------------


class TestAdminCreateUserSchema:
    def test_normalizes_email(self):
        m = schemas.AdminCreateUser(
            email="  FOO@BAR.COM  ",
            password="ValidPass1!",
            full_name="Jane Doe",
            phone_number="9876543210",
            role="patient",
        )
        assert m.email == "foo@bar.com"

    def test_strips_and_normalizes_phone(self):
        m = schemas.AdminCreateUser(
            email="a@b.com",
            password="ValidPass1!",
            full_name="Jane Doe",
            phone_number="+91 98765-43210",
            role="patient",
        )
        assert m.phone_number == "+919876543210"

    def test_extra_fields_rejected(self):
        with pytest.raises(ValidationError):
            schemas.AdminCreateUser(
                email="a@b.com",
                password="ValidPass1!",
                full_name="Jane Doe",
                phone_number="9876543210",
                role="patient",
                is_admin=True,  # must be rejected
            )

    def test_doctor_without_nmc_rejected(self):
        with pytest.raises(ValidationError) as exc:
            schemas.AdminCreateUser(
                email="a@b.com",
                password="ValidPass1!",
                full_name="Dr X",
                phone_number="9876543210",
                role="doctor",
            )
        assert "nmc" in str(exc.value).lower()

    def test_nmc_too_short_rejected(self):
        with pytest.raises(ValidationError):
            schemas.AdminCreateUser(
                email="a@b.com",
                password="ValidPass1!",
                full_name="Dr X",
                phone_number="9876543210",
                role="doctor",
                nmc_number="1234",  # 4 digits — too short
            )

    def test_nmc_valid_formats_accepted(self):
        for value in ("12345", "BMCR/123456", "KMC1234567"):
            m = schemas.AdminCreateUser(
                email="a@b.com",
                password="ValidPass1!",
                full_name="Dr X",
                phone_number="9876543210",
                role="doctor",
                nmc_number=value,
                specialty="General Physician",
            )
            assert m.nmc_number == value.upper()

    def test_invalid_specialty_rejected(self):
        with pytest.raises(ValidationError):
            schemas.AdminCreateUser(
                email="a@b.com",
                password="ValidPass1!",
                full_name="Dr X",
                phone_number="9876543210",
                role="doctor",
                nmc_number="BMCR/123456",
                specialty="Astrologer",
            )

    def test_phone_rejects_letters(self):
        with pytest.raises(ValidationError):
            schemas.AdminCreateUser(
                email="a@b.com",
                password="ValidPass1!",
                full_name="Jane Doe",
                phone_number="98765abc10",
                role="patient",
            )
