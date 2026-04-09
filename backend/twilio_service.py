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

    def send_whatsapp(self, to_number: str, body: str) -> bool:
        """
        Send a WhatsApp message via Twilio.
        
        Args:
            to_number: Recipient's phone number (e.g. "+919876543210")
            body: The message text
            
        Returns:
            True if sent successfully, False otherwise
        """
        if not self.client or not self.from_number:
            print("Twilio credentials or from_number not configured.")
            return False
            
        # Ensure 'whatsapp:' prefix is present for both to and from
        final_to = to_number if to_number.startswith("whatsapp:") else f"whatsapp:{to_number}"
        final_from = self.from_number if self.from_number.startswith("whatsapp:") else f"whatsapp:{self.from_number}"
            
        try:
            message = self.client.messages.create(
                body=body,
                from_=final_from,
                to=final_to
            )
            return True if message.sid else False
        except Exception as e:
            # Note: In production, use a proper logger
            print(f"Error sending Twilio WhatsApp message: {e}")
            return False

# Create singleton instance
whatsapp_service = TwilioWhatsAppService()
