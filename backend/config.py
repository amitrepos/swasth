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
    BREVO_SMTP_LOGIN: str = ""
    BREVO_SMTP_PASSWORD: str = "your-brevo-smtp-password"
    BREVO_SENDER_NAME: str = "Swasth Health App"
    
    # OTP settings
    OTP_EXPIRE_MINUTES: int = 10

    # Google Gemini AI (comma-separated for key rotation)
    GEMINI_API_KEY: Optional[str] = None
    GEMINI_API_KEYS: Optional[str] = None  # e.g. "key1,key2,key3"

    # DeepSeek AI (fallback) — sign up at platform.deepseek.com
    DEEPSEEK_API_KEY: Optional[str] = None

    # Groq AI (kept for future use, not used for vision — Gemini is more accurate)
    GROQ_API_KEY: Optional[str] = None
    
    # CORS settings
    CORS_ORIGINS: list = ["http://localhost:3000", "http://localhost:8080"]

    # Chat quota — configurable rate limiting
    CHAT_QUOTA_LIMIT: int = 5              # max questions per period
    CHAT_QUOTA_PERIOD: str = "daily"       # "daily", "weekly", "monthly"
    CHAT_SUMMARY_INTERVAL: int = 5         # summarize conversation every N messages

    # Encryption — 64-char hex string = 32 bytes for AES-256-GCM
    # Generate with: python -c "import secrets; print(secrets.token_hex(32))"
    ENCRYPTION_KEY: Optional[str] = None

    # HTTPS — enable in production behind TLS termination
    REQUIRE_HTTPS: bool = False
    
    # WhatsApp Business API
    WA_PHONE_NUMBER_ID: Optional[str] = None
    WA_ACCESS_TOKEN: Optional[str] = None
    WA_VERIFY_TOKEN: Optional[str] = None
    
    # Twilio Messaging
    TWILIO_ACCOUNT_SID: Optional[str] = None
    TWILIO_AUTH_TOKEN: Optional[str] = None
    TWILIO_WHATSAPP_NUMBER: Optional[str] = None  # e.g. "whatsapp:+14155238886"
    TWILIO_SMS_NUMBER: Optional[str] = None  # e.g. "+14155238886" — SMS disabled until set

    # Critical Alert Dispatch (D7)
    CRITICAL_ALERT_DEDUPE_MINUTES: int = 30  # Suppress repeat alerts to same profile within window
    CRITICAL_ALERTS_ENABLED: bool = True     # Kill switch for the whole feature

    # WhatsApp Inbound Webhook
    TWILIO_WEBHOOK_VALIDATE: bool = False    # Set True in production to verify Twilio HMAC signatures
    WHATSAPP_SESSION_TTL_MINUTES: int = 10   # How long to wait for profile selection reply

    class Config:
        env_file = ".env"


settings = Settings()
