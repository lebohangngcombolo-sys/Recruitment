# Run Readiness — Recruitment (Frontend + Backend + DB)

This document summarizes how to run the full stack and what is required.

---

## 1. Frontend (Flutter — khono_recruite)

### Requirements
- Flutter SDK (>=3.0.0)
- Run from repo root or `khono_recruite/`

### Commands
```bash
cd khono_recruite
flutter pub get
flutter run
# Or: flutter run -d chrome   (web)
# Or: flutter run -d windows (desktop)
```

### API base URL
- **Local:** Default is `http://127.0.0.1:5000` (backend on port 5000).
- **Web (production host):** When the app is opened from a non-localhost URL (e.g. Render), it uses the production API base (`https://recruitment-api-zovg.onrender.com`) unless overridden.
- **Override at run time:**  
  `flutter run --dart-define=API_BASE=https://your-api.com`

### Firebase (optional)
- `lib/firebase_options.dart` has placeholders (empty `apiKey`). The app **runs without Firebase**; AI uses the backend when Firebase is not configured.
- To enable Firebase (e.g. Gemini client-side): configure a Firebase project and run `flutterfire configure` (or paste values into `firebase_options.dart`).

### Status
- Entry: `lib/main.dart`
- Config: `lib/utils/app_config.dart`, `lib/utils/api_endpoints.dart`
- No blocking analyzer issues when running `flutter analyze lib/` after `flutter pub get`.

---

## 2. Backend (Flask — server)

### Requirements
- Python 3.10+ recommended
- **`server/.env`** file with at least:
  - `DATABASE_URL` (PostgreSQL connection string)
  - `SECRET_KEY`
  - `JWT_SECRET_KEY`
- Optional: mail, OAuth, Cloudinary, Redis, MongoDB, Firebase Admin, AI keys (see `server/.env.example`).

### Commands
```bash
cd server
# Create venv if needed
python -m venv .venv
# Windows: .venv\Scripts\activate
# Linux/macOS: source .venv/bin/activate
pip install -r requirements.txt

# Apply DB migrations (recommended)
flask db upgrade

# Run the app
python run.py
# Or: flask run
# Listens on http://0.0.0.0:5000
```

### Env file
- Copy `server/.env.example` to `server/.env` and fill in values.
- `.env` is gitignored; never commit real secrets.

### Status
- Entry: `server/run.py` (loads `server/.env`, creates app, runs SocketIO on port 5000).
- Config: `server/app/config.py` (reads from env).
- Database: `SQLALCHEMY_DATABASE_URI` from `DATABASE_URL`; SSL is added for remote URLs (e.g. Render).

---

## 3. Database (PostgreSQL)

### Connection
- Backend uses **one** DB URL: **`DATABASE_URL`** in `server/.env`.
- For local Postgres:  
  `postgresql://USER:PASSWORD@localhost:5432/DBNAME`
- For Render/cloud: use the URL from the Render dashboard (often with `?sslmode=require`; config adds it if missing for non-localhost).

### Migrations
- Tool: **Flask-Migrate** (Alembic).
- Location: `server/migrations/`.
- After changing models: `flask db migrate -m "description"` then `flask db upgrade`.

### Status
- Models: `server/app/models.py`.
- Migrations exist under `server/migrations/versions/`; run `flask db upgrade` before first run.

---

## 4. Quick start (local)

1. **Backend**
   - `cd server`
   - Ensure `server/.env` exists with valid `DATABASE_URL`, `SECRET_KEY`, `JWT_SECRET_KEY`.
   - `pip install -r requirements.txt` (inside a venv).
   - `flask db upgrade`
   - `python run.py` → backend at http://127.0.0.1:5000

2. **Frontend**
   - `cd khono_recruite`
   - `flutter pub get`
   - `flutter run` (choose Chrome/Windows/etc.) → app uses http://127.0.0.1:5000 by default.

3. **Firebase**  
   Optional; app runs without it. Configure `firebase_options.dart` only if you need client-side Firebase/Gemini.

---

## 5. Blocking issues (none if env is set)

| Check              | Status |
|--------------------|--------|
| Frontend entry     | OK — `main.dart` |
| Frontend config    | OK — `AppConfig` / `ApiEndpoints` |
| Backend entry      | OK — `run.py` |
| Backend config     | OK — `app/config.py` + `server/.env` |
| DB connection      | OK — `DATABASE_URL` in `.env` |
| Migrations         | OK — `server/migrations/` |
| Firebase optional  | OK — app runs with empty `firebase_options.dart` |

**Only requirement:** `server/.env` must exist with a valid `DATABASE_URL` (and `SECRET_KEY` / `JWT_SECRET_KEY`) so the backend can start and connect to the DB.
