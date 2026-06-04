#!/usr/bin/env python3
"""Send a test verification email to check MAIL_* (e.g. SendGrid) configuration.
Uses .env from server/. Run from repo root: python server/scripts/send_test_verification_email.py
Or from server/: python scripts/send_test_verification_email.py
"""
import os
import sys

SERVER_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, SERVER_DIR)
os.chdir(SERVER_DIR)

try:
    from dotenv import load_dotenv
    load_dotenv(os.path.join(SERVER_DIR, ".env"))
except Exception:
    pass

# Recipient for this test
TEST_EMAIL = "dzunisanimabunda85@gmail.com"
TEST_CODE = "123456"


def main():
    from app import create_app
    from app.extensions import mail
    from flask_mail import Message
    from flask import render_template

    app = create_app()
    with app.app_context():
        sender = app.config.get("MAIL_DEFAULT_SENDER") or app.config.get("MAIL_USERNAME")
        if not sender or not app.config.get("MAIL_PASSWORD"):
            print("ERROR: MAIL_* not configured. Set MAIL_USERNAME, MAIL_PASSWORD, MAIL_DEFAULT_SENDER (and MAIL_SERVER, MAIL_PORT, MAIL_USE_TLS) in server/.env")
            sys.exit(1)
        app_url = (app.config.get("FRONTEND_URL") or "").rstrip("/") or "http://localhost:3000"
        try:
            html = render_template(
                "email_templates/verification_email.html",
                verification_code=TEST_CODE,
                app_url=app_url,
            )
        except Exception as e:
            print(f"Template render failed: {e}")
            html = f"Your verification code is: {TEST_CODE}. Enter it at {app_url}/verify-email"

        msg = Message(
            subject="Verify Your Email Address (Test)",
            recipients=[TEST_EMAIL],
            html=html,
            body=f"Your verification code is: {TEST_CODE}",
            sender=sender,
        )
        try:
            mail.send(msg)
            print(f"OK: Test verification email sent to {TEST_EMAIL} (code: {TEST_CODE})")
        except Exception as e:
            print(f"FAIL: {e}")
            sys.exit(1)


if __name__ == "__main__":
    main()
