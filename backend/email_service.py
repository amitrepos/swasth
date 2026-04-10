import smtplib
import random
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime, timedelta
from typing import Optional
from config import settings


class BrevoEmailService:
    """Service for sending emails via Brevo SMTP."""
    
    def __init__(self):
        self.smtp_server = settings.BREVO_SMTP_SERVER
        self.smtp_port = settings.BREVO_SMTP_PORT
        self.sender_email = settings.BREVO_SENDER_EMAIL
        self.smtp_login = settings.BREVO_SMTP_LOGIN  
        self.sender_password = settings.BREVO_SMTP_PASSWORD
        self.sender_name = settings.BREVO_SENDER_NAME
    
    def generate_otp(self) -> str:
        """Generate a 6-digit OTP."""
        return str(random.randint(100000, 999999))
    
    def send_otp_email(self, recipient_email: str, otp: str) -> bool:
        """
        Send OTP email for password reset.
        
        Args:
            recipient_email: Recipient's email address
            otp: The OTP to send
            
        Returns:
            True if email sent successfully, False otherwise
        """
        try:
            # Create message
            msg = MIMEMultipart()
            msg['From'] = f"{self.sender_name} <{self.sender_email}>"
            msg['To'] = recipient_email
            msg['Subject'] = "Password Reset OTP - Swasth Health App"
            
            # Email body
            body = f"""
<!DOCTYPE html>
<html>
<head>
    <style>
        body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
        .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
        .header {{ background-color: #4CAF50; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }}
        .content {{ background-color: #f9f9f9; padding: 30px; border: 1px solid #ddd; }}
        .otp-box {{ background-color: #fff; border: 2px dashed #4CAF50; padding: 20px; text-align: center; margin: 20px 0; }}
        .otp-code {{ font-size: 32px; font-weight: bold; color: #4CAF50; letter-spacing: 5px; }}
        .warning {{ background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; }}
        .footer {{ text-align: center; padding: 20px; color: #666; font-size: 12px; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🏥 Swasth Health App</h1>
            <p>Password Reset Request</p>
        </div>
        
        <div class="content">
            <p>Hello,</p>
            
            <p>We received a request to reset your password for your Swasth Health App account.</p>
            
            <p>Your One-Time Password (OTP) is:</p>
            
            <div class="otp-box">
                <div class="otp-code">{otp}</div>
            </div>
            
            <p>This OTP is valid for <strong>10 minutes</strong>.</p>
            
            <div class="warning">
                <strong>⚠️ Important Security Notice:</strong>
                <ul>
                    <li>Do not share this OTP with anyone</li>
                    <li>Our team will never ask for your password or OTP</li>
                    <li>If you didn't request this, please ignore this email</li>
                </ul>
            </div>
            
            <p>To complete the password reset:</p>
            <ol>
                <li>Open the Swasth Health App</li>
                <li>Enter this OTP when prompted</li>
                <li>Create a new strong password</li>
            </ol>
            
            <p>Thank you for using Swasth Health App!</p>
            
            <p>Best regards,<br>
            <strong>The Swasth Health Team</strong></p>
        </div>
        
        <div class="footer">
            <p>This is an automated message. Please do not reply to this email.</p>
            <p>&copy; 2026 Swasth Health App. All rights reserved.</p>
        </div>
    </div>
</body>
</html>
            """
            
            msg.attach(MIMEText(body, 'html'))
            
            # Connect to Brevo SMTP and send email
            with smtplib.SMTP(self.smtp_server, self.smtp_port) as server:
                server.starttls()
                server.login(self.smtp_login, self.sender_password)
                server.send_message(msg)
            
            return True
            
        except Exception as e:
            print(f"Error sending email: {e}")
            return False
    
    def send_welcome_email(self, recipient_email: str, user_name: str) -> bool:
        """
        Send welcome email to new users.
        
        Args:
            recipient_email: Recipient's email address
            user_name: User's name
            
        Returns:
            True if email sent successfully, False otherwise
        """
        try:
            msg = MIMEMultipart()
            msg['From'] = f"{self.sender_name} <{self.sender_email}>"
            msg['To'] = recipient_email
            msg['Subject'] = "Welcome to Swasth Health App! 🎉"
            
            body = f"""
<!DOCTYPE html>
<html>
<head>
    <style>
        body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
        .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
        .header {{ background-color: #4CAF50; color: white; padding: 30px; text-align: center; border-radius: 8px 8px 0 0; }}
        .content {{ background-color: #f9f9f9; padding: 30px; border: 1px solid #ddd; }}
        .features {{ background-color: #fff; padding: 20px; margin: 20px 0; border-radius: 8px; }}
        .feature-item {{ margin: 15px 0; padding: 10px; border-left: 3px solid #4CAF50; }}
        .footer {{ text-align: center; padding: 20px; color: #666; font-size: 12px; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🎉 Welcome to Swasth!</h1>
            <p>Your Health Monitoring Companion</p>
        </div>
        
        <div class="content">
            <p>Dear {user_name},</p>
            
            <p>Welcome to <strong>Swasth Health App</strong>! We're excited to have you on board.</p>
            
            <p>Your account has been successfully created. You can now start tracking your health data and monitoring your wellness journey.</p>
            
            <div class="features">
                <h3>What you can do with Swasth:</h3>
                <div class="feature-item">✅ Track your health metrics in real-time</div>
                <div class="feature-item">✅ Monitor blood glucose levels</div>
                <div class="feature-item">✅ View historical health data</div>
                <div class="feature-item">✅ Connect BLE health devices</div>
                <div class="feature-item">✅ Get insights into your health trends</div>
            </div>
            
            <p>Get started by logging into your account and exploring all the features we have to offer.</p>
            
            <p>If you have any questions or need assistance, feel free to reach out to our support team.</p>
            
            <p>Welcome aboard! 🚀</p>
            
            <p>Best regards,<br>
            <strong>The Swasth Health Team</strong></p>
        </div>
        
        <div class="footer">
            <p>&copy; 2026 Swasth Health App. All rights reserved.</p>
        </div>
    </div>
</body>
</html>
            """
            
            msg.attach(MIMEText(body, 'html'))
            
            with smtplib.SMTP(self.smtp_server, self.smtp_port) as server:
                server.starttls()
                server.login(self.smtp_login, self.sender_password)
                server.send_message(msg)
            
            return True
            
        except Exception as e:
            print(f"Error sending welcome email: {e}")
            return False


    def send_profile_invite_email(
        self,
        invitee_email: str,
        inviter_name: str,
        profile_name: str,
        invite_id: int,
    ) -> bool:
        """Send an invite notification when a user shares their health profile.

        Args:
            invitee_email:  Email of the person being invited.
            inviter_name:   Full name of the person sending the invite.
            profile_name:   Name of the profile being shared (e.g. "Papa", "My Health").
            invite_id:      DB id of the ProfileInvite row (for deep-link future use).

        Returns:
            True if the email was sent successfully, False otherwise.
        """
        try:
            msg = MIMEMultipart()
            msg['From'] = f"{self.sender_name} <{self.sender_email}>"
            msg['To'] = invitee_email
            msg['Subject'] = f"{inviter_name} wants to share health data with you on Swasth"

            body = f"""
<!DOCTYPE html>
<html>
<head>
    <style>
        body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
        .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
        .header {{ background-color: #4CAF50; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }}
        .content {{ background-color: #f9f9f9; padding: 30px; border: 1px solid #ddd; }}
        .invite-box {{ background-color: #fff; border: 2px solid #4CAF50; padding: 20px; margin: 20px 0; border-radius: 8px; text-align: center; }}
        .profile-name {{ font-size: 22px; font-weight: bold; color: #4CAF50; }}
        .footer {{ text-align: center; padding: 20px; color: #666; font-size: 12px; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Swasth Health App</h1>
            <p>Health Profile Invite</p>
        </div>

        <div class="content">
            <p>Hello,</p>

            <p><strong>{inviter_name}</strong> wants to share their health profile with you on Swasth Health App.</p>

            <div class="invite-box">
                <p>Profile:</p>
                <div class="profile-name">{profile_name}</div>
            </div>

            <p>By accepting this invite, you will be able to view health readings (glucose, blood pressure) logged under this profile.</p>

            <p>To accept or reject this invite:</p>
            <ol>
                <li>Open the Swasth Health App</li>
                <li>Go to <strong>Pending Invites</strong></li>
                <li>Accept or reject the invite from {inviter_name}</li>
            </ol>

            <p>This invite will expire in <strong>7 days</strong>. If you did not expect this invite, you can safely ignore this email.</p>

            <p>Best regards,<br>
            <strong>The Swasth Health Team</strong></p>
        </div>

        <div class="footer">
            <p>This is an automated message. Please do not reply to this email.</p>
            <p>&copy; 2026 Swasth Health App. All rights reserved.</p>
        </div>
    </div>
</body>
</html>
            """

            msg.attach(MIMEText(body, 'html'))

            with smtplib.SMTP(self.smtp_server, self.smtp_port) as server:
                server.starttls()
                server.login(self.smtp_login, self.sender_password)
                server.send_message(msg)

            return True

        except Exception as e:
            print(f"Error sending invite email: {e}")
            return False

    def send_critical_alert_email(
        self,
        recipient_email: str,
        recipient_name: str,
        patient_name: str,
        alert_text_en: str,
        alert_text_hi: str,
    ) -> bool:
        """Send a bilingual (EN + HI) critical health alert to a family member.

        Returns True on success, False on any failure (SMTP down, auth error,
        not configured, rejected recipient). Callers log the failure and try
        other channels.
        """
        if not self.smtp_login or not self.sender_password:
            return False
        try:
            msg = MIMEMultipart()
            msg['From'] = f"{self.sender_name} <{self.sender_email}>"
            msg['To'] = recipient_email
            msg['Subject'] = f"🚨 Health Alert — {patient_name} needs attention"

            body = f"""
<!DOCTYPE html>
<html>
<head>
    <style>
        body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
        .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
        .alert {{ background: #fff5f5; border-left: 4px solid #dc2626; padding: 16px; margin: 16px 0; }}
        .lang {{ margin: 12px 0; }}
        .footer {{ font-size: 12px; color: #666; margin-top: 32px; }}
    </style>
</head>
<body>
    <div class="container">
        <h2>🚨 Swasth Health Alert</h2>
        <p>Dear {recipient_name},</p>
        <div class="alert">
            <div class="lang"><strong>English:</strong><br>{alert_text_en}</div>
            <div class="lang"><strong>हिन्दी:</strong><br>{alert_text_hi}</div>
        </div>
        <p>Please check on {patient_name} immediately and contact their doctor if needed.</p>
        <p class="footer">
            You received this alert because you have access to {patient_name}'s health profile on Swasth.
            To stop receiving alerts, revoke your access in the Swasth app.
            <br><br>— Swasth Health App
        </p>
    </div>
</body>
</html>
"""
            msg.attach(MIMEText(body, 'html'))
            with smtplib.SMTP(self.smtp_server, self.smtp_port) as server:
                server.starttls()
                server.login(self.smtp_login, self.sender_password)
                server.send_message(msg)
            return True
        except Exception as e:
            print(f"Failed to send critical alert email to {recipient_email}: {e}")
            return False


# Create singleton instance
email_service = BrevoEmailService()
