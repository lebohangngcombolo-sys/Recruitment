#!/usr/bin/env python3
"""
Setup CV Analyser Database
Creates the cv_analyser schema and cv_analyses table in the analyser database.
"""
import os
from dotenv import load_dotenv
import psycopg2
from psycopg2 import sql

# Load environment variables
_server_dir = os.path.dirname(os.path.abspath(__file__))
_env_path = os.path.join(_server_dir, ".env")
load_dotenv(_env_path)

def setup_analyser_database():
    analyser_db_url = os.getenv('ANALYSER_DATABASE_URL')
    if not analyser_db_url:
        print("ANALYSER_DATABASE_URL not set in .env")
        return False

    print(f"Setting up analyser database: {analyser_db_url.split('@')[-1]}")

    try:
        # Connect to analyser database
        conn = psycopg2.connect(analyser_db_url)
        conn.autocommit = True
        cur = conn.cursor()

        # Create cv_analyser schema if it doesn't exist
        cur.execute("CREATE SCHEMA IF NOT EXISTS cv_analyser")
        print("✅ Created cv_analyser schema")

        # Create cv_records table
        create_cv_records_query = """
        CREATE TABLE IF NOT EXISTS cv_analyser.cv_records (
            id VARCHAR(36) PRIMARY KEY,
            cv_text TEXT NOT NULL,
            status VARCHAR(20) NOT NULL DEFAULT 'pending',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """
        cur.execute(create_cv_records_query)
        print("✅ Created cv_records table")

        # Create cv_analyses table
        create_table_query = """
        CREATE TABLE IF NOT EXISTS cv_analyser.cv_analyses (
            id SERIAL PRIMARY KEY,
            record_id VARCHAR(36) REFERENCES cv_analyser.cv_records(id),
            candidate_id INTEGER,
            application_id INTEGER,
            requisition_id INTEGER,
            job_description TEXT,
            cv_text TEXT,
            result JSONB DEFAULT '{}',
            status VARCHAR(20) DEFAULT 'pending',
            started_at TIMESTAMP,
            finished_at TIMESTAMP,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """
        cur.execute(create_table_query)
        print("✅ Created cv_analyses table (if not exists)")

        # Ensure cv_analyses required columns exist
        required_columns = [
            ("candidate_id", "INTEGER"),
            ("application_id", "INTEGER"),
            ("requisition_id", "INTEGER"),
            ("job_description", "TEXT"),
            ("cv_text", "TEXT"),
            ("result", "JSONB DEFAULT '{}'"),
            ("status", "VARCHAR(20) DEFAULT 'pending'"),
            ("started_at", "TIMESTAMP"),
            ("finished_at", "TIMESTAMP"),
            ("created_at", "TIMESTAMP DEFAULT CURRENT_TIMESTAMP"),
            ("updated_at", "TIMESTAMP DEFAULT CURRENT_TIMESTAMP"),
            ("external_analysis_id", "VARCHAR(255)")
        ]

        for column_name, column_type in required_columns:
            cur.execute(f"ALTER TABLE cv_analyser.cv_analyses ADD COLUMN IF NOT EXISTS {column_name} {column_type}")

        print("✅ Ensured cv_analyses required columns exist")

        # Create indexes
        indexes = [
            "CREATE INDEX IF NOT EXISTS ix_cv_analyses_external_analysis_id ON cv_analyser.cv_analyses (external_analysis_id)",
            "CREATE INDEX IF NOT EXISTS ix_cv_analyses_status ON cv_analyser.cv_analyses (status)",
            "CREATE INDEX IF NOT EXISTS ix_cv_analyses_candidate_id ON cv_analyser.cv_analyses (candidate_id)"
        ]

        for index_query in indexes:
            cur.execute(index_query)
        print("✅ Created indexes")

        # Verify tables exist
        cur.execute("""
            SELECT EXISTS (
                SELECT 1 FROM information_schema.tables
                WHERE table_schema = 'cv_analyser'
                AND table_name = 'cv_records'
            )
        """)
        records_result = cur.fetchone()
        print(f"✅ Table verification: cv_records exists = {records_result[0]}")

        cur.execute("""
            SELECT EXISTS (
                SELECT 1 FROM information_schema.tables
                WHERE table_schema = 'cv_analyser'
                AND table_name = 'cv_analyses'
            )
        """)
        analyses_result = cur.fetchone()
        print(f"✅ Table verification: cv_analyses exists = {analyses_result[0]}")

        cur.close()
        conn.close()

        print("🎉 Analyser database setup complete!")
        return True

    except Exception as e:
        print(f"❌ Error setting up analyser database: {e}")
        return False

if __name__ == "__main__":
    success = setup_analyser_database()
    exit(0 if success else 1)