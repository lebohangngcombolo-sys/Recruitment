"""
Simple database migration to add missing fields for team collaboration enhancements
"""

from app import db
from sqlalchemy import text

def upgrade():
    """Add missing fields and tables"""
    
    try:
        # Add username field to users table if it doesn't exist
        try:
            db.session.execute(text("ALTER TABLE users ADD COLUMN username VARCHAR(50) UNIQUE"))
            print("✅ Added username column to users table")
        except Exception as e:
            if "already exists" in str(e).lower():
                print("ℹ️ username column already exists")
            else:
                print(f"⚠️ Could not add username column: {e}")
        
        # Create message_mentions table if it doesn't exist
        try:
            db.session.execute(text("""
                CREATE TABLE IF NOT EXISTS message_mentions (
                    id SERIAL PRIMARY KEY,
                    message_id INTEGER NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE,
                    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE(message_id, user_id)
                )
            """))
            print("✅ Created message_mentions table")
        except Exception as e:
            print(f"⚠️ Could not create message_mentions table: {e}")
        
        # Create meetings table if it doesn't exist
        try:
            db.session.execute(text("""
                CREATE TABLE IF NOT EXISTS meetings (
                    id SERIAL PRIMARY KEY,
                    title VARCHAR(200) NOT NULL,
                    description TEXT,
                    scheduled_at TIMESTAMP NOT NULL,
                    duration_minutes INTEGER DEFAULT 60,
                    location VARCHAR(200),
                    created_by INTEGER REFERENCES users(id),
                    thread_id INTEGER REFERENCES chat_threads(id),
                    reminder_sent BOOLEAN DEFAULT FALSE,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """))
            print("✅ Created meetings table")
        except Exception as e:
            print(f"⚠️ Could not create meetings table: {e}")
        
        # Create meeting_participants table if it doesn't exist
        try:
            db.session.execute(text("""
                CREATE TABLE IF NOT EXISTS meeting_participants (
                    meeting_id INTEGER NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
                    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                    status VARCHAR(20) DEFAULT 'pending',
                    notified_at TIMESTAMP,
                    PRIMARY KEY (meeting_id, user_id)
                )
            """))
            print("✅ Created meeting_participants table")
        except Exception as e:
            print(f"⚠️ Could not create meeting_participants table: {e}")
        
        # Create indexes
        try:
            db.session.execute(text("CREATE INDEX IF NOT EXISTS idx_message_mentions_message_id ON message_mentions(message_id)"))
            db.session.execute(text("CREATE INDEX IF NOT EXISTS idx_message_mentions_user_id ON message_mentions(user_id)"))
            db.session.execute(text("CREATE INDEX IF NOT EXISTS idx_meetings_scheduled_at ON meetings(scheduled_at)"))
            db.session.execute(text("CREATE INDEX IF NOT EXISTS idx_meetings_created_by ON meetings(created_by)"))
            db.session.execute(text("CREATE INDEX IF NOT EXISTS idx_meeting_participants_meeting_id ON meeting_participants(meeting_id)"))
            db.session.execute(text("CREATE INDEX IF NOT EXISTS idx_meeting_participants_user_id ON meeting_participants(user_id)"))
            print("✅ Created indexes")
        except Exception as e:
            print(f"⚠️ Could not create indexes: {e}")
        
        db.session.commit()
        print("✅ Database migration completed successfully!")
        
    except Exception as e:
        db.session.rollback()
        print(f"❌ Migration failed: {e}")
        raise

if __name__ == "__main__":
    upgrade()
