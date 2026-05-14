# Fix: Can't locate revision '7ec5a07c5b21'

The DB has `alembic_version` set to a revision that no longer exists, so `flask db stamp` fails too (Alembic reads the DB first). Fix it by updating the DB directly, then upgrading.

**1. Set alembic_version to a revision that exists (from `server`):**
```bash
cd server
python scripts/fix_alembic_version.py
```

**2. Run pending migrations:**
```bash
flask db upgrade
```

This applies only the approval workflow migration (`20260317_approval`). Use this only if your schema is already up to date up to `20260306_interview_slots`. If the DB is empty or missing tables, run a full migration from scratch instead.
