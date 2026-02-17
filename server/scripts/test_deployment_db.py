#!/usr/bin/env python3
"""Test connection to the deployment database (recruitment_db_vexi).
Uses External_Database_URL from .env.
Run from repo root or server/: python server/scripts/test_deployment_db.py
Or from server/: python scripts/test_deployment_db.py
"""
import os
import sys

SERVER_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, SERVER_DIR)
os.chdir(SERVER_DIR)

# Load .env from server directory
try:
    from dotenv import load_dotenv
    load_dotenv(os.path.join(SERVER_DIR, ".env"))
except Exception:
    pass

def main():
    url = os.getenv("External_Database_URL") or os.getenv("EXTERNAL_DATABASE_URL")
    if not url:
        print("ERROR: Set External_Database_URL (or EXTERNAL_DATABASE_URL) in .env")
        sys.exit(1)
    url = url.strip()
    if url.startswith("postgresql://") and "sslmode=" not in url:
        url = f"{url}?sslmode=require"

    from sqlalchemy import create_engine, text
    print("Connecting to deployment DB (External_Database_URL)...")
    try:
        engine = create_engine(url, connect_args={"connect_timeout": 10})
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
            print("  SELECT 1: OK")
            r = conn.execute(text(
                "SELECT table_name FROM information_schema.tables "
                "WHERE table_schema = 'public' ORDER BY table_name"
            ))
            tables = [row[0] for row in r]
            print(f"  Tables in public: {len(tables)}")
            if tables:
                print("  ", ", ".join(tables[:15]), "..." if len(tables) > 15 else "")
            # Check alembic if present
            if "alembic_version" in tables:
                v = conn.execute(text("SELECT version_num FROM alembic_version")).scalar()
                print(f"  Alembic revision: {v}")
        print("Deployment database connection: OK")
    except Exception as e:
        print(f"Deployment database connection: FAILED — {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
