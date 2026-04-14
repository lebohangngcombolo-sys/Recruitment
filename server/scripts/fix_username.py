import os
import psycopg2
from dotenv import load_dotenv

load_dotenv()
url = os.getenv('DATABASE_URL')
print(f"Connecting to: {url.split('@')[-1]}")

try:
    conn = psycopg2.connect(url)
    conn.autocommit = False # Explicitly manage transaction
    cur = conn.cursor()
    
    print("Executing ALTER TABLE...")
    cur.execute("ALTER TABLE users ADD COLUMN username VARCHAR(50) UNIQUE;")
    
    print("Committing transaction...")
    conn.commit()
    print("✅ Successfully added username column!")
    
    cur.close()
    conn.close()
except Exception as e:
    print(f"❌ Error: {e}")
    if 'conn' in locals():
        conn.rollback()
