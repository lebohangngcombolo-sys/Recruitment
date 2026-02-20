#!/usr/bin/env python3
"""Set bcrypt passwords for the two deployed test users. Uses DATABASE_URL only (no full Flask app)."""
import os
import sys

SERVER_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, SERVER_DIR)
os.chdir(SERVER_DIR)
from dotenv import load_dotenv
load_dotenv(os.path.join(SERVER_DIR, ".env"))

import bcrypt

USERS = [
    ("hm.deployed@test.com", "Deploy123!"),
    ("admin.deployed@test.com", "DeployAdmin123!"),
]

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
    with engine.connect() as conn:
        for email, password in USERS:
            email = email.strip().lower()
            hashed = bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")
            r = conn.execute(
                text("UPDATE users SET password = :pw WHERE LOWER(email) = :email"),
                {"pw": hashed, "email": email},
            )
            conn.commit()
            if r.rowcount:
                print(f"Updated: {email}")
            else:
                print(f"Not found: {email}")
    print("Done.")

if __name__ == "__main__":
    main()
