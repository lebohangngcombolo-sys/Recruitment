"""
Create and push test user credentials to the database: one candidate, one hiring manager,
and one admin. All users are verified and can log in with the same password.

Usage (from server directory):
  venv\\scripts\\activate  (Windows) or: source venv/bin/activate (Unix)
  python scripts/seed_test_users.py

Uses DATABASE_URL from server/.env (or default local Postgres).
"""
import os
import sys
from pathlib import Path

# Load .env from server directory
server_dir = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(server_dir))
_env_path = server_dir / ".env"
if _env_path.exists():
    from dotenv import load_dotenv
    load_dotenv(_env_path)

from app import create_app
from app.extensions import db
from app.models import User, Candidate
from app.services.auth_service import AuthService

# Default password for all test users (meet typical validator: upper, lower, number, special)
DEFAULT_PASSWORD = "Password123!"

# Use @khonology.com so login passes "Only Khonology work emails allowed" check
USERS_TO_CREATE = [
    {"email": "candidate@khonology.com", "role": "candidate", "label": "Candidate"},
    {"email": "hiringmanager@khonology.com", "role": "hiring_manager", "label": "Hiring Manager"},
    {"email": "admin@khonology.com", "role": "admin", "label": "Admin"},
]


def main():
    # Ensure we use server/.env (for DATABASE_URL) even when run from repo root
    env_path = Path(__file__).resolve().parent.parent / ".env"
    if env_path.exists():
        from dotenv import load_dotenv
        load_dotenv(env_path, override=True)
    db_url = os.environ.get("DATABASE_URL", "")
    if "render.com" in db_url:
        print("Using Render database:", db_url.split("@")[-1].split("/")[0] if "@" in db_url else "(Render)")
    elif db_url:
        print("Using DATABASE_URL from .env")
    app = create_app()
    with app.app_context():
        for spec in USERS_TO_CREATE:
            email = spec["email"].strip().lower()
            role = spec["role"]
            existing = User.query.filter(db.func.lower(User.email) == email).first()
            if existing:
                existing.is_verified = True
                existing.is_active = True
                existing.enrollment_completed = True
                existing.mfa_enabled = False
                existing.mfa_verified = False
                existing.mfa_secret = None
                existing.mfa_backup_codes = None
                existing.role = role
                db.session.commit()
                print(f"Updated existing user: {email} (role={role})")
                if role == "candidate":
                    cand = Candidate.query.filter_by(user_id=existing.id).first()
                    if not cand:
                        cand = Candidate(user_id=existing.id, full_name=existing.profile.get("full_name") or "Test Candidate")
                        db.session.add(cand)
                        db.session.commit()
                        print(f"  -> Created Candidate record for {email}")
                continue

            user = User(
                email=email,
                password=AuthService.hash_password(DEFAULT_PASSWORD),
                role=role,
                profile={"full_name": spec["label"]} if role != "candidate" else {},
                is_verified=True,
                is_active=True,
                enrollment_completed=True,
                mfa_enabled=False,
                mfa_verified=False,
            )
            db.session.add(user)
            db.session.flush()
            if role == "candidate":
                cand = Candidate(user_id=user.id, full_name="Test Candidate")
                db.session.add(cand)
            db.session.commit()
            print(f"Created: {email} (role={role})")

        print("\n--- Login credentials (all use this password) ---")
        print(f"  Password: {DEFAULT_PASSWORD}")
        print("  Candidate:       candidate@khonology.com")
        print("  Hiring Manager:  hiringmanager@khonology.com")
        print("  Admin:           admin@khonology.com")
        print("\nAll users are verified (Khonology work emails). Log in with the above.")


if __name__ == "__main__":
    main()
