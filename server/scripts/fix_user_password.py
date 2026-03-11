#!/usr/bin/env python3
"""Update a user's password to a valid bcrypt hash in the database.
Uses DATABASE_URL from .env (same DB as the app).

Usage:
  python scripts/fix_user_password.py <email> [password]
  If password is omitted, you will be prompted (recommended).

Example:
  python scripts/fix_user_password.py admin@example.com
  python scripts/fix_user_password.py admin@example.com myNewPassword
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


def main():
    if len(sys.argv) < 2:
        print("Usage: python scripts/fix_user_password.py <email> [password]")
        sys.exit(1)

    email = sys.argv[1].strip().lower()
    if len(sys.argv) >= 3:
        password = sys.argv[2]
    else:
        try:
            import getpass
            password = getpass.getpass("New password: ")
        except Exception:
            password = input("New password: ")
        if not password:
            print("Password cannot be empty.")
            sys.exit(1)

    from app import create_app
    from app.extensions import db
    from app.models import User
    from app.services.auth_service import AuthService

    app = create_app()
    with app.app_context():
        user = User.query.filter(db.func.lower(User.email) == email).first()
        if not user:
            print(f"No user found with email: {email}")
            sys.exit(1)

        user.password = AuthService.hash_password(password)
        db.session.commit()
        print(f"Password updated for: {email}")


if __name__ == "__main__":
    main()
