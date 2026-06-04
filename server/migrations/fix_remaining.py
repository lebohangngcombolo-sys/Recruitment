#!/usr/bin/env python3

import os
import sys
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import create_app, db
from sqlalchemy import text

def fix_remaining_issues():
    app = create_app()
    with app.app_context():
        print("🔧 Fixing remaining database issues...")
        
        try:
            # Check if meetings.scheduled_at exists
            result = db.session.execute(text("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name = 'meetings' AND column_name = 'scheduled_at'
            """))
            
            if not result.fetchone():
                print("✅ Adding scheduled_at column to meetings")
                db.session.execute(text("ALTER TABLE meetings ADD COLUMN scheduled_at TIMESTAMP"))
                db.session.commit()
            else:
                print("ℹ️ meetings.scheduled_at already exists")
                
        except Exception as e:
            print(f"⚠️ Error with scheduled_at: {e}")
            db.session.rollback()
        
        try:
            # Check user_presence table structure
            result = db.session.execute(text("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name = 'user_presence' AND column_name = 'id'
            """))
            
            if not result.fetchone():
                print("⚠️ user_presence.id missing - trying to add...")
                # If table doesn't have id, we need to recreate it
                db.session.execute(text("DROP TABLE IF EXISTS user_presence"))
                db.session.execute(text("""
                    CREATE TABLE user_presence (
                        id SERIAL PRIMARY KEY,
                        user_id INTEGER NOT NULL REFERENCES users(id),
                        status VARCHAR(20) DEFAULT 'offline',
                        last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        socket_id VARCHAR(100),
                        is_typing BOOLEAN DEFAULT FALSE,
                        typing_in_thread INTEGER
                    )
                """))
                db.session.commit()
                print("✅ Recreated user_presence table with id column")
            else:
                print("ℹ️ user_presence.id exists")
                
        except Exception as e:
            print(f"⚠️ Error with user_presence: {e}")
            db.session.rollback()
        
        print("✅ Fixed remaining issues!")

if __name__ == "__main__":
    fix_remaining_issues()
