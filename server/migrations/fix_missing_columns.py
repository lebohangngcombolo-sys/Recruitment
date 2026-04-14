#!/usr/bin/env python3

import os
import sys
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import create_app, db
from sqlalchemy import inspect, text

def add_column_if_not_exists(table_name, column_name, column_type):
    """Add a column to a table if it does not already exist."""
    try:
        inspector = inspect(db.engine)
        columns = [col['name'] for col in inspector.get_columns(table_name)]
        if column_name not in columns:
            print(f"✅ Adding column {column_name} to {table_name}")
            db.session.execute(text(f"ALTER TABLE {table_name} ADD COLUMN {column_name} {column_type}"))
            db.session.commit()
        else:
            print(f"ℹ️ Column {column_name} already exists in {table_name}")
    except Exception as e:
        print(f"❌ Error with column {column_name} in {table_name}: {e}")
        db.session.rollback()

def check_table_exists(table_name):
    """Check if a table exists."""
    try:
        inspector = inspect(db.engine)
        tables = inspector.get_table_names()
        return table_name in tables
    except:
        return False

def create_table_if_not_exists(table_name, create_sql):
    """Create a table if it doesn't exist."""
    if not check_table_exists(table_name):
        print(f"✅ Creating table {table_name}")
        db.session.execute(text(create_sql))
        db.session.commit()
    else:
        print(f"ℹ️ Table {table_name} already exists")

def upgrade():
    app = create_app()
    with app.app_context():
        print("🔧 Starting database migration...")
        
        # 1. Fix user_presence table - add missing id column
        if check_table_exists('user_presence'):
            # Check if it has an id column
            try:
                inspector = inspect(db.engine)
                columns = [col['name'] for col in inspector.get_columns('user_presence')]
                if 'id' not in columns:
                    print("✅ Adding id column to user_presence table")
                    # For PostgreSQL, we need to handle this carefully
                    db.session.execute(text("""
                        ALTER TABLE user_presence 
                        ADD COLUMN id SERIAL PRIMARY KEY
                    """))
                    db.session.commit()
                else:
                    print("ℹ️ user_presence.id already exists")
            except Exception as e:
                print(f"⚠️ Could not add id to user_presence: {e}")
                # Try alternative approach
                try:
                    db.session.execute(text("ALTER TABLE user_presence ADD COLUMN id SERIAL"))
                    db.session.commit()
                    print("✅ Added id column (SERIAL) to user_presence")
                except:
                    print("⚠️ Could not add id column, table might already have it")
        else:
            # Create user_presence table
            create_table_if_not_exists('user_presence', """
                CREATE TABLE user_presence (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER NOT NULL REFERENCES users(id),
                    status VARCHAR(20) DEFAULT 'offline',
                    last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    socket_id VARCHAR(100),
                    is_typing BOOLEAN DEFAULT FALSE,
                    typing_in_thread INTEGER
                )
            """)
        
        # 2. Fix meetings table - add missing columns
        if check_table_exists('meetings'):
            add_column_if_not_exists('meetings', 'scheduled_at', 'TIMESTAMP')
            add_column_if_not_exists('meetings', 'location', 'VARCHAR(200)')
            add_column_if_not_exists('meetings', 'duration_minutes', 'INTEGER DEFAULT 60')
            add_column_if_not_exists('meetings', 'cancelled', 'BOOLEAN DEFAULT FALSE')
            add_column_if_not_exists('meetings', 'cancelled_at', 'TIMESTAMP')
            add_column_if_not_exists('meetings', 'cancelled_by', 'INTEGER')
            add_column_if_not_exists('meetings', 'reminder_sent', 'BOOLEAN DEFAULT FALSE')
        else:
            # Create meetings table
            create_table_if_not_exists('meetings', """
                CREATE TABLE meetings (
                    id SERIAL PRIMARY KEY,
                    title VARCHAR(200) NOT NULL,
                    description TEXT,
                    created_by INTEGER NOT NULL REFERENCES users(id),
                    scheduled_at TIMESTAMP NOT NULL,
                    location VARCHAR(200),
                    duration_minutes INTEGER DEFAULT 60,
                    cancelled BOOLEAN DEFAULT FALSE,
                    cancelled_at TIMESTAMP,
                    cancelled_by INTEGER REFERENCES users(id),
                    reminder_sent BOOLEAN DEFAULT FALSE,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
        
        # 3. Create meeting_participants table if missing
        create_table_if_not_exists('meeting_participants', """
            CREATE TABLE meeting_participants (
                id SERIAL PRIMARY KEY,
                meeting_id INTEGER NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
                user_id INTEGER NOT NULL REFERENCES users(id),
                status VARCHAR(20) DEFAULT 'pending',
                responded_at TIMESTAMP,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(meeting_id, user_id)
            )
        """)
        
        # 4. Create message_mentions table if missing
        create_table_if_not_exists('message_mentions', """
            CREATE TABLE message_mentions (
                id SERIAL PRIMARY KEY,
                message_id INTEGER NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE,
                mentioned_user_id INTEGER NOT NULL REFERENCES users(id),
                mentioned_by_user_id INTEGER NOT NULL REFERENCES users(id),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        # 5. Create chat_messages table if missing (for completeness)
        if not check_table_exists('chat_messages'):
            create_table_if_not_exists('chat_messages', """
                CREATE TABLE chat_messages (
                    id SERIAL PRIMARY KEY,
                    thread_id INTEGER NOT NULL REFERENCES chat_threads(id) ON DELETE CASCADE,
                    sender_id INTEGER NOT NULL REFERENCES users(id),
                    content TEXT NOT NULL,
                    message_type VARCHAR(20) DEFAULT 'text',
                    edited_at TIMESTAMP,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
        
        # 6. Create chat_threads table if missing
        if not check_table_exists('chat_threads'):
            create_table_if_not_exists('chat_threads', """
                CREATE TABLE chat_threads (
                    id SERIAL PRIMARY KEY,
                    title VARCHAR(200) NOT NULL,
                    entity_type VARCHAR(50) DEFAULT 'general',
                    entity_id VARCHAR(50),
                    created_by INTEGER NOT NULL REFERENCES users(id),
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
        
        print("✅ Migration completed successfully!")

if __name__ == "__main__":
    upgrade()
