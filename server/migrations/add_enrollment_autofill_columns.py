"""
Migration: Add enrollment autofill columns to candidates table

This migration adds individual columns for frequently accessed enrollment fields
to make the autofill process easier and enable database-level validation.

Run with: python migrations/add_enrollment_autofill_columns.py
"""

import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import create_app
from app.extensions import db

def migrate():
    """Add new columns to candidates table."""
    app = create_app()
    
    with app.app_context():
        from sqlalchemy import text
        
        # Check if columns already exist
        inspector = db.inspect(db.engine)
        existing_columns = {col['name'] for col in inspector.get_columns('candidates')}
        
        new_columns = []
        
        # Define new columns to add
        columns_to_add = [
            ('education_level', 'VARCHAR(100)'),
            ('university', 'VARCHAR(150)'),
            ('graduation_year', 'VARCHAR(4)'),
            ('previous_companies', 'TEXT'),
            ('experience_summary', 'TEXT'),
        ]
        
        for col_name, col_type in columns_to_add:
            if col_name not in existing_columns:
                new_columns.append((col_name, col_type))
        
        if not new_columns:
            print("✅ All columns already exist. No migration needed.")
            return
        
        print(f"Adding {len(new_columns)} new columns to candidates table...")
        
        # Add columns using raw SQL (PostgreSQL compatible)
        for col_name, col_type in new_columns:
            try:
                sql = f'ALTER TABLE candidates ADD COLUMN IF NOT EXISTS {col_name} {col_type}'
                db.session.execute(text(sql))
                print(f"  ✅ Added {col_name} ({col_type})")
            except Exception as e:
                print(f"  ❌ Failed to add {col_name}: {e}")
                db.session.rollback()
                return
        
        db.session.commit()
        print(f"\n🎉 Migration completed successfully!")
        print(f"   Added columns: {', '.join([c[0] for c in new_columns])}")
        
        # Show current columns
        print("\n📋 Current candidates table columns:")
        all_columns = inspector.get_columns('candidates')
        for col in all_columns:
            print(f"   - {col['name']}: {col['type']}")


def rollback():
    """Rollback: Remove the new columns."""
    app = create_app()
    
    with app.app_context():
        from sqlalchemy import text
        
        columns_to_remove = [
            'education_level',
            'university', 
            'graduation_year',
            'previous_companies',
            'experience_summary',
        ]
        
        print(f"Removing columns from candidates table...")
        
        for col_name in columns_to_remove:
            try:
                sql = f'ALTER TABLE candidates DROP COLUMN IF EXISTS {col_name}'
                db.session.execute(text(sql))
                print(f"  ✅ Dropped {col_name}")
            except Exception as e:
                print(f"  ❌ Failed to drop {col_name}: {e}")
                db.session.rollback()
                return
        
        db.session.commit()
        print(f"\n🎉 Rollback completed!")


if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(description='Migration for enrollment autofill columns')
    parser.add_argument('--rollback', action='store_true', help='Rollback the migration')
    args = parser.parse_args()
    
    if args.rollback:
        rollback()
    else:
        migrate()
