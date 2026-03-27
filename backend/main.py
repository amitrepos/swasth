from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from database import engine, Base
import models
import routes
import routes_health
import routes_profiles
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

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify exact origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


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
