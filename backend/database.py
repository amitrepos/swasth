from sqlalchemy import create_engine, event, text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from config import settings

_is_sqlite = settings.DATABASE_URL.startswith("sqlite")

engine = create_engine(settings.DATABASE_URL)

if not _is_sqlite:
    @event.listens_for(engine, "connect")
    def _set_utc(dbapi_conn, _record):
        cursor = dbapi_conn.cursor()
        cursor.execute("SET timezone = 'UTC'")
        cursor.close()

# Create SessionLocal class
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Create Base class
Base = declarative_base()


# Dependency to get DB session
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
