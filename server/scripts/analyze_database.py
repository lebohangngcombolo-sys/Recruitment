#!/usr/bin/env python3
"""Analyze the recruitment database: tables, row counts, users, and schema readiness.

Uses DATABASE_URL from server/.env, or pass the URL as the first argument.

  python scripts/analyze_database.py
  python scripts/analyze_database.py "postgresql://user:pass@host/db?sslmode=require"
"""
import os
import sys

SERVER_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, SERVER_DIR)
os.chdir(SERVER_DIR)

_env_path = os.path.join(SERVER_DIR, ".env")
if os.path.isfile(_env_path):
    from dotenv import load_dotenv
    load_dotenv(_env_path)

# Optional: override from command line
if len(sys.argv) >= 2:
    os.environ["DATABASE_URL"] = sys.argv[1].strip()

URL = os.environ.get("DATABASE_URL")
if not URL or not URL.strip():
    print("ERROR: DATABASE_URL not set. Set in server/.env or pass as first argument.")
    sys.exit(1)
URL = URL.strip()
if "postgresql" in URL and "sslmode=" not in URL:
    URL += "&sslmode=require" if "?" in URL else "?sslmode=require"

def main():
    import psycopg2
    from psycopg2 import sql

    print("=" * 60)
    print("DATABASE ANALYSIS")
    print("=" * 60)
    # Mask password in display
    from urllib.parse import urlparse, urlunparse
    p = urlparse(URL)
    if p.password:
        netloc = p.hostname or ""
        if p.port:
            netloc += f":{p.port}"
        if p.username:
            display_url = urlunparse((p.scheme, f"{p.username}:****@{netloc}", p.path or "", "", p.query or "", ""))
        else:
            display_url = URL
    else:
        display_url = URL
    print(f"URL: {display_url}")
    print()

    conn = psycopg2.connect(URL)
    conn.autocommit = True
    cur = conn.cursor()

    # 1) List all tables and row counts
    cur.execute("""
        SELECT tablename FROM pg_tables
        WHERE schemaname = 'public'
        ORDER BY tablename
    """)
    tables = [r[0] for r in cur.fetchall()]
    print("TABLES AND ROW COUNTS")
    print("-" * 40)
    for t in tables:
        try:
            cur.execute(sql.SQL("SELECT COUNT(*) FROM {}").format(sql.Identifier(t)))
            n = cur.fetchone()[0]
            print(f"  {t}: {n}")
        except Exception as e:
            print(f"  {t}: ERROR - {e}")
    print()

    # 2) Alembic version (migrations)
    if "alembic_version" in tables:
        cur.execute("SELECT version_num FROM alembic_version")
        rows = cur.fetchall()
        print("MIGRATIONS (alembic_version)")
        print("-" * 40)
        for r in rows:
            print(f"  current: {r[0]}")
        print()
    else:
        print("MIGRATIONS: alembic_version table not found (run: flask db upgrade)")
        print()

    # 3) Users table: columns and sample
    if "users" not in tables:
        print("USERS: table 'users' not found. Run migrations.")
        cur.close()
        conn.close()
        return

    cur.execute("""
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'users'
        ORDER BY ordinal_position
    """)
    col_rows = cur.fetchall()
    columns = [r[0] for r in col_rows]
    print("USERS TABLE COLUMNS")
    print("-" * 40)
    for row in col_rows:
        print(f"  {row[0]}: {row[1]} (nullable={row[2]})")

    required_for_login = ["email", "password", "role", "is_verified", "is_active", "last_login_at"]
    missing = [c for c in required_for_login if c not in columns]
    if missing:
        print(f"\n  WARNING: Missing columns required by app: {missing}")
        print("  Run: flask db upgrade")
    print()

    # 4) List users (id, email, role, is_verified, is_active, password set?)
    cur.execute("""
        SELECT id, email, role,
               COALESCE(is_verified, false) AS is_verified,
               COALESCE(is_active, true) AS is_active,
               LENGTH(COALESCE(password, '')) AS pwd_len,
               COALESCE(mfa_enabled, false) AS mfa_enabled
        FROM users
        ORDER BY id
    """)
    rows = cur.fetchall()
    print("USERS (login readiness)")
    print("-" * 40)
    if not rows:
        print("  No users. Create with: python scripts/ensure_local_test_users.py")
    else:
        for r in rows:
            uid, email, role, is_verified, is_active, pwd_len, mfa_enabled = r
            can_login = is_verified and is_active and pwd_len > 0
            status = "OK" if can_login else "BLOCKED"
            if not is_verified:
                status += " (unverified)"
            if not is_active:
                status += " (inactive)"
            if pwd_len == 0:
                status += " (no password)"
            if mfa_enabled:
                status += " (MFA on)"
            print(f"  id={uid} {email} role={role} | {status}")
    print()

    # 5) Key tables for app
    for t in ["candidates", "requisitions", "applications"]:
        if t in tables:
            cur.execute(sql.SQL("SELECT COUNT(*) FROM {}").format(sql.Identifier(t)))
            n = cur.fetchone()[0]
            print(f"  {t}: {n} rows")
    print()

    cur.close()
    conn.close()
    print("Done.")


if __name__ == "__main__":
    main()
