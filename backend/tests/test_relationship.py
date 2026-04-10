"""Tests for relationship field on profile sharing."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from tests.conftest import TEST_USER_EMAIL, TEST_USER_PASSWORD


class TestInviteWithRelationship:
    """Test that relationship is captured on invite and carried to access."""

    def _register_second_user(self, client):
        """Create a second user to be invited."""
        resp = client.post("/api/auth/register", json={
            "email": "viewer@test.com",
            "password": "Test@1234",
            "confirm_password": "Test@1234",
            "full_name": "Viewer User",
            "phone_number": "9876543211",
        })
        return resp

    def test_invite_includes_relationship(self, client, test_user, auth_headers):
        """Invite should store the relationship field."""
        self._register_second_user(client)

        # Get profile ID
        profiles = client.get("/api/profiles", headers=auth_headers).json()
        pid = profiles[0]["id"]

        # Send invite with relationship
        resp = client.post(
            f"/api/profiles/{pid}/invite",
            json={"email": "viewer@test.com", "relationship": "father"},
            headers=auth_headers,
        )
        assert resp.status_code == 201

    def test_invite_rejects_invalid_relationship(self, client, test_user, auth_headers):
        """Invalid relationship value should be rejected."""
        profiles = client.get("/api/profiles", headers=auth_headers).json()
        pid = profiles[0]["id"]

        resp = client.post(
            f"/api/profiles/{pid}/invite",
            json={"email": "someone@test.com", "relationship": "invalid_value"},
            headers=auth_headers,
        )
        assert resp.status_code == 422  # validation error

    def test_accept_copies_relationship_to_access(self, client, test_user, auth_headers):
        """When invite is accepted, relationship should be on ProfileAccess."""
        self._register_second_user(client)

        # Get profile ID
        profiles = client.get("/api/profiles", headers=auth_headers).json()
        pid = profiles[0]["id"]

        # Send invite
        resp = client.post(
            f"/api/profiles/{pid}/invite",
            json={"email": "viewer@test.com", "relationship": "son"},
            headers=auth_headers,
        )
        invite_id = resp.json()["invite_id"]

        # Login as the viewer
        login = client.post("/api/auth/login", json={
            "email": "viewer@test.com",
            "password": "Test@1234",
        })
        viewer_token = login.json()["access_token"]
        viewer_headers = {"Authorization": f"Bearer {viewer_token}"}

        # Accept invite
        resp = client.patch(
            f"/api/invites/{invite_id}",
            json={"action": "accept"},
            headers=viewer_headers,
        )
        assert resp.status_code == 200

        # Check access list includes relationship
        resp = client.get(f"/api/profiles/{pid}/access", headers=auth_headers)
        accesses = resp.json()
        viewer_access = [a for a in accesses if a["email"] == "viewer@test.com"]
        assert len(viewer_access) == 1
        assert viewer_access[0]["relationship"] == "son"


class TestProfileListRelationship:
    """Test that /profiles endpoint returns relationship for shared profiles."""

    def test_profiles_include_relationship_for_viewers(self, client, test_user, auth_headers):
        """Shared profiles should show relationship in the list."""
        # Register viewer
        client.post("/api/auth/register", json={
            "email": "family@test.com",
            "password": "Test@1234",
            "confirm_password": "Test@1234",
            "full_name": "Family Member",
            "phone_number": "9876543212",
        })

        # Get owner's profile
        profiles = client.get("/api/profiles", headers=auth_headers).json()
        pid = profiles[0]["id"]

        # Invite with relationship
        resp = client.post(
            f"/api/profiles/{pid}/invite",
            json={"email": "family@test.com", "relationship": "daughter"},
            headers=auth_headers,
        )
        invite_id = resp.json()["invite_id"]

        # Login as family member and accept
        login = client.post("/api/auth/login", json={
            "email": "family@test.com",
            "password": "Test@1234",
        })
        family_headers = {"Authorization": f"Bearer {login.json()['access_token']}"}

        client.patch(
            f"/api/invites/{invite_id}",
            json={"action": "accept"},
            headers=family_headers,
        )

        # Check family member's profile list
        profiles = client.get("/api/profiles", headers=family_headers).json()
        shared = [p for p in profiles if p["access_level"] == "viewer"]
        assert len(shared) >= 1
        assert shared[0]["relationship"] == "daughter"

    def test_owner_profiles_have_null_relationship(self, client, test_user, auth_headers):
        """Owner's own profiles should have relationship=null."""
        profiles = client.get("/api/profiles", headers=auth_headers).json()
        owned = [p for p in profiles if p["access_level"] == "owner"]
        assert len(owned) >= 1
        assert owned[0]["relationship"] is None
