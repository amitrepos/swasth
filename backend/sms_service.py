"""Twilio SMS service — currently stubbed pending SMS sender number.

The `send_critical_alert_sms` entrypoint is wired into `alert_service.dispatch_critical_alert`
so the full fanout pipeline is ready. When `settings.TWILIO_SMS_NUMBER` is set and
the Twilio account has SMS capabilities, SMS dispatch will activate without any
code changes — just drop the number into `backend/.env`.
"""
from typing import Optional

from twilio.rest import Client

from config import settings
import logging

logger = logging.getLogger(__name__)

class TwilioSmsService:
    """Service for sending SMS messages via Twilio.

    Disabled-by-default stub — returns False (skipped) when
    `TWILIO_SMS_NUMBER` is not configured. Once the sender number
    is added to env, SMS will activate automatically.
    """

    def __init__(self):
        self.account_sid = settings.TWILIO_ACCOUNT_SID
        self.auth_token = settings.TWILIO_AUTH_TOKEN
        self.from_number = settings.TWILIO_SMS_NUMBER
        self._client: Optional[Client] = None

    @property
    def client(self) -> Optional[Client]:
        if not self._client and self.account_sid and self.auth_token:
            try:
                self._client = Client(self.account_sid, self.auth_token)
            except Exception as e:
                print(f"Failed to initialize Twilio SMS client: {e}")
        return self._client

    @property
    def is_enabled(self) -> bool:
        """True only when all three prerequisites are set."""
        return bool(self.account_sid and self.auth_token and self.from_number)

    def send_sms(self, to_number: str, body: str) -> bool:
        """Send a raw SMS message via Twilio.

        Returns False if SMS is not configured (from_number unset), so the
        caller can treat it as "skipped" rather than "failed".
        """
        if not self.is_enabled or not self.client:
            return False
        try:
            message = self.client.messages.create(
                body=body,
                from_=self.from_number,
                to=to_number,
            )
            return bool(message.sid)
        except Exception as e:
            print(f"Error sending Twilio SMS: {e}")
            return False

    def send_verify_otp(self, to_number: str) -> bool:
        """Send an OTP using Twilio Verify."""
        service_sid = settings.TWILIO_SERVICE_SID
        
        if not self.client or not service_sid:
            logger.error(f"Cannot send Verify OTP: client initialized={bool(self.client)}, service_sid={service_sid}")
            return False
        try:
            verification = self.client.verify.v2.services(service_sid).verifications.create(
                to=to_number, channel="sms"
            )
            return verification.status in ["pending", "approved"]
        except Exception as e:
            logger.error(f"Error sending Verify OTP to {to_number}: {e}", exc_info=True)
            return False

    def check_verify_otp(self, to_number: str, code: str) -> bool:
        """Check an OTP using Twilio Verify."""
        service_sid = settings.TWILIO_SERVICE_SID
        
        if not self.client or not service_sid:
            logger.error(f"Cannot check Verify OTP: client initialized={bool(self.client)}, service_sid={service_sid}")
            return False
        try:
            verification_check = self.client.verify.v2.services(service_sid).verification_checks.create(
                to=to_number, code=code
            )
            return verification_check.status == "approved"
        except Exception as e:
            logger.error(f"Error checking Verify OTP for {to_number}: {e}", exc_info=True)
            return False

    def send_critical_alert_sms(
        self,
        to_number: str,
        patient_name: str,
        alert_text_en: str,
        alert_text_hi: str,
    ) -> bool:
        """Send a bilingual critical health alert via SMS.

        SMS is length-constrained (160 chars per segment), so we prioritize
        English first with a short Hindi suffix. If SMS is disabled (no
        sender number in env), returns False — caller logs as "skipped".
        """
        if not self.is_enabled:
            return False
        body = (
            f"Swasth Alert: {alert_text_en} "
            f"({patient_name}). {alert_text_hi[:60]}..."
        )
        return self.send_sms(to_number, body)


# Singleton instance
sms_service = TwilioSmsService()
