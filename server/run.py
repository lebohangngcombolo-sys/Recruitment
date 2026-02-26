import os
from pathlib import Path

# Load .env from server directory so DATABASE_URL is set even when run from repo root
_env_path = Path(__file__).resolve().parent / ".env"
if _env_path.exists():
    from dotenv import load_dotenv
    load_dotenv(_env_path)

from app import create_app
from app.extensions import db, socketio

app = create_app()

with app.app_context():
    try:
        db.create_all()
    except Exception as e:
        if "OperationalError" in type(e).__name__ or "connection" in str(e).lower():
            print("\n*** Database connection failed ***")
            print("Check DATABASE_URL in server/.env")
            print("  - For local Postgres: postgresql://USER:PASSWORD@localhost:5432/DBNAME")
            print("  - Ensure Postgres is running and USER/PASSWORD are correct.")
            print("  - Or use your Render DB URL (with ?sslmode=require) for remote DB.\n")
        raise

if __name__ == "__main__":
    socketio.run(app, host="0.0.0.0", port=5000)
