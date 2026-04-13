"""
Database migration to add Recruitee ATS integration fields
Run: python migrations/add_recruitee_integration.py
"""

from sqlalchemy import text
from app import create_app, db

app = create_app()


def upgrade():
    """Add Recruitee integration columns to requisitions and candidates tables"""
    
    with app.app_context():
        try:
            # Add columns to requisitions table
            columns_to_add = [
                ("recruitee_id", "VARCHAR(100)"),
                ("sync_to_recruitee", "BOOLEAN DEFAULT FALSE"),
                ("last_synced_at", "TIMESTAMP"),
                ("last_synced_source", "VARCHAR(20)"),
            ]
            
            for col_name, col_type in columns_to_add:
                try:
                    db.session.execute(
                        text(f"ALTER TABLE requisitions ADD COLUMN {col_name} {col_type}")
                    )
                    print(f"✅ Added {col_name} to requisitions table")
                except Exception as e:
                    if "already exists" in str(e).lower():
                        print(f"ℹ️ {col_name} already exists in requisitions")
                    else:
                        print(f"⚠️ Could not add {col_name}: {e}")
            
            # Add columns to candidates table
            for col_name, col_type in columns_to_add:
                try:
                    db.session.execute(
                        text(f"ALTER TABLE candidates ADD COLUMN {col_name} {col_type}")
                    )
                    print(f"✅ Added {col_name} to candidates table")
                except Exception as e:
                    if "already exists" in str(e).lower():
                        print(f"ℹ️ {col_name} already exists in candidates")
                    else:
                        print(f"⚠️ Could not add {col_name}: {e}")
            
            # Create indexes for performance
            indexes = [
                ("requisitions", "idx_requisitions_recruitee_id", "recruitee_id"),
                ("candidates", "idx_candidates_recruitee_id", "recruitee_id"),
                ("requisitions", "idx_requisitions_sync_flag", "sync_to_recruitee"),
                ("candidates", "idx_candidates_sync_flag", "sync_to_recruitee"),
            ]
            
            for table, idx_name, col_name in indexes:
                try:
                    db.session.execute(
                        text(f"CREATE INDEX IF NOT EXISTS {idx_name} ON {table}({col_name})")
                    )
                    print(f"✅ Created index {idx_name}")
                except Exception as e:
                    print(f"⚠️ Could not create index {idx_name}: {e}")
            
            db.session.commit()
            print("\n✅ Recruitee integration migration completed successfully!")
            print("\nNext steps:")
            print("1. Add RECRUITEE_API_TOKEN to your .env file")
            print("2. Set RECRUITEE_ENABLED=true to enable the integration")
            print("3. Run the app and test connection via /api/admin/integrations/recruitee/status")
            
        except Exception as e:
            db.session.rollback()
            print(f"\n❌ Migration failed: {e}")
            raise


def downgrade():
    """Remove Recruitee integration columns"""
    
    with app.app_context():
        try:
            columns_to_remove = [
                "recruitee_id",
                "sync_to_recruitee", 
                "last_synced_at",
                "last_synced_source",
            ]
            
            for col_name in columns_to_remove:
                try:
                    db.session.execute(
                        text(f"ALTER TABLE requisitions DROP COLUMN IF EXISTS {col_name}")
                    )
                    db.session.execute(
                        text(f"ALTER TABLE candidates DROP COLUMN IF EXISTS {col_name}")
                    )
                    print(f"✅ Removed {col_name}")
                except Exception as e:
                    print(f"⚠️ Could not remove {col_name}: {e}")
            
            # Drop indexes
            indexes = [
                "idx_requisitions_recruitee_id",
                "idx_candidates_recruitee_id",
                "idx_requisitions_sync_flag",
                "idx_candidates_sync_flag",
            ]
            
            for idx_name in indexes:
                try:
                    db.session.execute(text(f"DROP INDEX IF EXISTS {idx_name}"))
                    print(f"✅ Dropped index {idx_name}")
                except Exception as e:
                    print(f"⚠️ Could not drop index {idx_name}: {e}")
            
            db.session.commit()
            print("\n✅ Recruitee integration columns removed")
            
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
