from fastapi import FastAPI, Depends, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from starlette.middleware.httpsredirect import HTTPSRedirectMiddleware
from database import engine, Base
from config import settings
import models
import routes
import routes_health
import routes_profiles
import routes_chat
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Create database tables
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Swasth Health App API",
    description="Backend API for Swasth Health Application",
    version="1.0.0"
)

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


if __name__ == "__main__":
    import uvicorn
    # Get host and port from environment variables
    host = os.getenv("SERVER_HOST", "0.0.0.0")
    port = int(os.getenv("SERVER_PORT", 8000))
    
    print(f"\n{'='*50}")
    print(f"Swasth Health App API Server")
    print(f"{'='*50}")
    print(f"Host: {host}")
    print(f"Port: {port}")
    print(f"Local URL: http://localhost:{port}")
    print(f"Mobile URL: http://{host}:{port}")
    print(f"API Docs: http://localhost:{port}/docs")
    print(f"{'='*50}\n")
    
    uvicorn.run(app, host=host, port=port)
