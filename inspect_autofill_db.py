
import os
import sys
from sqlalchemy import create_engine, inspect

# Force UTF-8 for output
if sys.stdout.encoding != 'utf-8':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

DATABASE_URL = "postgresql://recruitement_deploy_user:tHkpCaJ8nxQpN1tCItF7BEXNvzLrkgiQ@dpg-d62tb67pm1nc738h8jv0-a.oregon-postgres.render.com/recruitement_deploy?sslmode=require"

def inspect_autofill_tables():
    output = []
    output.append(f"🔍 Inspecting Database: {DATABASE_URL.split('/')[-1].split('?')[0]}")
    output.append("=" * 60)
    
    try:
        engine = create_engine(DATABASE_URL)
        inspector = inspect(engine)
        
        tables = inspector.get_table_names()
        output.append(f"✅ Found {len(tables)} tables.\n")
        
        target_keywords = ["autofill", "profile", "resume", "cv", "candidate", "experience", "education", "skill", "user"]
        
        for table in sorted(tables):
            if any(kw in table.lower() for kw in target_keywords):
                output.append(f"📦 TABLE: {table}")
                columns = inspector.get_columns(table)
                for col in columns:
                    output.append(f"   - {col['name']} ({col['type']})")
                output.append("-" * 30)
                
    except Exception as e:
        output.append(f"❌ Connection Failed: {e}")

    # Write to file with explicit encoding
    with open("db_schema.txt", "w", encoding="utf-8") as f:
        f.write("\n".join(output))
    
    print("\n".join(output))

if __name__ == "__main__":
    inspect_autofill_tables()
