"""Shared pytest fixtures for the Swasth backend test suite.

Uses an in-memory SQLite database so tests never touch the real PostgreSQL
instance.  We monkey-patch `database.engine` BEFORE importing `main` so that
`Base.metadata.create_all(bind=engine)` in main.py targets SQLite, not PG.
"""
import sys, os
import secrets

# Ensure the backend package root is importable
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

# Disable rate limiting during tests
os.environ["TESTING"] = "true"

# Provide deterministic encryption keys for the test session so every test
# that hits the PII model properties has working encrypt/decrypt. Only
# populated if the env doesn't already set them — CI/dev runs that want a
# specific value can override via the shell environment. Without this the
# pre-push hook runs pytest without PII_ENCRYPTION_KEY and the property
# setters raise ValueError across the whole suite.
os.environ.setdefault("ENCRYPTION_KEY", secrets.token_hex(32))
os.environ.setdefault("PII_ENCRYPTION_KEY", secrets.token_hex(32))

import pytest
from sqlalchemy import create_engine, event, JSON
from sqlalchemy.orm import sessionmaker
from fastapi.testclient import TestClient

# ---------------------------------------------------------------------------
# In-memory SQLite engine — must be set up BEFORE importing main/database
# ---------------------------------------------------------------------------

SQLALCHEMY_TEST_URL = "sqlite:///file::memory:?cache=shared&uri=true"

_test_engine = create_engine(
    SQLALCHEMY_TEST_URL,
    connect_args={"check_same_thread": False},
)

@event.listens_for(_test_engine, "connect")
def _set_sqlite_pragma(dbapi_conn, _connection_record):
    cursor = dbapi_conn.cursor()
    cursor.execute("PRAGMA foreign_keys=ON")
    cursor.close()

# Monkey-patch database module BEFORE main.py is imported
import database
database.engine = _test_engine
database.SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=_test_engine)

# Now fix ARRAY and Enum columns for SQLite compatibility
import models  # noqa: F401
from sqlalchemy import String as SAString
for table in database.Base.metadata.tables.values():
    for col in table.columns:
        if col.type.__class__.__name__ == 'ARRAY':
            col.type = JSON()
        elif col.type.__class__.__name__ == 'Enum':
            col.type = SAString()

# Now safe to import — main.py's create_all will use SQLite
from database import Base, get_db
from auth import get_password_hash, create_access_token
from utils.phone import normalize_phone

TestSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=_test_engine)

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(scope="session", autouse=True)
def _create_tables():
    """Create all tables once for the entire test session."""
    Base.metadata.create_all(bind=_test_engine)
    yield
    Base.metadata.drop_all(bind=_test_engine)


@pytest.fixture()
def db():
    """Provide a clean transactional DB session per test."""
    connection = _test_engine.connect()
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
        phone_number=normalize_phone(TEST_USER_PHONE),
    )
    db.add(user)
    db.flush()

    # Also create a default profile + owner access (mirrors register flow)
    profile = models.Profile(name="My Health", phone_number=normalize_phone(TEST_USER_PHONE))
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
