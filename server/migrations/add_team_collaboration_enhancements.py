"""
Database migration for team collaboration enhancements
Adds support for @mentions and meeting scheduling
"""

def upgrade():
    """Add new tables and fields for enhanced team collaboration"""
    
    # Add username field to users table
    from app import db
    from sqlalchemy import text
    
    try:
        # Add username column to users table
        db.session.execute(text("""
            ALTER TABLE users ADD COLUMN username VARCHAR(50) UNIQUE
        """))
        
        # Create message_mentions table
        db.session.execute(text("""
            CREATE TABLE IF NOT EXISTS message_mentions (
                id SERIAL PRIMARY KEY,
                message_id INTEGER NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE,
                user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(message_id, user_id)
            )
        """))
        
        # Create meetings table
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
        
        # Create meeting_participants association table
        db.session.execute(text("""
            CREATE TABLE IF NOT EXISTS meeting_participants (
                meeting_id INTEGER NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
                user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                status VARCHAR(20) DEFAULT 'pending',
                notified_at TIMESTAMP,
                PRIMARY KEY (meeting_id, user_id)
            )
        """))
        
        # Create indexes for better performance
        db.session.execute(text("""
            CREATE INDEX IF NOT EXISTS idx_message_mentions_message_id 
            ON message_mentions(message_id)
        """))
        
        db.session.execute(text("""
            CREATE INDEX IF NOT EXISTS idx_message_mentions_user_id 
            ON message_mentions(user_id)
        """))
        
        db.session.execute(text("""
            CREATE INDEX IF NOT EXISTS idx_meetings_scheduled_at 
            ON meetings(scheduled_at)
        """))
        
        db.session.execute(text("""
            CREATE INDEX IF NOT EXISTS idx_meetings_created_by 
            ON meetings(created_by)
        """))
        
        db.session.execute(text("""
            CREATE INDEX IF NOT EXISTS idx_meeting_participants_meeting_id 
            ON meeting_participants(meeting_id)
        """))
        
        db.session.execute(text("""
            CREATE INDEX IF NOT EXISTS idx_meeting_participants_user_id 
            ON meeting_participants(user_id)
        """))
        
        # Create trigger to update updated_at timestamp
        db.session.execute(text("""
            CREATE OR REPLACE FUNCTION update_meetings_updated_at()
            RETURNS TRIGGER AS $$
            BEGIN
                NEW.updated_at = CURRENT_TIMESTAMP;
                RETURN NEW;
            END;
            $$ language 'plpgsql';
        """))
        
        db.session.execute(text("""
            CREATE TRIGGER meetings_updated_at_trigger 
                BEFORE UPDATE ON meetings 
                FOR EACH ROW 
                EXECUTE FUNCTION update_meetings_updated_at()
        """))
        
        db.session.commit()
        print("✅ Database migration completed successfully!")
        
    except Exception as e:
        db.session.rollback()
        print(f"❌ Migration failed: {e}")
        raise


def downgrade():
    """Remove the new tables and fields"""
    
    from app import db
    from sqlalchemy import text
    
    try:
        # Drop indexes
        db.session.execute(text("DROP INDEX IF EXISTS idx_meeting_participants_user_id"))
        db.session.execute(text("DROP INDEX IF EXISTS idx_meeting_participants_meeting_id"))
        db.session.execute(text("DROP INDEX IF EXISTS idx_meetings_created_by"))
        db.session.execute(text("DROP INDEX IF EXISTS idx_meetings_scheduled_at"))
        db.session.execute(text("DROP INDEX IF EXISTS idx_message_mentions_user_id"))
        db.session.execute(text("DROP INDEX IF EXISTS idx_message_mentions_message_id"))
        
        # Drop tables
        db.session.execute(text("DROP TABLE IF EXISTS meeting_participants"))
        db.session.execute(text("DROP TABLE IF EXISTS meetings"))
        db.session.execute(text("DROP TABLE IF EXISTS message_mentions"))
        
        # Drop trigger and function
        db.session.execute(text("DROP TRIGGER IF EXISTS meetings_updated_at_trigger ON meetings"))
        db.session.execute(text("DROP FUNCTION IF EXISTS update_meetings_updated_at()"))
        
        # Drop username column from users table
        db.session.execute(text("ALTER TABLE users DROP COLUMN IF EXISTS username"))
        
        db.session.commit()
        print("✅ Database rollback completed successfully!")
        
    except Exception as e:
        db.session.rollback()
        print(f"❌ Rollback failed: {e}")
        raise


if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1 and sys.argv[1] == "downgrade":
        downgrade()
    else:
        upgrade()
