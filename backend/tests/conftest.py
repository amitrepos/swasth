"""Shared pytest fixtures for the Swasth backend test suite.

Uses an in-memory SQLite database so tests never touch the real PostgreSQL
instance.
"""
import sys, os

# Ensure the backend package root is importable
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker
from fastapi.testclient import TestClient

from database import Base, get_db
from auth import get_password_hash, create_access_token

# ---------------------------------------------------------------------------
# In-memory SQLite engine (per-test-session)
# ---------------------------------------------------------------------------

SQLALCHEMY_TEST_URL = "sqlite:///file::memory:?cache=shared&uri=true"

engine = create_engine(
    SQLALCHEMY_TEST_URL,
    connect_args={"check_same_thread": False},
)

# SQLite does not enforce FK constraints by default — enable them.
@event.listens_for(engine, "connect")
def _set_sqlite_pragma(dbapi_conn, _connection_record):
    cursor = dbapi_conn.cursor()
    cursor.execute("PRAGMA foreign_keys=ON")
    cursor.close()

TestSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(scope="session", autouse=True)
def _create_tables():
    """Create all tables once for the entire test session."""
    import models  # noqa: F401 — ensures all models are registered on Base

    # SQLite doesn't support PostgreSQL ARRAY — swap to JSON for tests
    from sqlalchemy import JSON
    for table in Base.metadata.tables.values():
        for col in table.columns:
            if hasattr(col.type, '__class__') and col.type.__class__.__name__ == 'ARRAY':
                col.type = JSON()

    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture()
def db():
    """Provide a clean transactional DB session per test.

    Each test runs inside a transaction that is rolled back at the end,
    so tests are fully isolated.
    """
    connection = engine.connect()
    transaction = connection.begin()
    session = TestSessionLocal(bind=connection)

    yield session

    session.close()
    transaction.rollback()
    connection.close()


@pytest.fixture()
def client(db):
    """FastAPI TestClient wired to the per-test SQLite session."""
    from main import app

    def _override_get_db():
        try:
            yield db
        finally:
            pass

    app.dependency_overrides[get_db] = _override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# Convenience: pre-created test user + auth token
# ---------------------------------------------------------------------------

TEST_USER_EMAIL = "test@swasth.app"
TEST_USER_PASSWORD = "Test@1234"
TEST_USER_NAME = "Test User"
TEST_USER_PHONE = "9876543210"


@pytest.fixture()
def test_user(db):
    """Insert a User row and return the ORM instance."""
    import models

    user = models.User(
        email=TEST_USER_EMAIL,
        password_hash=get_password_hash(TEST_USER_PASSWORD),
        full_name=TEST_USER_NAME,
        phone_number=TEST_USER_PHONE,
    )
    db.add(user)
    db.flush()

    # Also create a default profile + owner access (mirrors register flow)
    profile = models.Profile(name="My Health")
    db.add(profile)
    db.flush()

    access = models.ProfileAccess(
        user_id=user.id,
        profile_id=profile.id,
        access_level="owner",
    )
    db.add(access)
    db.flush()

    return user


@pytest.fixture()
def auth_token(test_user) -> str:
    """Return a valid JWT bearer token for ``test_user``."""
    return create_access_token(data={"sub": test_user.email})


@pytest.fixture()
def auth_headers(auth_token) -> dict:
    """Return HTTP headers dict with Authorization bearer token."""
    return {"Authorization": f"Bearer {auth_token}"}
