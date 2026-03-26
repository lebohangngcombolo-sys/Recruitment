"""
Fix alembic_version when it points to a revision that no longer exists (e.g. 7ec5a07c5b21).
Run from server directory: python scripts/fix_alembic_version.py
Then run: flask db upgrade
"""
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import create_app
from sqlalchemy import text

TARGET_REVISION = "20260306_interview_slots"

def main():
    app = create_app()
    with app.app_context():
        from app.extensions import db
        with db.engine.connect() as conn:
            conn.execute(text("UPDATE alembic_version SET version_num = :rev"), {"rev": TARGET_REVISION})
            conn.commit()
    print(f"alembic_version set to '{TARGET_REVISION}'. Now run: flask db upgrade")

if __name__ == "__main__":
    main()
