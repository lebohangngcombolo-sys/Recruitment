#!/usr/bin/env python3
"""Create or update sim.carl@khonology.com as a hiring manager with a known password.

Sets: profile (first_name, last_name, full_name), is_verified, is_active,
role=hiring_manager, and password. Password is hashed with AuthService so login works.

Run from server directory with venv activated:

  python scripts/ensure_sim_carl_user.py [password]

Default password: TempPass123!
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

EMAIL = "sim.carl@khonology.com"
DEFAULT_PASSWORD = "TempPass123!"
PROFILE = {
    "first_name": "Sim",
    "last_name": "Carl",
    "full_name": "Sim Carl",
}


def main():
    password = (sys.argv[1] if len(sys.argv) >= 2 else None) or os.environ.get("SIM_CARL_PASSWORD") or DEFAULT_PASSWORD
    email = EMAIL.strip().lower()

    from app import create_app
    from app.extensions import db
    from app.models import User
    from app.services.auth_service import AuthService

    app = create_app()
    with app.app_context():
        user = User.query.filter(db.func.lower(User.email) == email).first()
        hashed = AuthService.hash_password(password)
        if user:
            user.role = "hiring_manager"
            user.is_verified = True
            user.is_active = True
            user.password = hashed
            user.profile = user.profile or {}
            user.profile.update(PROFILE)
            user.enrollment_completed = True
            user.mfa_enabled = False
            user.mfa_verified = False
            if hasattr(user, "mfa_secret"):
                user.mfa_secret = None
            if hasattr(user, "mfa_backup_codes"):
                user.mfa_backup_codes = None
            db.session.commit()
            print(f"Updated: {email}")
        else:
            user = User(
                email=email,
                password=hashed,
                role="hiring_manager",
                profile=dict(PROFILE),
                is_verified=True,
                is_active=True,
                enrollment_completed=True,
                mfa_enabled=False,
                mfa_verified=False,
            )
            db.session.add(user)
            db.session.commit()
            print(f"Created: {email}")

        # Reload and verify password
        db.session.refresh(user)
        if not AuthService.verify_password(password, user.password):
            print("ERROR: Password verification failed after save.")
            sys.exit(1)
        print("Password verification: OK")
        print(f"\nLogin: {email}")
        print(f"Password: {password}")
        print("Role: hiring_manager (is_verified=True)")


if __name__ == "__main__":
    main()
