"""Integration tests for /api/profiles/* endpoints — CRUD, invites, access control."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch
from tests.conftest import TEST_USER_EMAIL, TEST_USER_PASSWORD
import models
from auth import get_password_hash, create_access_token
from utils.phone import normalize_phone


def _second_user(db):
    """Create a second user for sharing/invite tests."""
    u = models.User(
        email="viewer@swasth.app",
        password_hash=get_password_hash("View@1234"),
        full_name="Viewer User",
        phone_number=normalize_phone("9876500099"),
    )
    db.add(u)
    db.flush()
    return u


def _get_profile_id(db, user_id):
    access = db.query(models.ProfileAccess).filter(
        models.ProfileAccess.user_id == user_id,
        models.ProfileAccess.access_level == "owner",
    ).first()
    return access.profile_id if access else None


# ===========================================================================
# GET /api/profiles
# ===========================================================================

class TestListProfiles:
    URL = "/api/profiles"

    def test_list_own_profiles(self, client, test_user, auth_headers):
        resp = client.get(self.URL, headers=auth_headers)
        assert resp.status_code == 200
        profiles = resp.json()
        assert len(profiles) >= 1
        assert profiles[0]["access_level"] == "owner"

    def test_list_unauthenticated(self, client):
        resp = client.get(self.URL)
        assert resp.status_code == 401


# ===========================================================================
# POST /api/profiles
# ===========================================================================

class TestCreateProfile:
    URL = "/api/profiles"

    def test_create_profile(self, client, test_user, auth_headers):
        resp = client.post(self.URL, json={
            "name": "Mom Health",
            "relationship": "mother",
            "age": 65,
            "gender": "Female",
            "phone_number": "9876543210",
        }, headers=auth_headers)
        assert resp.status_code == 201
        body = resp.json()
        assert body["name"] == "Mom Health"
        assert body["access_level"] == "owner"

    def test_create_profile_minimal(self, client, test_user, auth_headers):
        resp = client.post(self.URL, json={
            "name": "Quick Profile",
            "phone_number": "9876543210",
        }, headers=auth_headers)
        assert resp.status_code == 201

    def test_create_profile_unauthenticated(self, client):
        resp = client.post(self.URL, json={"name": "Test", "phone_number": "9876543210"})
        assert resp.status_code == 401

    def test_create_profile_no_phone(self, client, test_user, auth_headers):
        """M4: Verify creating a profile without a phone number stores NULL (not empty string)."""
        resp = client.post(self.URL, json={"name": "No Phone"}, headers=auth_headers)
        assert resp.status_code == 201
        assert resp.json()["phone_number"] is None


# ===========================================================================
# GET /api/profiles/{profile_id}
# ===========================================================================

class TestGetProfile:

    def test_get_own_profile(self, client, test_user, auth_headers, db):
        pid = _get_profile_id(db, test_user.id)
        resp = client.get(f"/api/profiles/{pid}", headers=auth_headers)
        assert resp.status_code == 200
        assert resp.json()["id"] == pid

    def test_get_nonexistent_profile(self, client, test_user, auth_headers):
        resp = client.get("/api/profiles/99999", headers=auth_headers)
        assert resp.status_code == 403  # no access

    def test_get_unauthenticated(self, client):
        resp = client.get("/api/profiles/1")
        assert resp.status_code == 401


# ===========================================================================
# PUT /api/profiles/{profile_id}
# ===========================================================================

class TestUpdateProfile:

    def test_update_profile_name(self, client, test_user, auth_headers, db):
        pid = _get_profile_id(db, test_user.id)
        resp = client.put(f"/api/profiles/{pid}", json={
            "name": "Updated Name",
            "age": 50,
        }, headers=auth_headers)
        assert resp.status_code == 200
        assert resp.json()["name"] == "Updated Name"
        assert resp.json()["age"] == 50

    def test_update_profile_as_viewer_rejected(self, client, test_user, auth_headers, db):
        """Viewers should not be able to update profiles."""
        viewer = _second_user(db)
        pid = _get_profile_id(db, test_user.id)

        # Grant viewer access
        db.add(models.ProfileAccess(user_id=viewer.id, profile_id=pid, access_level="viewer"))
        db.flush()

        viewer_token = create_access_token(data={"sub": viewer.email})
        viewer_headers = {"Authorization": f"Bearer {viewer_token}"}

        resp = client.put(f"/api/profiles/{pid}", json={"name": "Hacked"}, headers=viewer_headers)
        assert resp.status_code == 403

    def test_update_profile_invalid_phone_rejected(self, client, test_user, auth_headers, db):
        """M4: Verify that providing an invalid phone number returns a 422 error."""
        pid = _get_profile_id(db, test_user.id)
        resp = client.put(f"/api/profiles/{pid}", json={
            "phone_number": "abc",
        }, headers=auth_headers)
        # Validation error from Pydantic schema (ProfileUpdate)
        assert resp.status_code == 422

    def test_clear_profile_phone_number(self, client, test_user, auth_headers, db):
        pid = _get_profile_id(db, test_user.id)
        resp = client.put(f"/api/profiles/{pid}", json={"phone_number": None}, headers=auth_headers)
        assert resp.status_code == 200
        profile = db.query(models.Profile).filter(models.Profile.id == pid).first()
        db.refresh(profile)
        assert profile.phone_number is None


# ===========================================================================
# DELETE /api/profiles/{profile_id}
# ===========================================================================

class TestDeleteProfile:

    def test_delete_profile(self, client, test_user, auth_headers, db):
        # Create a separate profile to delete (don't delete the default one)
        resp = client.post("/api/profiles", json={
            "name": "To Delete",
            "phone_number": "9876543210"
        }, headers=auth_headers)
        assert resp.status_code == 201
        pid = resp.json()["id"]

        del_resp = client.delete(f"/api/profiles/{pid}", headers=auth_headers)
        assert del_resp.status_code == 204

    def test_delete_profile_as_viewer_rejected(self, client, test_user, auth_headers, db):
        viewer = _second_user(db)
        pid = _get_profile_id(db, test_user.id)
        db.add(models.ProfileAccess(user_id=viewer.id, profile_id=pid, access_level="viewer"))
        db.flush()

        viewer_token = create_access_token(data={"sub": viewer.email})
        resp = client.delete(f"/api/profiles/{pid}", headers={"Authorization": f"Bearer {viewer_token}"})
        assert resp.status_code == 403


# ===========================================================================
# POST /api/profiles/{profile_id}/invite
# ===========================================================================

class TestSendInvite:

    @patch("routes_profiles.email_service.send_profile_invite_email")
    def test_send_invite_success(self, mock_email, client, test_user, auth_headers, db):
        invitee = _second_user(db)
        pid = _get_profile_id(db, test_user.id)
        resp = client.post(f"/api/profiles/{pid}/invite", json={
            "email": invitee.email,
            "relationship": "friend",
            "access_level": "editor",
        }, headers=auth_headers)
        assert resp.status_code == 201
        assert "invite_id" in resp.json()

    @patch("routes_profiles.email_service.send_profile_invite_email")
    def test_nonexistent_email_returns_404(self, mock_email, client, test_user, auth_headers, db):
        """Inviting an email not registered in the system must return 404."""
        pid = _get_profile_id(db, test_user.id)
        resp = client.post(f"/api/profiles/{pid}/invite", json={
            "email": "nobody@notregistered.com",
        }, headers=auth_headers)
        assert resp.status_code == 404
        assert "register" in resp.json()["detail"].lower()
        mock_email.assert_not_called()

    @patch("routes_profiles.email_service.send_profile_invite_email")
    def test_cannot_invite_self(self, mock_email, client, test_user, auth_headers, db):
        pid = _get_profile_id(db, test_user.id)
        resp = client.post(f"/api/profiles/{pid}/invite", json={
            "email": TEST_USER_EMAIL,
        }, headers=auth_headers)
        assert resp.status_code == 400
        assert "yourself" in resp.json()["detail"].lower()

    @patch("routes_profiles.email_service.send_profile_invite_email")
    def test_duplicate_invite_rejected(self, mock_email, client, test_user, auth_headers, db):
        invitee = _second_user(db)
        pid = _get_profile_id(db, test_user.id)
        # First invite
        client.post(f"/api/profiles/{pid}/invite", json={
            "email": invitee.email,
        }, headers=auth_headers)
        # Second invite — same email
        resp = client.post(f"/api/profiles/{pid}/invite", json={
            "email": invitee.email,
        }, headers=auth_headers)
        assert resp.status_code == 409


# ===========================================================================
# DELETE /api/profiles/{profile_id}/invites/{invite_id}
# ===========================================================================

class TestCancelInvite:

    @patch("routes_profiles.email_service.send_profile_invite_email")
    def test_cancel_invite(self, mock_email, client, test_user, auth_headers, db):
        invitee = _second_user(db)
        pid = _get_profile_id(db, test_user.id)
        create_resp = client.post(f"/api/profiles/{pid}/invite", json={
            "email": invitee.email,
        }, headers=auth_headers)
        assert create_resp.status_code == 201
        invite_id = create_resp.json()["invite_id"]

        resp = client.delete(f"/api/profiles/{pid}/invites/{invite_id}", headers=auth_headers)
        assert resp.status_code == 204

    def test_cancel_nonexistent_invite(self, client, test_user, auth_headers, db):
        pid = _get_profile_id(db, test_user.id)
        resp = client.delete(f"/api/profiles/{pid}/invites/99999", headers=auth_headers)
        assert resp.status_code == 404


# ===========================================================================
# GET /api/profiles/{profile_id}/access
# ===========================================================================

class TestListAccess:

    def test_list_access_as_owner(self, client, test_user, auth_headers, db):
        pid = _get_profile_id(db, test_user.id)
        resp = client.get(f"/api/profiles/{pid}/access", headers=auth_headers)
        assert resp.status_code == 200
        assert len(resp.json()) >= 1
        assert resp.json()[0]["access_level"] == "owner"


# ===========================================================================
# DELETE /api/profiles/{profile_id}/access/{target_user_id} — revoke access
# ===========================================================================

class TestRevokeAccess:

    def test_revoke_viewer_access(self, client, test_user, auth_headers, db):
        pid = _get_profile_id(db, test_user.id)
        viewer = _second_user(db)
        db.add(models.ProfileAccess(user_id=viewer.id, profile_id=pid, access_level="viewer"))
        db.flush()

        resp = client.delete(f"/api/profiles/{pid}/access/{viewer.id}", headers=auth_headers)
        assert resp.status_code == 204

    def test_cannot_revoke_own_access(self, client, test_user, auth_headers, db):
        pid = _get_profile_id(db, test_user.id)
        resp = client.delete(f"/api/profiles/{pid}/access/{test_user.id}", headers=auth_headers)
        assert resp.status_code == 400
        assert "own owner" in resp.json()["detail"].lower()

    def test_revoke_nonexistent_user(self, client, test_user, auth_headers, db):
        pid = _get_profile_id(db, test_user.id)
        resp = client.delete(f"/api/profiles/{pid}/access/99999", headers=auth_headers)
        assert resp.status_code == 404


# ===========================================================================
# PATCH /api/profiles/{profile_id}/access/{target_user_id} — change level
# ===========================================================================

class TestUpdateAccessLevel:

    def test_change_viewer_to_editor(self, client, test_user, auth_headers, db):
        pid = _get_profile_id(db, test_user.id)
        viewer = _second_user(db)
        db.add(models.ProfileAccess(user_id=viewer.id, profile_id=pid, access_level="viewer"))
        db.flush()

        resp = client.patch(f"/api/profiles/{pid}/access/{viewer.id}", json={
            "access_level": "editor",
        }, headers=auth_headers)
        assert resp.status_code == 200
        assert resp.json()["access_level"] == "editor"

    def test_invalid_access_level(self, client, test_user, auth_headers, db):
        pid = _get_profile_id(db, test_user.id)
        viewer = _second_user(db)
        db.add(models.ProfileAccess(user_id=viewer.id, profile_id=pid, access_level="viewer"))
        db.flush()

        resp = client.patch(f"/api/profiles/{pid}/access/{viewer.id}", json={
            "access_level": "admin",
        }, headers=auth_headers)
        assert resp.status_code == 400

    def test_cannot_change_own_level(self, client, test_user, auth_headers, db):
        pid = _get_profile_id(db, test_user.id)
        resp = client.patch(f"/api/profiles/{pid}/access/{test_user.id}", json={
            "access_level": "viewer",
        }, headers=auth_headers)
        assert resp.status_code == 400


# ===========================================================================
# GET /api/invites/pending
# ===========================================================================

class TestPendingInvites:

    @patch("routes_profiles.email_service.send_profile_invite_email")
    def test_list_pending_invites(self, mock_email, client, test_user, auth_headers, db):
        # Create a second user who sends invite to test_user
        owner = _second_user(db)
        profile = models.Profile(name="Shared Profile", phone_number=normalize_phone("9876543214"))
        db.add(profile)
        db.flush()
        db.add(models.ProfileAccess(user_id=owner.id, profile_id=profile.id, access_level="owner"))
        db.flush()

        # Create invite to test_user
        invite = models.ProfileInvite(
            profile_id=profile.id,
            invited_by_user_id=owner.id,
            invited_email=TEST_USER_EMAIL.lower(),
            status="pending",
            expires_at=datetime.now(timezone.utc) + timedelta(days=7),
        )
        db.add(invite)
        db.flush()

        resp = client.get("/api/invites/pending", headers=auth_headers)
        assert resp.status_code == 200
        invites = resp.json()
        assert len(invites) >= 1

    def test_no_pending_invites(self, client, test_user, auth_headers):
        resp = client.get("/api/invites/pending", headers=auth_headers)
        assert resp.status_code == 200
        assert resp.json() == []


# ===========================================================================
# PATCH /api/invites/{invite_id}
# ===========================================================================

class TestRespondToInvite:

    def test_accept_invite(self, client, test_user, auth_headers, db):
        owner = _second_user(db)
        profile = models.Profile(name="Family Profile", phone_number=normalize_phone("9876543214"))
        db.add(profile)
        db.flush()
        db.add(models.ProfileAccess(user_id=owner.id, profile_id=profile.id, access_level="owner"))

        invite = models.ProfileInvite(
            profile_id=profile.id,
            invited_by_user_id=owner.id,
            invited_email=TEST_USER_EMAIL.lower(),
            access_level="editor",
            status="pending",
            expires_at=datetime.now(timezone.utc) + timedelta(days=7),
        )
        db.add(invite)
        db.flush()
        invite_id = invite.id

        resp = client.patch(f"/api/invites/{invite_id}", json={"action": "accept"}, headers=auth_headers)
        assert resp.status_code == 200
        assert "accepted" in resp.json()["message"].lower()

    def test_reject_invite(self, client, test_user, auth_headers, db):
        owner = _second_user(db)
        profile = models.Profile(name="Rejected Profile", phone_number=normalize_phone("9876543214"))
        db.add(profile)
        db.flush()
        db.add(models.ProfileAccess(user_id=owner.id, profile_id=profile.id, access_level="owner"))

        invite = models.ProfileInvite(
            profile_id=profile.id,
            invited_by_user_id=owner.id,
            invited_email=TEST_USER_EMAIL.lower(),
            status="pending",
            expires_at=datetime.now(timezone.utc) + timedelta(days=7),
        )
        db.add(invite)
        db.flush()

        resp = client.patch(f"/api/invites/{invite.id}", json={"action": "reject"}, headers=auth_headers)
        assert resp.status_code == 200
        assert "rejected" in resp.json()["message"].lower()

    def test_expired_invite(self, client, test_user, auth_headers, db):
        owner = _second_user(db)
        profile = models.Profile(name="Expired Profile", phone_number=normalize_phone("9876543214"))
        db.add(profile)
        db.flush()
        db.add(models.ProfileAccess(user_id=owner.id, profile_id=profile.id, access_level="owner"))

        invite = models.ProfileInvite(
            profile_id=profile.id,
            invited_by_user_id=owner.id,
            invited_email=TEST_USER_EMAIL.lower(),
            status="pending",
            expires_at=datetime.now(timezone.utc) - timedelta(days=1),
        )
        db.add(invite)
        db.flush()

        resp = client.patch(f"/api/invites/{invite.id}", json={"action": "accept"}, headers=auth_headers)
        assert resp.status_code == 410


# ===========================================================================
# PUT /api/auth/me — user profile update
# ===========================================================================

class TestUserProfileUpdate:
    URL = "/api/auth/me"

    def test_update_name(self, client, test_user, auth_headers):
        resp = client.put(self.URL, json={"full_name": "New Name"}, headers=auth_headers)
        assert resp.status_code == 200
        assert resp.json()["full_name"] == "New Name"

    def test_change_password(self, client, test_user, auth_headers):
        resp = client.put(self.URL, json={
            "current_password": TEST_USER_PASSWORD,
            "new_password": "Changed@1234",
        }, headers=auth_headers)
        assert resp.status_code == 200

    def test_change_password_wrong_current(self, client, test_user, auth_headers):
        resp = client.put(self.URL, json={
            "current_password": "Wrong@Pass1",
            "new_password": "Changed@1234",
        }, headers=auth_headers)
        assert resp.status_code == 401

    def test_change_password_no_current(self, client, test_user, auth_headers):
        resp = client.put(self.URL, json={
            "new_password": "Changed@1234",
        }, headers=auth_headers)
        assert resp.status_code == 400

    def test_update_phone_stores_e164(self, client, test_user, auth_headers, db):
        resp = client.put(self.URL, json={"phone_number": "9876543210"}, headers=auth_headers)
        assert resp.status_code == 200
        db.refresh(test_user)
        assert test_user.phone_number == "+919876543210"

    def test_update_phone_already_e164_unchanged(self, client, test_user, auth_headers, db):
        resp = client.put(self.URL, json={"phone_number": "+919876543210"}, headers=auth_headers)
        assert resp.status_code == 200
        db.refresh(test_user)
        assert test_user.phone_number == "+919876543210"


# ===========================================================================
# POST /api/auth/phone-otp/verify — OTP login/registration
# (M2: integration test for the new-user branch so WhatsApp inbound matching
# by phone does not silently break if the Profile constructor changes.)
# ===========================================================================

class TestPhoneOTPVerifyNewUser:
    URL = "/api/auth/phone-otp/verify"

    def test_new_user_gets_profile_with_normalized_phone(self, client, db):
        from datetime import datetime, timedelta

        normalized = "+919999111122"
        # Seed a valid, unused OTP for the normalized phone
        otp = models.PhoneOTP(
            phone_number=normalized,
            otp="123456",
            expires_at=datetime.utcnow() + timedelta(minutes=5),
            is_used=False,
        )
        db.add(otp)
        db.commit()

        resp = client.post(
            self.URL,
            json={"phone_number": "9999111122", "otp": "123456", "full_name": "Phone User"},
        )
        assert resp.status_code == 200
        assert resp.json()["access_token"]  # login succeeded

        # User row stores E.164 — inbound matching relies on this
        from encryption_service import hash_phone
        created_user = db.query(models.User).filter(models.User.phone_hash == hash_phone(normalized)).first()
        assert created_user is not None
        assert created_user.phone_number == normalized

        # Default Profile created with matching E.164 phone — WhatsApp inbound
        # photo routing matches on this field, so the assignment must not
        # silently disappear in a future refactor.
        access = (
            db.query(models.ProfileAccess)
            .filter(models.ProfileAccess.user_id == created_user.id)
            .first()
        )
        assert access is not None
        profile = db.query(models.Profile).filter(models.Profile.id == access.profile_id).first()
        assert profile is not None
        assert profile.phone_number == normalized
