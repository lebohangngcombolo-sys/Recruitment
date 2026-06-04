# Run the app locally

Everything can run locally with minimal setup. Use this as the single source of truth.

**Guarantees**
- Backend starts with only `DATABASE_URL`, `SECRET_KEY`, and `JWT_SECRET_KEY` in `server/.env`.
- Frontend uses `http://127.0.0.1:5000` as the API when you open the app from localhost (no config change).
- Redis, MongoDB, mail, Cloudinary, and AI keys are optional; the app runs without them (some features will be disabled or return errors when used).

---

## 1. Backend (Flask)

### Minimum to start
- Python 3.10+
- **`server/.env`** with:
  - `DATABASE_URL` – PostgreSQL (local or remote); e.g. `postgresql://user:pass@localhost:5432/recruitment_db`
  - `SECRET_KEY`
  - `JWT_SECRET_KEY`

Copy `server/.env.example` to `server/.env` and fill in the three required vars (or reuse your existing `.env`).

### Commands (from repo root or `server/`)

```bash
cd server
python -m venv .venv
# Windows PowerShell:
.\.venv\Scripts\Activate.ps1
# WSL / Linux / macOS:
source .venv/bin/activate

pip install -r requirements.txt
flask db upgrade
python run.py
```

- Backend runs at **http://127.0.0.1:5000**
- If DB connection fails, `run.py` prints a short hint; fix `DATABASE_URL` in `server/.env`

### Optional (app still runs without these)
| Service | Used for | Without it |
|--------|----------|------------|
| **Redis** | Forgot password / reset flow | Forgot-password returns an error; login, dashboards, and rest of app work |
| **MongoDB** | Some features if used | Leave `MONGO_URI` unset or default; app uses env or `mongodb://localhost:27017/recruitment_cv` |
| **Mail** | Verification / reset emails | Emails not sent; set SMTP or `SENDGRID_API_KEY` if needed |
| **Cloudinary** | CV/image uploads | Set `CLOUDINARY_*` in `.env` if you need uploads |
| **AI keys** | Job gen, CV parsing, chat | Set `GEMINI_API_KEY` / `OPENROUTER_API_KEY` / `DEEPSEEK_API_KEY` as needed |

---

## 2. Frontend (Flutter)

### Requirements
- Flutter SDK (>=3.0.0)

### Commands

```bash
cd khono_recruite
flutter pub get
flutter run
# Or: flutter run -d chrome --web-port=3000
```

- When opened from **localhost** / **127.0.0.1**, the app uses **http://127.0.0.1:5000** as the API base (no change needed).
- Override at run time:  
  `flutter run --dart-define=API_BASE=http://127.0.0.1:5000`

---

## 3. Quick checklist

| Step | Action |
|------|--------|
| 1 | Copy `server/.env.example` to `server/.env` and set `DATABASE_URL`, `SECRET_KEY`, `JWT_SECRET_KEY` (or keep your current `.env`) |
| 2 | Backend: `cd server` → activate venv → `pip install -r requirements.txt` |
| 3 | Backend: `flask db upgrade` (apply migrations) |
| 4 | Backend: `python run.py` → http://127.0.0.1:5000 |
| 5 | Frontend: `cd khono_recruite` → `flutter pub get` → `flutter run` |
| 6 | Use app from localhost so it talks to local backend |

---

## 4. Database and migrations

- **Database** – `DATABASE_URL` in `server/.env` is used for local runs. It may point at a Render DB or local Postgres.
- **Migrations** – Run `flask db upgrade` after pulling or when the schema changes so the DB matches the code.
- **Frontend** – No config change needed for local; `AppConfig` uses `http://127.0.0.1:5000` when the app is served from localhost.

---

## 5. Health check

- Backend: **GET http://127.0.0.1:5000/api/public/healthz**
- Frontend: Open the app in the browser; login/register should hit the local backend when running from localhost.

---

## 6. If you get 401 (UNAUTHORIZED) on login

The API returns 401 when the user is not found or the password is wrong. **In DEBUG mode**, the server log will show either `Login 401: no user for email=...` or `Login 401: password mismatch for user id=...` so you can tell which it is.

To get a working login locally:

1. **Create/update test users with a known password** (from `server/` with venv activated):

   ```bash
   cd server
   source .venv/bin/activate   # or .\.venv\Scripts\Activate.ps1 on Windows
   python scripts/ensure_local_test_users.py
   ```

   This ensures:
   - **admin@mycompany.com** (admin) — password: `LocalDev123!`
   - **hiring.manager@test.com** (hiring manager) — password: `LocalDev123!`

2. Log in with one of those emails and the password printed by the script (default `LocalDev123!`).

3. Alternatively, set a password for an existing user:
   ```bash
   python scripts/fix_user_password.py your@email.com YourPassword
   ```
