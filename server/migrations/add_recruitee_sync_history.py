"""
Migration: Add Recruitee sync history table for audit tracking
Run: python migrations/add_recruitee_sync_history.py
"""

from sqlalchemy import text
from app import create_app, db

app = create_app()


def upgrade():
    """Create sync history table"""
    
    with app.app_context():
        try:
            # Create sync history table
            db.session.execute(text("""
                CREATE TABLE IF NOT EXISTS recruitee_sync_history (
                    id SERIAL PRIMARY KEY,
                    entity_type VARCHAR(20) NOT NULL,  -- 'job' or 'candidate'
                    entity_id INTEGER NOT NULL,        -- local requisition_id or candidate_id
                    recruitee_id VARCHAR(100),         -- Recruitee's ID
                    action VARCHAR(20) NOT NULL,       -- 'create', 'update', 'delete', 'retry'
                    status VARCHAR(20) NOT NULL,     -- 'success', 'failed', 'pending', 'skipped'
                    error_message TEXT,                -- error details if failed
                    retry_count INTEGER DEFAULT 0,     -- number of retry attempts
                    max_retries INTEGER DEFAULT 3,   -- max retry attempts allowed
                    next_retry_at TIMESTAMP,           -- scheduled retry time
                    request_data JSONB,                -- data sent to Recruitee
                    response_data JSONB,               -- response from Recruitee
                    synced_by INTEGER REFERENCES users(id),  -- admin who triggered sync
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    completed_at TIMESTAMP             -- when sync completed
                )
            """))
            print("✅ Created recruitee_sync_history table")
            
            # Create indexes for performance
            indexes = [
                "CREATE INDEX IF NOT EXISTS idx_sync_history_entity ON recruitee_sync_history(entity_type, entity_id)",
                "CREATE INDEX IF NOT EXISTS idx_sync_history_status ON recruitee_sync_history(status)",
                "CREATE INDEX IF NOT EXISTS idx_sync_history_retry ON recruitee_sync_history(status, next_retry_at)",
                "CREATE INDEX IF NOT EXISTS idx_sync_history_created ON recruitee_sync_history(created_at DESC)",
            ]
            
            for idx_sql in indexes:
                db.session.execute(text(idx_sql))
            print("✅ Created sync history indexes")
            
            db.session.commit()
            print("\n✅ Sync history migration completed!")
            
        except Exception as e:
            db.session.rollback()
            print(f"\n❌ Migration failed: {e}")
            raise


def downgrade():
    """Remove sync history table"""
    
    with app.app_context():
        try:
            db.session.execute(text("DROP TABLE IF EXISTS recruitee_sync_history"))
            db.session.commit()
            print("✅ Sync history table removed")
        except Exception as e:
            db.session.rollback()
            print(f"❌ Downgrade failed: {e}")
            raise


if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1 and sys.argv[1] == "downgrade":
        print("Running downgrade...")
        downgrade()
    else:
        print("Running upgrade...")
        upgrade()
