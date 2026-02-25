#!/usr/bin/env python3
"""
Load realistic test packs from realistic_test_packs.json into the database.
Skips any pack that already exists (by name). Run from server directory.
"""
import os
import sys
import json
from datetime import datetime, timezone
from urllib.parse import urlparse

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SERVER_DIR = os.path.dirname(SCRIPT_DIR)
os.chdir(SERVER_DIR)
sys.path.insert(0, SERVER_DIR)

def load_dotenv(path=None):
    path = path or os.path.join(SERVER_DIR, ".env")
    if not os.path.isfile(path):
        return
    with open(path, "r") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                k, v = line.split("=", 1)
                os.environ[k.strip()] = v.strip().strip('"').strip("'")

load_dotenv()
DATABASE_URL = os.environ.get("DATABASE_URL")
if not DATABASE_URL:
    print("ERROR: DATABASE_URL not set in .env")
    sys.exit(1)

parsed = urlparse(DATABASE_URL)
conn_params = {
    "host": parsed.hostname,
    "port": parsed.port or 5432,
    "database": parsed.path.lstrip("/").split("?")[0],
    "user": parsed.username,
    "password": parsed.password,
}
if "sslmode=require" in (parsed.query or "") or (parsed.hostname and "render.com" in parsed.hostname):
    conn_params["sslmode"] = "require"

try:
    import psycopg2
    from psycopg2.extras import Json
except ImportError:
    print("ERROR: psycopg2 required. Run: pip install psycopg2-binary")
    sys.exit(1)

JSON_PATH = os.path.join(SERVER_DIR, "realistic_test_packs.json")

def main():
    if not os.path.isfile(JSON_PATH):
        print(f"ERROR: {JSON_PATH} not found")
        sys.exit(1)

    with open(JSON_PATH, "r", encoding="utf-8") as f:
        packs = json.load(f)

    if not isinstance(packs, list):
        print("ERROR: JSON must be an array of test pack objects")
        sys.exit(1)

    conn = psycopg2.connect(**conn_params)
    cur = conn.cursor()
    now = datetime.now(timezone.utc)
    inserted = 0
    skipped = 0

    for pack in packs:
        name = (pack.get("name") or "").strip()
        if not name:
            print("  Skip: pack with empty name")
            skipped += 1
            continue

        category = (pack.get("category") or "technical").strip().lower()
        if category not in ("technical", "role-specific"):
            category = "technical"
        description = (pack.get("description") or "").strip()
        questions = pack.get("questions")
        if not isinstance(questions, list):
            questions = []

        cur.execute(
            "SELECT id FROM test_packs WHERE name = %s AND deleted_at IS NULL",
            (name,),
        )
        if cur.fetchone():
            print(f"  Skip (already exists): {name}")
            skipped += 1
            continue

        cur.execute(
            """
            INSERT INTO test_packs (name, category, description, questions, created_at, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s)
            """,
            (name, category, description, Json(questions), now, now),
        )
        print(f"  Inserted: {name} ({len(questions)} questions)")
        inserted += 1

    conn.commit()
    cur.close()
    conn.close()
    print(f"\nDone. Inserted: {inserted}, Skipped: {skipped}")

if __name__ == "__main__":
    main()
