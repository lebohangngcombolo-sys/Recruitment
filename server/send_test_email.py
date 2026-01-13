import os
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

from dotenv import load_dotenv


def send_welcome_email() -> bool:
    """Send a simple welcome email using SendGrid SMTP settings from .env."""
    # Load environment variables from .env in this directory
    load_dotenv()

    mail_server = os.getenv("MAIL_SERVER", "smtp.sendgrid.net")
    mail_port = int(os.getenv("MAIL_PORT", "587"))
    mail_use_tls = os.getenv("MAIL_USE_TLS", "True").lower() == "true"
    mail_username = os.getenv("MAIL_USERNAME", "apikey")
    mail_password = os.getenv("MAIL_PASSWORD")
    mail_sender = os.getenv("MAIL_DEFAULT_SENDER")

    recipient_email = os.getenv("TEST_RECIPIENT_EMAIL", "dzunisanimabunda85@gmail.com")

    if not mail_password:
        print("MAIL_PASSWORD is not set. Check your .env file.")
        return False
    if not mail_sender:
        print("MAIL_DEFAULT_SENDER is not set. Check your .env file.")
        return False

    subject = "Welcome to Khono Recruite!"

    text_content = (
        "Hello!\n\n"
        "Welcome to Khono Recruite. This is a test email sent via SendGrid SMTP "
        "using your Flask application's mail settings.\n\n"
        "If you received this, SMTP is working correctly.\n\n"
        "Best regards,\nKhono Recruite Backend"
    )

    html_content = f"""
    <html>
      <body style="font-family: Arial, sans-serif; line-height: 1.5;">
        <h2>Welcome to Khono Recruite!</h2>
        <p>Hello!</p>
        <p>
          This is a <strong>test email</strong> sent via <code>smtp.sendgrid.net</code>
          using the credentials configured in your <code>.env</code> file.
        </p>
        <p>If you received this message, your SMTP configuration is working correctly.</p>
        <p>Best regards,<br/>Khono Recruite Backend</p>
      </body>
    </html>
    """

    try:
        msg = MIMEMultipart("alternative")
        msg["Subject"] = subject
        msg["From"] = mail_sender
        msg["To"] = recipient_email

        msg.attach(MIMEText(text_content, "plain"))
        msg.attach(MIMEText(html_content, "html"))

        print(f"Connecting to SMTP server {mail_server}:{mail_port} ...")
        with smtplib.SMTP(mail_server, mail_port) as server:
            server.set_debuglevel(1)  # print SMTP conversation

            if mail_use_tls:
                print("Starting TLS ...")
                server.starttls()

            print(f"Logging in as {mail_username} ...")
            server.login(mail_username, mail_password)

            print(f"Sending email from {mail_sender} to {recipient_email} ...")
            server.sendmail(mail_sender, [recipient_email], msg.as_string())

        print("Email sent successfully.")
        return True
    except Exception as e:
        print(f"Error sending email: {e}")
        return False


if __name__ == "__main__":
    success = send_welcome_email()
    if success:
        print("Welcome email sent successfully.")
    else:
        print("Failed to send welcome email.")
