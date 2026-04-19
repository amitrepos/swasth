"""Tests for global exception handlers registered in main.py.

These guard the contract that unhandled exceptions in routes are
translated into sanitized JSON responses — no stack traces, no SQL
constraint names, no PHI leaked to the client.
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from fastapi import APIRouter, HTTPException
from fastapi.testclient import TestClient
from sqlalchemy.exc import IntegrityError, OperationalError

from database import get_db


@pytest.fixture()
def probe_routes(db):
    """Attach a set of routes that deliberately raise each exception type
    we care about, so we can assert the handler's response shape without
    having to reproduce a real DB fault in the test.

    Uses a dedicated TestClient with raise_server_exceptions=False because
    the default re-raises unhandled exceptions into the test function —
    we need to observe the actual HTTP response the handler produced."""
    from main import app

    router = APIRouter()

    @router.get("/_probe/unhandled")
    def _unhandled():
        raise RuntimeError("kaboom — this should never reach the client")

    @router.get("/_probe/integrity")
    def _integrity():
        raise IntegrityError(
            "UNIQUE constraint failed: user.email",
            params={"email": "patient@example.com"},
            orig=Exception("duplicate key value (email)=(patient@example.com)"),
        )

    @router.get("/_probe/operational")
    def _operational():
        raise OperationalError("connection refused", params={}, orig=Exception())

    @router.get("/_probe/http")
    def _http():
        # HTTPException must still flow through untouched — it encodes an
        # intentional client-facing status.
        raise HTTPException(status_code=418, detail="teapot")

    app.include_router(router)

    def _override_get_db():
        try:
            yield db
        finally:
            pass

    app.dependency_overrides[get_db] = _override_get_db
    client = TestClient(app, raise_server_exceptions=False)
    with client:
        yield client
    # Clean up so probe routes don't leak into the next test.
    app.routes[:] = [r for r in app.routes if not getattr(r, "path", "").startswith("/_probe/")]
    app.dependency_overrides.clear()


class TestUnhandledException:
    def test_returns_generic_500(self, probe_routes):
        resp = probe_routes.get("/_probe/unhandled")
        assert resp.status_code == 500
        assert resp.json() == {"detail": "An unexpected error occurred. Please try again."}

    def test_does_not_leak_exception_message(self, probe_routes):
        resp = probe_routes.get("/_probe/unhandled")
        body = resp.text
        # None of these internal strings should reach the client
        assert "kaboom" not in body
        assert "RuntimeError" not in body
        assert "Traceback" not in body


class TestIntegrityError:
    def test_returns_409(self, probe_routes):
        resp = probe_routes.get("/_probe/integrity")
        assert resp.status_code == 409

    def test_does_not_leak_column_or_phi(self, probe_routes):
        resp = probe_routes.get("/_probe/integrity")
        body = resp.text
        # Must not echo constraint name, column, or PHI email from the exception
        assert "patient@example.com" not in body
        assert "UNIQUE constraint" not in body
        assert "user.email" not in body
        assert "duplicate key" not in body


class TestSQLAlchemyError:
    def test_returns_503(self, probe_routes):
        resp = probe_routes.get("/_probe/operational")
        assert resp.status_code == 503

    def test_does_not_leak_connection_detail(self, probe_routes):
        resp = probe_routes.get("/_probe/operational")
        body = resp.text
        assert "connection refused" not in body
        assert "OperationalError" not in body


class TestHTTPExceptionStillWorks:
    """Critical: adding a catch-all Exception handler must not break
    routes that intentionally raise HTTPException with a specific status."""

    def test_http_exception_preserves_status_and_detail(self, probe_routes):
        resp = probe_routes.get("/_probe/http")
        assert resp.status_code == 418
        assert resp.json()["detail"] == "teapot"
