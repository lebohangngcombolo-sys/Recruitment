"""
One-off script: set is_verified=True, is_active=True (and disable MFA) for
hm.deployed@test.com (id 17) and admin.deployed@test.com (id 18) in the
deployed DB (recruitment_db_vexi) so login works before/after redeploy.

Usage (from server directory):
  set DEPLOYED_DATABASE_URL=postgresql://user:pass@host.../recruitment_db_vexi
  python scripts/fix_deployed_users.py
"""
import os
import sys

try:
    import psycopg2
except ImportError:
    print("psycopg2 not installed. Run: pip install psycopg2-binary", file=sys.stderr)
    sys.exit(1)

# Set DEPLOYED_DATABASE_URL to the external Render Postgres URL for recruitment_db_vexi.
# Example: postgresql://user:pass@host.oregon-postgres.render.com/recruitment_db_vexi?sslmode=require
DSN = os.environ.get("DEPLOYED_DATABASE_URL")
if not DSN:
    print("Set DEPLOYED_DATABASE_URL (external Render DB URL) and run again.", file=sys.stderr)
    sys.exit(1)
if "sslmode" not in DSN and "?" not in DSN:
    DSN = DSN + "?sslmode=require"
elif "sslmode" not in DSN:
    DSN = DSN + "&sslmode=require"


def main():
    print("Connecting to deployed DB...")
    conn = psycopg2.connect(DSN)
    conn.autocommit = False
    cur = conn.cursor()

    # 1) Show current state
    cur.execute(
        """
        SELECT id, email, role, is_verified, is_active, enrollment_completed,
               mfa_enabled, mfa_verified
        FROM users
        WHERE id IN (17, 18) OR lower(email) IN ('hm.deployed@test.com', 'admin.deployed@test.com')
        ORDER BY id
        """
    )
    rows = cur.fetchall()
    print("BEFORE:")
    for r in rows:
        print("  ", r)

    # 2) Verify + activate + disable MFA so password login works
    cur.execute(
        """
        UPDATE users
        SET is_verified = TRUE,
            is_active = TRUE,
            mfa_enabled = FALSE,
            mfa_verified = FALSE,
            mfa_secret = NULL,
            mfa_backup_codes = NULL
        WHERE id IN (17, 18)
           OR lower(email) IN ('hm.deployed@test.com', 'admin.deployed@test.com')
        """
    )
    updated = cur.rowcount
    conn.commit()
    print(f"Updated {updated} row(s).")

    # 3) Show after state
    cur.execute(
        """
        SELECT id, email, role, is_verified, is_active, mfa_enabled
        FROM users
        WHERE id IN (17, 18)
        ORDER BY id
        """
    )
    print("AFTER:")
    for r in cur.fetchall():
        print("  ", r)

    cur.close()
    conn.close()
    print("Done. You can now log in with hm.deployed@test.com and admin.deployed@test.com.")


if __name__ == "__main__":
    main()
