#!/usr/bin/env python3
"""Create and verify an admin user using DATABASE_URL from server/.env.

Usage:
  python scripts/create_admin_user.py [email] [password]
  If email/password omitted, uses admin@example.com and a generated password (printed).

Example:
  python scripts/create_admin_user.py
  python scripts/create_admin_user.py admin@mycompany.com MySecurePass123
"""
import os
import sys
import secrets
import string

SERVER_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, SERVER_DIR)
os.chdir(SERVER_DIR)

# Ensure we load .env from server directory (same as app config)
_env_path = os.path.join(SERVER_DIR, ".env")
if os.path.isfile(_env_path):
    from dotenv import load_dotenv
    load_dotenv(_env_path)
    db_url = os.environ.get("DATABASE_URL")
    if not db_url:
        print("ERROR: DATABASE_URL not set in server/.env")
        sys.exit(1)
else:
    print("ERROR: server/.env not found")
    sys.exit(1)


def _generate_password(length=14):
    alphabet = string.ascii_letters + string.digits + "!@#$%^&*"
    return "".join(secrets.choice(alphabet) for _ in range(length))


def main():
    email = (sys.argv[1].strip().lower() if len(sys.argv) >= 2 else None) or "admin@example.com"
    if len(sys.argv) >= 3:
        password = sys.argv[2]
    else:
        password = _generate_password()

    from app import create_app
    from app.extensions import db
    from app.models import User
    from app.services.auth_service import AuthService

    app = create_app()
    with app.app_context():
        user = User.query.filter(db.func.lower(User.email) == email).first()
        created = False
        if user:
            user.role = "admin"
            user.is_verified = True
            user.is_active = True
            user.password = AuthService.hash_password(password)
            db.session.commit()
            print(f"Updated existing user to admin: {email}")
        else:
            user = User(
                email=email,
                password=AuthService.hash_password(password),
                role="admin",
                profile={},
                is_verified=True,
                is_active=True,
            )
            db.session.add(user)
            db.session.commit()
            created = True
            print(f"Created admin user: {email}")

        # Verify: check password and role
        check = User.query.get(user.id)
        assert check is not None
        ok_password = AuthService.verify_password(password, check.password)
        ok_role = check.role == "admin"
        ok_verified = check.is_verified is True
        if ok_password and ok_role and ok_verified:
            print("Verification: OK (password valid, role=admin, is_verified=True)")
        else:
            print("Verification: FAILED")
            if not ok_password:
                print("  - Password check failed")
            if not ok_role:
                print(f"  - role is {check.role!r}, expected 'admin'")
            if not ok_verified:
                print(f"  - is_verified is {check.is_verified}")
            sys.exit(1)

        print(f"\nAdmin login:")
        print(f"  Email:    {email}")
        print(f"  Password: {password}")
        if created or len(sys.argv) < 3:
            print("  (Save the password; it won't be shown again.)")
        print(f"\nDatabase: DATABASE_URL from server/.env (connected successfully)")


if __name__ == "__main__":
    main()
