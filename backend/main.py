import logging
import time
from fastapi import FastAPI, Depends, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, Response
from starlette.exceptions import HTTPException as StarletteHTTPException
from starlette.middleware.httpsredirect import HTTPSRedirectMiddleware
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from database import engine, Base
from config import settings
import ops_metrics  # must import before Base.metadata.create_all so middleware attaches first
import models
import routes_whatsapp
import routes
import routes_health
import routes_profiles
import routes_chat
import routes_admin
import routes_meals
import routes_doctor
import os
from dotenv import load_dotenv
from scheduler import start_scheduler, stop_scheduler

# Load environment variables
load_dotenv()

# ---------------------------------------------------------------------------
# Structured logging — used by global exception handlers below and by any
# service that needs to surface an error without returning it to the user.
# Level defaults to INFO; set LOG_LEVEL=DEBUG in .env for deeper traces.
# ---------------------------------------------------------------------------
_log_level = os.getenv("LOG_LEVEL", "INFO").upper()
logging.basicConfig(
    level=getattr(logging, _log_level, logging.INFO),
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
logger = logging.getLogger("swasth")

# Create database tables
Base.metadata.create_all(bind=engine)

# ---------------------------------------------------------------------------
# Rate limiter — shared instance used by route files via app.state.limiter
# ---------------------------------------------------------------------------
_rate_limit_enabled = os.getenv("TESTING", "").lower() != "true"
limiter = Limiter(key_func=get_remote_address, enabled=_rate_limit_enabled)

app = FastAPI(
    title="Swasth Health App API",
    description="Backend API for Swasth Health Application",
    version="1.0.0"
)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)


# ---------------------------------------------------------------------------
# Global exception handlers
# ---------------------------------------------------------------------------
# These catch anything a route didn't handle and return a sanitized response
# to the client while logging the full trace internally. Without these,
# FastAPI's default behaviour would leak stack traces and SQL constraint
# names (including PHI like email addresses in IntegrityError messages) to
# the frontend. Ordered most-specific-first so IntegrityError wins over
# the generic SQLAlchemyError handler.
# ---------------------------------------------------------------------------

@app.exception_handler(IntegrityError)
async def _integrity_error_handler(request: Request, exc: IntegrityError):
    # Unique violation, FK violation, NOT NULL violation, etc. The driver
    # error message typically includes the offending value (e.g. email),
    # so we must not echo it to the client.
    logger.warning(
        "integrity_error path=%s method=%s",
        request.url.path,
        request.method,
        exc_info=True,
    )
    return JSONResponse(
        status_code=409,
        content={"detail": "This record already exists or conflicts with existing data."},
    )


@app.exception_handler(SQLAlchemyError)
async def _sqlalchemy_error_handler(request: Request, exc: SQLAlchemyError):
    # Connection drops, timeouts, data-type mismatches, etc. These usually
    # mean the database is unhealthy; 503 is honest about that to clients.
    logger.error(
        "db_error path=%s method=%s",
        request.url.path,
        request.method,
        exc_info=True,
    )
    return JSONResponse(
        status_code=503,
        content={"detail": "The service is temporarily unavailable. Please try again shortly."},
    )


@app.exception_handler(Exception)
async def _unhandled_exception_handler(request: Request, exc: Exception):
    # Catch-all for anything a route didn't translate into an HTTPException.
    # Logs with full trace for operators; returns a generic 500 to the user.
    #
    # Defensive: if an HTTPException reaches here (shouldn't, since Starlette
    # handles those via its own middleware), preserve its status and detail
    # instead of rewriting it to a 500. Otherwise `raise HTTPException(404)`
    # in a route would silently become a 500 with a misleading detail.
    if isinstance(exc, (HTTPException, StarletteHTTPException)):
        return JSONResponse(
            status_code=exc.status_code,
            content={"detail": exc.detail},
            headers=getattr(exc, "headers", None),
        )
    logger.error(
        "unhandled path=%s method=%s",
        request.url.path,
        request.method,
        exc_info=True,
    )
    ops_metrics.record_request(request.url.path, 0, 500)
    return JSONResponse(
        status_code=500,
        content={"detail": "An unexpected error occurred. Please try again."},
    )

@app.on_event("startup")
async def startup_event():
    start_scheduler()

@app.on_event("shutdown")
async def shutdown_event():
    stop_scheduler()

# ---------------------------------------------------------------------------
# HTTPS redirect (enable in production via REQUIRE_HTTPS=true in .env)
# ---------------------------------------------------------------------------
if settings.REQUIRE_HTTPS:
    app.add_middleware(HTTPSRedirectMiddleware)

# ---------------------------------------------------------------------------
# CORS — restricted to configured origins
# In dev (REQUIRE_HTTPS=False), also allow any localhost port for Flutter web
# ---------------------------------------------------------------------------
_cors_origins = list(settings.CORS_ORIGINS)
if not settings.REQUIRE_HTTPS:
    _cors_origins.append("http://localhost:*")

app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins,
    allow_origin_regex=r"^http://localhost:\d+$" if not settings.REQUIRE_HTTPS else None,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)


# ---------------------------------------------------------------------------
# Ops telemetry middleware — measures per-request latency + tracks concurrent count
# Must run AFTER security headers so latency includes the full request cycle.
# ---------------------------------------------------------------------------
@app.middleware("http")
async def ops_telemetry(request: Request, call_next):
    ops_metrics.increment_concurrent()
    t_start = time.perf_counter()
    try:
        response: Response = await call_next(request)
        latency_ms = int((time.perf_counter() - t_start) * 1000)
        ops_metrics.record_request(request.url.path, latency_ms, response.status_code)
        return response
    finally:
        ops_metrics.decrement_concurrent()


# ---------------------------------------------------------------------------
# Security headers
# ---------------------------------------------------------------------------
@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    response: Response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    if settings.REQUIRE_HTTPS:
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    return response


@app.get("/")
def read_root():
    return {"message": "Welcome to Swasth Health App API"}


@app.get("/health")
def health_check():
    return {"status": "healthy"}


# Include authentication routes
app.include_router(routes.router, prefix="/api/auth", tags=["Authentication"])

# Include health readings routes
app.include_router(routes_health.router, prefix="/api", tags=["Health Readings"])

# Include profile routes
app.include_router(routes_profiles.router, prefix="/api", tags=["Profiles"])

# Include chat routes
app.include_router(routes_chat.router, prefix="/api", tags=["Chat"])

# Include admin routes
app.include_router(routes_admin.router, prefix="/api", tags=["Admin"])
app.include_router(routes_meals.router, prefix="/api", tags=["Meals"])

# Include doctor portal routes
app.include_router(routes_doctor.router, prefix="/api/doctor", tags=["Doctor Portal"])

# Include WhatsApp inbound webhook (no auth — Twilio HMAC validated internally)
app.include_router(routes_whatsapp.router, prefix="/api", tags=["WhatsApp Inbound"])


if __name__ == "__main__":
    import uvicorn
    # Get host and port from environment variables
    host = os.getenv("SERVER_HOST", "0.0.0.0")
    port = int(os.getenv("SERVER_PORT", 8000))

    logger.info(
        "starting swasth api host=%s port=%s docs=http://localhost:%s/docs",
        host, port, port,
    )

    uvicorn.run(app, host=host, port=port)
