#!/usr/bin/env python3
import os
from dotenv import load_dotenv
import psycopg2

# Load environment variables
_server_dir = os.path.dirname(os.path.abspath(__file__))
_env_path = os.path.join(_server_dir, ".env")
load_dotenv(_env_path)

# Get database URLs
main_db_url = os.getenv('DATABASE_URL')
analyser_db_url = os.getenv('ANALYSER_DATABASE_URL')

print(f"Main DB URL: {main_db_url}")
print(f"Analyser DB URL: {analyser_db_url}")

# Check main database
try:
    if main_db_url:
        conn = psycopg2.connect(main_db_url)
        cur = conn.cursor()
        cur.execute("""
            SELECT EXISTS (
                SELECT 1 FROM information_schema.tables
                WHERE table_schema = 'public'
                AND table_name = 'candidates'
            )
        """)
        result = cur.fetchone()
        print("Main DB - candidates table exists:", result[0])
        cur.close()
        conn.close()
except Exception as e:
    print("Main DB Error:", e)

# Check analyser database
try:
    if analyser_db_url:
        conn = psycopg2.connect(analyser_db_url)
        cur = conn.cursor()
        cur.execute("""
            SELECT EXISTS (
                SELECT 1 FROM information_schema.tables
                WHERE table_schema = 'cv_analyser'
                AND table_name = 'cv_analyses'
            )
        """)
        result = cur.fetchone()
        print("Analyser DB - cv_analyses table exists:", result[0])
        cur.close()
        conn.close()
except Exception as e:
    print("Analyser DB Error:", e)