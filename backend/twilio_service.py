from twilio.rest import Client
from config import settings
from typing import Optional

class TwilioWhatsAppService:
    """Service for sending WhatsApp messages via Twilio."""
    
    def __init__(self):
        self.account_sid = settings.TWILIO_ACCOUNT_SID
        self.auth_token = settings.TWILIO_AUTH_TOKEN
        self.from_number = settings.TWILIO_WHATSAPP_NUMBER
        
        # Initialize client lazily
        self._client: Optional[Client] = None

    @property
    def client(self) -> Optional[Client]:
        if not self._client and self.account_sid and self.auth_token:
            try:
                self._client = Client(self.account_sid, self.auth_token)
            except Exception as e:
                print(f"Failed to initialize Twilio client: {e}")
        return self._client

    def send_whatsapp(self, to_number: str, body: str) -> tuple[bool, Optional[str], Optional[str]]:
        """
        Send a WhatsApp message via Twilio.
        
        Args:
            to_number: Recipient's phone number (e.g. "+919876543210")
            body: The message text
            
        Returns:
            A tuple of (success, twilio_sid, error_message)
        """
        if not self.client or not self.from_number:
            error_msg = "Twilio credentials or from_number not configured."
            print(error_msg)
            return False, None, error_msg
            
        # Ensure 'whatsapp:' prefix is present for both to and from
        final_to = to_number if to_number.startswith("whatsapp:") else f"whatsapp:{to_number}"
        final_from = self.from_number if self.from_number.startswith("whatsapp:") else f"whatsapp:{self.from_number}"
            
        try:
            message = self.client.messages.create(
                body=body,
                from_=final_from,
                to=final_to
            )
            return True, message.sid, None
        except Exception as e:
            error_msg = str(e)
            # Note: In production, use a proper logger
            print(f"Error sending Twilio WhatsApp message: {error_msg}")
            return False, None, error_msg

    def send_critical_alert_whatsapp(
        self,
        to_number: str,
        patient_name: str,
        alert_text_en: str,
        alert_text_hi: str,
    ) -> bool:
        """Send a bilingual critical health alert via WhatsApp.

        Returns True on success, False on any failure. Callers log and
        try other channels on False.
        """
        if not self.client or not self.from_number:
            return False
        body = (
            f"🚨 *Swasth Health Alert*\n\n"
            f"*English:* {alert_text_en}\n\n"
            f"*हिन्दी:* {alert_text_hi}\n\n"
            f"— Swasth Health App"
        )
        return self.send_whatsapp(to_number, body)


# Create singleton instance
whatsapp_service = TwilioWhatsAppService()
