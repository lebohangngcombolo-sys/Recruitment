"""
Database migration to add Recruitee webhook logging table
Run: python migrations/add_recruitee_webhook_logs.py
"""

from sqlalchemy import text
from app import create_app, db

app = create_app()


def upgrade():
    """Add recruitee_webhook_logs table for tracking incoming webhooks"""
    
    with app.app_context():
        try:
            # Create recruitee_webhook_logs table
            db.session.execute(text("""
                CREATE TABLE IF NOT EXISTS recruitee_webhook_logs (
                    id SERIAL PRIMARY KEY,
                    event_id VARCHAR(100) UNIQUE NOT NULL,
                    event_type VARCHAR(50) NOT NULL,
                    raw_payload JSONB DEFAULT '{}'::jsonb,
                    processed BOOLEAN DEFAULT FALSE NOT NULL,
                    processing_status VARCHAR(20) DEFAULT 'pending',
                    error_message TEXT,
                    processed_at TIMESTAMP,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """))
            print("✅ Created recruitee_webhook_logs table")
            
            # Create indexes
            indexes = [
                "idx_recruitee_webhook_logs_event_id",
                "idx_recruitee_webhook_logs_event_type",
                "idx_recruitee_webhook_logs_created_at"
            ]
            
            # Map index names to correct column names
            index_columns = {
                'idx_recruitee_webhook_logs_event_id': 'event_id',
                'idx_recruitee_webhook_logs_event_type': 'event_type',
                'idx_recruitee_webhook_logs_created_at': 'created_at'
            }
            
            for idx_name, col_name in index_columns.items():
                try:
                    db.session.execute(
                        text(f"CREATE INDEX IF NOT EXISTS {idx_name} ON recruitee_webhook_logs({col_name})")
                    )
                    print(f"✅ Created index {idx_name}")
                except Exception as e:
                    print(f"⚠️ Could not create index {idx_name}: {e}")
            
            db.session.commit()
            print("\n✅ Recruitee webhook logging migration completed successfully!")
            
        except Exception as e:
            db.session.rollback()
            print(f"\n❌ Migration failed: {e}")
            raise


def downgrade():
    """Remove recruitee_webhook_logs table"""
    
    with app.app_context():
        try:
            # Drop indexes first
            indexes = [
                "idx_recruitee_webhook_logs_event_id",
                "idx_recruitee_webhook_logs_event_type",
                "idx_recruitee_webhook_logs_created_at"
            ]
            
            for idx_name in indexes:
                try:
                    db.session.execute(text(f"DROP INDEX IF EXISTS {idx_name}"))
                    print(f"✅ Dropped index {idx_name}")
                except Exception as e:
                    print(f"⚠️ Could not drop index {idx_name}: {e}")
            
            # Drop table
            db.session.execute(text("DROP TABLE IF EXISTS recruitee_webhook_logs"))
            print("✅ Dropped recruitee_webhook_logs table")
            
            db.session.commit()
            print("\n✅ Recruitee webhook logging table removed")
            
        except Exception as e:
            db.session.rollback()
            print(f"\n❌ Downgrade failed: {e}")
            raise


if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1 and sys.argv[1] == "downgrade":
        print("Running downgrade...")
        downgrade()
    else:
        print("Running upgrade...")
        upgrade()
