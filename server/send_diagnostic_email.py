import os
import uuid
import datetime
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

from dotenv import load_dotenv


def send_diagnostic_email() -> bool:
    """Send a diagnostic email using SendGrid SMTP and log detailed steps."""
    print("Starting SendGrid Diagnostic Test...\n")

    # Load configuration from .env
    load_dotenv()

    mail_server = os.getenv("MAIL_SERVER", "smtp.sendgrid.net")
    mail_port = int(os.getenv("MAIL_PORT", "587"))
    mail_use_tls = os.getenv("MAIL_USE_TLS", "True").lower() == "true"
    mail_username = os.getenv("MAIL_USERNAME", "apikey")
    mail_password = os.getenv("MAIL_PASSWORD")
    mail_sender = os.getenv("MAIL_DEFAULT_SENDER")

    recipient_email = "dzunisanimabunda85@gmail.com"

    if not mail_password:
        print("MAIL_PASSWORD is not set. Check your .env file.")
        return False
    if not mail_sender:
        print("MAIL_DEFAULT_SENDER is not set. Check your .env file.")
        return False

    # Unique ID for tracing in SendGrid Activity
    unique_id = str(uuid.uuid4())[:8]
    subject = f"[DIAGNOSTIC {unique_id}] SendGrid Test - Please confirm delivery"
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    text_content = f"""
SendGrid Configuration Test
Test ID: {unique_id}
Time: {timestamp}

If you receive this email, your SendGrid SMTP configuration is working correctly.
Please reply to this email to confirm successful delivery.
"""

    html_content = f"""
<html>
  <body style="font-family: Arial, sans-serif;">
    <h2>SendGrid Configuration Test</h2>
    <p><strong>Test ID:</strong> {unique_id}</p>
    <p><strong>Time:</strong> {timestamp}</p>
    <p>If you receive this email, your SendGrid SMTP configuration is working correctly.</p>
    <p>Please reply to this email to confirm successful delivery.</p>
  </body>
</html>
"""

    # Build the email message
    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = mail_sender
    msg["To"] = recipient_email
    msg.attach(MIMEText(text_content, "plain"))
    msg.attach(MIMEText(html_content, "html"))

    try:
        print(f"1. Connecting to {mail_server}:{mail_port} ...")
        server = smtplib.SMTP(mail_server, mail_port, timeout=30)
        server.set_debuglevel(1)  # verbose SMTP conversation

        if mail_use_tls:
            print("2. Starting TLS ...")
            server.starttls()

        print(f"3. Authenticating as '{mail_username}' ...")
        server.login(mail_username, mail_password)

        print(
            f"4. Sending diagnostic email from {mail_sender} "
            f"to {recipient_email} with Test ID {unique_id} ..."
        )
        server.sendmail(mail_sender, [recipient_email], msg.as_string())
        server.quit()

        print(
            """
5. Diagnostic email queued for delivery.
   --------------------------------------------
   NEXT STEPS:
   1. Wait 1-2 minutes, then refresh your SendGrid 'Activity' page.
   2. Look for this email's status using the Test ID in the subject.
   3. Check your Gmail Spam and Promotions tabs.

   If the status is not 'Delivered', inspect the error for:
   • Unverified sender address
   • Recipient on suppression list
   • Trial account daily send limit
   • Content or policy-related blocks
"""
        )
        return True

    except smtplib.SMTPAuthenticationError:
        print("AUTHENTICATION FAILED: Invalid API key or username.")
        print("- Confirm MAIL_USERNAME='apikey' in .env")
        print("- Ensure the API key has 'Mail Send' permissions")
        print("- Consider creating a new API key in SendGrid")
        return False
    except Exception as e:
        print(f"UNEXPECTED ERROR: {type(e).__name__}: {e}")
        return False


if __name__ == "__main__":
    send_diagnostic_email()
