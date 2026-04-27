from pydantic_settings import BaseSettings
from pydantic import Field
from typing import Optional, List, ClassVar


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
    CORS_ORIGINS: list = [
        "http://localhost:3000",
        "http://localhost:8080",
        "https://app.swasth.health",
        "https://swasth.health",
        "https://www.swasth.health",
    ]

    # Chat quota — configurable rate limiting
    CHAT_QUOTA_LIMIT: int = 5              # max questions per period
    CHAT_QUOTA_PERIOD: str = "daily"       # "daily", "weekly", "monthly"
    CHAT_SUMMARY_INTERVAL: int = 5         # summarize conversation every N messages

    # Encryption — 64-char hex string = 32 bytes for AES-256-GCM
    # Generate with: python -c "import secrets; print(secrets.token_hex(32))"
    # ENCRYPTION_KEY      — SPDI (glucose, BP, SpO2, weight, notes)
    # PII_ENCRYPTION_KEY  — PII (name, email, phone) + HMAC blind indexes + OTP hashing
    # Kept separate so a compromise of one key does not expose the other domain.
    ENCRYPTION_KEY: Optional[str] = None
    PII_ENCRYPTION_KEY: Optional[str] = None

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
    TWILIO_REPORT_CONTENT_SID: Optional[str] = None  # Approved WhatsApp template SID for weekly report delivery

    # Critical Alert Dispatch (D7)
    CRITICAL_ALERT_DEDUPE_MINUTES: int = 30  # Suppress repeat alerts to same profile within window
    CRITICAL_ALERTS_ENABLED: bool = True     # Kill switch for the whole feature

    # Operational Monitoring & Alerting
    OPS_ALERT_EMAIL: str = "support@swasth.health"   # destination for all tiered ops alerts
    OPS_ALERTS_ENABLED: bool = True                   # master kill switch
    OPS_P0_ALERTS_ENABLED: bool = True                # P0: immediate (API down, DB down, all AI failed)
    OPS_P1_ALERTS_ENABLED: bool = False               # P1: disabled at launch — enable one-by-one as team matures
    OPS_P2_ALERTS_ENABLED: bool = True                # P2: weekly digest (Sundays 08:00 IST)
    OPS_P0_COOLDOWN_MINUTES: int = 15                 # dedup window — same alert_key suppressed within window
    OPS_P1_COOLDOWN_MINUTES: int = 60
    OPS_P2_COOLDOWN_HOURS: int = 168                  # 7 days — weekly digest
    # P0 thresholds
    OPS_CONCURRENT_P0_THRESHOLD: int = 40
    OPS_MEMORY_P0_THRESHOLD: float = 0.90             # 90% RAM usage
    OPS_CRITICAL_ALERT_FAIL_P0_THRESHOLD: float = 0.50  # >50% critical alerts failing
    # P1 thresholds (off by default)
    OPS_ERROR_RATE_P1_THRESHOLD: int = 10             # 500s per 5-min window
    OPS_AI_FALLBACK_P1_THRESHOLD: float = 0.30        # 30% fallback rate
    OPS_CONCURRENT_P1_THRESHOLD: int = 25
    OPS_MEMORY_P1_THRESHOLD: float = 0.80             # 80% RAM usage
    OPS_DISK_P1_THRESHOLD: float = 0.85               # 85% disk usage
    OPS_AI_KEY_QUOTA_P1_THRESHOLD: float = 0.80       # 80% of daily quota used
    # P2 thresholds (weekly digest)
    OPS_PENDING_DOCTORS_P2_THRESHOLD: int = 5
    OPS_NO_READING_DAYS_THRESHOLD: int = 7            # patients with no reading in N days

    # WhatsApp Inbound Webhook
    TWILIO_WEBHOOK_VALIDATE: bool = False    # Set True in production to verify Twilio HMAC signatures
    WHATSAPP_SESSION_TTL_MINUTES: int = 10   # How long to wait for profile selection reply

    # File upload limits
    MAX_UPLOAD_SIZE_BYTES: int = 10_485_760  # 10 MB max for food photos
    ALLOWED_IMAGE_MIME_TYPES: List[str] = Field(default_factory=lambda: ["image/jpeg", "image/png", "image/webp"])

    class Config:
        env_file = ".env"
        extra = "ignore"  # Prevent prod deploy failures when a new env var is added on the server
                          # before the matching Settings field lands in code (the failure mode that
                          # took down prod on 2026-04-23 when TWILIO_REPORT_CONTENT_SID was set on
                          # the server but not declared here).


settings = Settings()
