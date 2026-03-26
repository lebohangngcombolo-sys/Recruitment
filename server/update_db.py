from app import create_app
from app.extensions import db
from sqlalchemy import text

app = create_app()
with app.app_context():
    try:
        # Add candidate_id to cv_analyses if it doesn't exist
        db.session.execute(text("ALTER TABLE cv_analyser.cv_analyses ADD COLUMN IF NOT EXISTS candidate_id INTEGER REFERENCES candidates(id)"))
        
        # Make organizer_id nullable in meetings
        db.session.execute(text("ALTER TABLE meetings ALTER COLUMN organizer_id DROP NOT NULL"))
        
        db.session.commit()
        print("Database schema updated successfully.")
    except Exception as e:
        db.session.rollback()
        print(f"Error updating database: {e}")
