#!/usr/bin/env python3
"""Set a valid bcrypt password for every user whose stored password is invalid or missing.
Uses DATABASE_URL. Default password for fixed users: Deploy123!
"""
import os
import sys

SERVER_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, SERVER_DIR)
os.chdir(SERVER_DIR)
from dotenv import load_dotenv
load_dotenv(os.path.join(SERVER_DIR, ".env"))

import bcrypt

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
    url = os.getenv("DATABASE_URL")
    if not url or not url.strip():
        print("ERROR: DATABASE_URL not set in .env")
        sys.exit(1)
    url = url.strip()
    if "postgresql" in url and "sslmode=" not in url:
        url = f"{url}?sslmode=require" if "?" not in url else f"{url}&sslmode=require"

    from sqlalchemy import create_engine, text

    engine = create_engine(url, connect_args={"connect_timeout": 15})
    hashed_default = bcrypt.hashpw(DEFAULT_PASSWORD.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")

    with engine.connect() as conn:
        r = conn.execute(text("SELECT id, email, password FROM users"))
        rows = r.fetchall()
        updated = []
        skipped = []
        for (uid, email, password) in rows:
            email = (email or "").strip().lower()
            if is_valid_bcrypt(password):
                skipped.append((uid, email))
                continue
            conn.execute(
                text("UPDATE users SET password = :pw WHERE id = :id"),
                {"pw": hashed_default, "id": uid},
            )
            conn.commit()
            updated.append((uid, email))

        print(f"Updated {len(updated)} user(s) to password '{DEFAULT_PASSWORD}':")
        for uid, email in updated:
            print(f"  id={uid}  {email}")
        if skipped:
            print(f"Skipped {len(skipped)} user(s) (already had valid bcrypt).")
    print("Done.")

if __name__ == "__main__":
    main()
