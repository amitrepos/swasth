import logging
import json

from twilio.rest import Client
from config import settings
from typing import Optional, List

logger = logging.getLogger(__name__)


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
            except Exception:
                logger.error("Failed to initialize Twilio client", exc_info=True)
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
            logger.warning(error_msg)
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
            logger.error("Error sending Twilio WhatsApp message", exc_info=True)
            return False, None, error_msg

    def send_whatsapp_template(
        self, 
        to_number: str, 
        content_sid: str, 
        variables: List[str]
    ) -> tuple[bool, Optional[str], Optional[str]]:
        """
        Send a WhatsApp message using a pre-approved Twilio template.
        
        Args:
            to_number: Recipient's phone number (e.g. "+919876543210")
            content_sid: Template content SID from Twilio (e.g. "HXxxxxx")
            variables: List of variable values in order (for {{1}}, {{2}}, {{3}}, etc.)
            
        Returns:
            A tuple of (success, twilio_sid, error_message)
        """
        if not self.client or not self.from_number:
            error_msg = "Twilio credentials or from_number not configured."
            logger.warning(error_msg)
            return False, None, error_msg
            
        final_to = to_number if to_number.startswith("whatsapp:") else f"whatsapp:{to_number}"
        final_from = self.from_number if self.from_number.startswith("whatsapp:") else f"whatsapp:{self.from_number}"
        
        try:
            # Convert list to dict with numeric string keys: {"1": val1, "2": val2, "3": val3}
            # Also sanitize each value: remove newlines, tabs, and multiple spaces
            content_vars_dict = {}
            for i, var in enumerate(variables, start=1):
                # Sanitize: remove newlines, tabs, and reduce multiple spaces to single space
                # M3 Fix: Use re.sub for O(n) space collapsing
                sanitized = re.sub(r" +", " ", var.replace('\n', ' ').replace('\t', ' '))
                content_vars_dict[str(i)] = sanitized.strip()
            
            message = self.client.messages.create(
                from_=final_from,
                to=final_to,
                content_sid=content_sid,
                content_variables=json.dumps(content_vars_dict)  # Convert dict to JSON string
            )
            return True, message.sid, None
        except Exception as e:
            error_msg = str(e)
            logger.error(f"Error sending Twilio WhatsApp template: {error_msg}", exc_info=True)
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
        success, _, _ = self.send_whatsapp(to_number, body)
        return success


# Create singleton instance
whatsapp_service = TwilioWhatsAppService()
