#!/usr/bin/env python3
"""Create or update local test users so you can log in without 401.

Ensures these users exist with known passwords (is_verified=True, is_active=True):
  - admin@mycompany.com (admin), password: LocalDev123!
  - hiring.manager@test.com (hiring_manager), password: LocalDev123!

Uses DATABASE_URL from server/.env. Run from server directory with venv activated:

  python scripts/ensure_local_test_users.py

To use a different password, set LOCAL_TEST_PASSWORD env var or pass as first argument.
"""
import os
import sys

SERVER_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, SERVER_DIR)
os.chdir(SERVER_DIR)

_env_path = os.path.join(SERVER_DIR, ".env")
if os.path.isfile(_env_path):
    from dotenv import load_dotenv
    load_dotenv(_env_path)

DEFAULT_PASSWORD = "LocalDev123!"
USERS = [
    ("admin@mycompany.com", "admin"),
    ("hiring.manager@test.com", "hiring_manager"),
]


def main():
    password = os.environ.get("LOCAL_TEST_PASSWORD") or (sys.argv[1] if len(sys.argv) >= 2 else None) or DEFAULT_PASSWORD

    from app import create_app
    from app.extensions import db
    from app.models import User
    from app.services.auth_service import AuthService

    app = create_app()
    with app.app_context():
        for email, role in USERS:
            email = email.strip().lower()
            user = User.query.filter(db.func.lower(User.email) == email).first()
            if user:
                user.role = role
                user.is_verified = True
                user.is_active = True
                user.password = AuthService.hash_password(password)
                user.mfa_enabled = False
                user.mfa_verified = False
                if hasattr(user, "mfa_secret"):
                    user.mfa_secret = None
                if hasattr(user, "mfa_backup_codes"):
                    user.mfa_backup_codes = None
                db.session.commit()
                print(f"Updated: {email} (role={role})")
            else:
                user = User(
                    email=email,
                    password=AuthService.hash_password(password),
                    role=role,
                    profile={"full_name": "Local Test " + ("Admin" if role == "admin" else "Hiring Manager")},
                    is_verified=True,
                    is_active=True,
                    enrollment_completed=(role != "candidate"),
                )
                db.session.add(user)
                db.session.commit()
                print(f"Created: {email} (role={role})")

        print(f"\nLogin with password: {password}")
        print("  admin@mycompany.com  → Admin dashboard")
        print("  hiring.manager@test.com → Hiring Manager dashboard")


if __name__ == "__main__":
    main()
