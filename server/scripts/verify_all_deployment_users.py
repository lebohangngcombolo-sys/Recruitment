#!/usr/bin/env python3
"""
Verify all unverified users in the deployment database (recruitment_db_vexi)
and ensure every user has a valid bcrypt password so they can log in.

Uses External_Database_URL from server/.env (use Internal_Database_URL only when
running on Render).

Run from repo root: python server/scripts/verify_all_deployment_users.py
Or from server/:  python scripts/verify_all_deployment_users.py
"""
import os
import sys

SERVER_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, SERVER_DIR)
os.chdir(SERVER_DIR)

from dotenv import load_dotenv
load_dotenv(os.path.join(SERVER_DIR, ".env"))

# Deployment DB: use External from local (SSL); use Internal on Render
url = os.getenv("External_Database_URL") or os.getenv("EXTERNAL_DATABASE_URL")
if not url:
    url = os.getenv("Internal_Database_URL")
if not url or not url.strip():
    print("ERROR: Set External_Database_URL (or Internal_Database_URL) in server/.env", file=sys.stderr)
    sys.exit(1)
url = url.strip()
if "postgresql" in url and "sslmode=" not in url:
    url = f"{url}?sslmode=require" if "?" not in url else f"{url}&sslmode=require"

try:
    import bcrypt
except ImportError:
    print("ERROR: bcrypt required. Run: pip install bcrypt", file=sys.stderr)
    sys.exit(1)

from sqlalchemy import create_engine, text

DEFAULT_PASSWORD = "Deploy123!"


def is_valid_bcrypt(s):
    if not s or not isinstance(s, str):
        return False
    s = s.strip()
    if not s.startswith(("$2a$", "$2b$", "$2y$")):
        return False
    if len(s) < 59:
        return False
    return True


def main():
    engine = create_engine(url, connect_args={"connect_timeout": 15})
    hashed_default = bcrypt.hashpw(DEFAULT_PASSWORD.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")

    with engine.begin() as conn:
        # 1) List unverified users
        r = conn.execute(text(
            "SELECT id, email, role, is_verified, is_active FROM users WHERE is_verified IS NOT TRUE"
        ))
        unverified = r.fetchall()
        if not unverified:
            print("No unverified users found.")
        else:
            print(f"Found {len(unverified)} unverified user(s):")
            for row in unverified:
                print(f"  id={row[0]}  email={row[1]}  role={row[2]}  is_verified={row[3]}  is_active={row[4]}")

            # 2) Set is_verified=True, is_active=True, disable MFA for all unverified
            conn.execute(text("""
                UPDATE users
                SET is_verified = TRUE,
                    is_active = TRUE,
                    mfa_enabled = FALSE,
                    mfa_verified = FALSE,
                    mfa_secret = NULL,
                    mfa_backup_codes = NULL
                WHERE is_verified IS NOT TRUE
            """))
            print(f"Verified and activated {len(unverified)} user(s).")

        # 3) Ensure every user has a valid bcrypt password (so they can log in)
        r = conn.execute(text("SELECT id, email, password FROM users"))
        rows = r.fetchall()
        fixed_passwords = []
        for (uid, email, password) in rows:
            email = (email or "").strip()
            if is_valid_bcrypt(password):
                continue
            conn.execute(
                text("UPDATE users SET password = :pw WHERE id = :id"),
                {"pw": hashed_default, "id": uid},
            )
            fixed_passwords.append((uid, email))

        if fixed_passwords:
            print(f"Set password to '{DEFAULT_PASSWORD}' for {len(fixed_passwords)} user(s) (invalid/missing bcrypt):")
            for uid, email in fixed_passwords:
                print(f"  id={uid}  {email}")
        else:
            print("All users already have valid bcrypt passwords.")

    print("Done. All deployment users are verified and can log in (use Deploy123! for any that had invalid password).")


if __name__ == "__main__":
    main()
