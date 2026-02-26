"""
Ensure the database (e.g. Render) has all tables required for the app, including enrollment.
Uses DATABASE_URL from .env. Run from server directory:

  python scripts/ensure_render_tables.py

Required for enrollment form submission:
  - users       (enrollment_completed, etc.)
  - candidates  (user_id, full_name, phone, education, skills, ...)
  - audit_logs  (admin_id, action, extra_data, timestamp)

Note: Render free-tier DB may sleep; first run can take 30–60s to wake. Retry if connection drops.
"""
import sys
import os
import time

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def main():
    from app import create_app
    from app.extensions import db
    from sqlalchemy import text, inspect

    app = create_app()
    with app.app_context():
        uri = app.config.get("SQLALCHEMY_DATABASE_URI", "")
        safe_uri = uri.split("@")[-1] if "@" in uri else uri
        print(f"Database: ...@{safe_uri}")
        print("(If Render free-tier: DB may wake in 30–60s. Retry if connection drops.)")

        # Wake / connect: simple query first so Render can spin up
        for attempt in range(3):
            try:
                db.session.execute(text("SELECT 1"))
                db.session.commit()
                print("Connection OK.")
                break
            except Exception as e:
                db.session.rollback()
                if attempt < 2:
                    print(f"Connection attempt {attempt + 1} failed: {e}. Retrying in 5s...")
                    time.sleep(5)
                else:
                    print("Could not connect. Check DATABASE_URL and that the DB is reachable.")
                    raise

        # Create all tables (same as run.py). Does not alter existing tables.
        for attempt in range(3):
            try:
                db.create_all()
                print("create_all() completed.")
                break
            except Exception as e:
                if attempt < 2 and "server closed the connection" in str(e).lower():
                    print(f"Connection dropped (attempt {attempt + 1}/3). Waiting 10s and retrying...")
                    time.sleep(10)
                else:
                    raise

        # List tables that exist (for verification)
        inspector = inspect(db.engine)
        tables = inspector.get_table_names()
        print(f"Tables present ({len(tables)}):", ", ".join(sorted(tables)))

        required_for_enrollment = ["users", "candidates", "audit_logs"]
        missing = [t for t in required_for_enrollment if t not in tables]
        if missing:
            print("WARNING: Missing tables for enrollment:", missing)
        else:
            print("OK: Enrollment-required tables exist: users, candidates, audit_logs.")

        # Ensure users has enrollment_completed (required for enrollment flow)
        if "users" in tables:
            cols = [c["name"] for c in inspector.get_columns("users")]
            if "enrollment_completed" not in cols:
                try:
                    db.session.execute(text(
                        "ALTER TABLE users ADD COLUMN enrollment_completed BOOLEAN DEFAULT FALSE"
                    ))
                    db.session.commit()
                    print("Added users.enrollment_completed.")
                except Exception as e:
                    db.session.rollback()
                    print("Could not add enrollment_completed:", e)
            else:
                print("OK: users.enrollment_completed exists.")

        # Ensure audit_logs has extra_data (some setups had metadata)
        if "audit_logs" in tables:
            cols = [c["name"] for c in inspector.get_columns("audit_logs")]
            if "extra_data" not in cols and "metadata" in cols:
                try:
                    db.session.execute(text(
                        "ALTER TABLE audit_logs RENAME COLUMN metadata TO extra_data"
                    ))
                    db.session.commit()
                    print("Renamed audit_logs.metadata -> extra_data.")
                except Exception as e:
                    db.session.rollback()
                    print("Note: audit_logs.extra_data:", e)
            elif "extra_data" in cols:
                print("OK: audit_logs.extra_data exists.")


if __name__ == "__main__":
    main()
