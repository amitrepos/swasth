from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    PROJECT_NAME: str = "Swasth Health App API"
    VERSION: str = "1.0.0"
    
    # Network settings
    SERVER_HOST: str = "0.0.0.0"
    SERVER_PORT: int = 8000
    
    # Database settings
    DATABASE_URL: str = "postgresql://postgres:password@localhost:5432/swasth_db"
    
    # Security settings
    SECRET_KEY: str = "your-secret-key-change-this-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    
    # Brevo SMTP settings
    BREVO_SMTP_SERVER: str = "smtp-relay.brevo.com"
    BREVO_SMTP_PORT: int = 587
    BREVO_SENDER_EMAIL: str = "your-brevo-email@example.com"
    BREVO_SMTP_LOGIN: str
    BREVO_SMTP_PASSWORD: str = "your-brevo-smtp-password"
    BREVO_SENDER_NAME: str = "Swasth Health App"
    
    # OTP settings
    OTP_EXPIRE_MINUTES: int = 10

    # Google Gemini AI
    GEMINI_API_KEY: Optional[str] = None
    
    # CORS settings
    CORS_ORIGINS: list = ["http://localhost:3000", "http://localhost:8080"]
    
    class Config:
        env_file = ".env"


settings = Settings()
