# Database analysis summary (recruitment_db_vexi)

Run: `python scripts/analyze_database.py` (uses `DATABASE_URL` from `.env`)  
Or: `python scripts/analyze_database.py "postgresql://..."` to analyze a specific URL.

---

## recruitment_db_vexi (Render)

- **Migrations**: Up to date (`20260228_last_login`). Table `users` has all required columns including `last_login_at`.
- **Tables**: 28 tables present; row counts include: users (28), candidates (9), requisitions (2), applications (1), audit_logs (125), etc.
- **Users**: 28 users. Many are login-ready (verified, active, password set). Examples:
  - **admin@mycompany.com** (admin) – OK  
  - **hiring.manager@test.com** (hiring_manager) – OK  
  - **admin@test.com**, **admin.deployed@test.com**, **hm.deployed@test.com**, **admin@example.com** – OK  
  - Some candidates are BLOCKED (unverified) and cannot log in until verified.

---

## Why you get 401 on login

1. **Wrong database**  
   Your `server/.env` has `DATABASE_URL` pointing to **recruitement_deploy**, not **recruitment_db_vexi**.  
   The app uses whatever `DATABASE_URL` is in `.env`. So if you want to log in against **recruitment_db_vexi**, set in `server/.env`:
   ```env
   DATABASE_URL=postgresql://recruitment_db_vexi_user:UcI5op62mjxTmneB9ZThvaxoC4EGMspu@dpg-d64aam8gjchc739jpt5g-a.oregon-postgres.render.com/recruitment_db_vexi?sslmode=require
   ```
   Then restart the Flask server.

2. **Wrong email or password**  
   ​401 means “user not found” or “wrong password” for the DB the app is using. Use an email that exists in that DB and the correct password.

3. **Set a known password**  
   To use **admin@mycompany.com** or **hiring.manager@test.com** with a known password on the DB pointed to by `DATABASE_URL`:
   ```bash
   cd server
   source .venv/bin/activate
   python scripts/ensure_local_test_users.py
   ```
   Default password: **LocalDev123!**  
   Then log in with that email and password.
