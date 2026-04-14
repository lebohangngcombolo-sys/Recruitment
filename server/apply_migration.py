import psycopg2
import os

def apply_fix():
    db_url = 'postgresql://recruiter:zhubXkTYjieGoYevXB7jtHj5EdhNYmV7@dpg-d6v72fchg0os73ddre00-a.oregon-postgres.render.com/analyser_w2n9?sslmode=require'
    print(f"Connecting to {db_url}...")
    try:
        conn = psycopg2.connect(db_url)
        cursor = conn.cursor()
        
        print("🔧 Applying schema fixes to cv_analyser.cv_records...")
        
        # 1. Add file_path
        cursor.execute("ALTER TABLE cv_analyser.cv_records ADD COLUMN IF NOT EXISTS file_path TEXT")
        print("  - Added file_path")
        
        # 2. Add file_extension
        cursor.execute("ALTER TABLE cv_analyser.cv_records ADD COLUMN IF NOT EXISTS file_extension TEXT")
        print("  - Added file_extension")
        
        # 3. Make cv_text nullable
        cursor.execute("ALTER TABLE cv_analyser.cv_records ALTER COLUMN cv_text DROP NOT NULL")
        print("  - Made cv_text nullable")
        
        conn.commit()
        print("✅ Schema migration completed successfully!")
        
        conn.close()
    except Exception as e:
        print(f"❌ Error: {e}")
        if 'conn' in locals():
            conn.rollback()

if __name__ == "__main__":
    apply_fix()
