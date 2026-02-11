"""
One-off script to add job listing display columns to requisitions table.
Run from server directory: python scripts/add_job_display_columns.py

Or use Flask-Migrate instead:
  flask db migrate -m "add job display fields to requisitions"
  flask db upgrade
"""
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

def main():
    from app import create_app
    from app.extensions import db
    from sqlalchemy import text

    app = create_app()
    with app.app_context():
        # Add columns if not present (idempotent for PostgreSQL)
        columns_add = [
            ("location", "VARCHAR(150) DEFAULT ''"),
            ("employment_type", "VARCHAR(80) DEFAULT 'Full Time'"),
            ("salary_range", "VARCHAR(100) DEFAULT ''"),
            ("application_deadline", "TIMESTAMP"),
            ("company", "VARCHAR(200) DEFAULT ''"),
            ("banner", "VARCHAR(500)"),
        ]
        for col_name, col_def in columns_add:
            try:
                db.session.execute(text(
                    f"ALTER TABLE requisitions ADD COLUMN IF NOT EXISTS {col_name} {col_def}"
                ))
                db.session.commit()
                print(f"Added column: {col_name}")
            except Exception as e:
                # MySQL/SQLite use different syntax; try simple ADD COLUMN
                try:
                    db.session.rollback()
                    db.session.execute(text(f"ALTER TABLE requisitions ADD COLUMN {col_name} {col_def}"))
                    db.session.commit()
                    print(f"Added column: {col_name}")
                except Exception as e2:
                    db.session.rollback()
                    print(f"Skip {col_name}: {e2}")
        print("Done.")

if __name__ == "__main__":
    main()
