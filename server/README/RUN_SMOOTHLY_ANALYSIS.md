# Codebase Analysis — Frontend, Backend, Database (Run Smoothly)

This document summarizes a full pass over the repo so the app runs smoothly locally and in production.

---

## 1. Backend (Flask / Python)

### 1.1 Entry & config

- **Entry:** `server/run.py` → `create_app()`, `db.create_all()`, `socketio.run(app, host="0.0.0.0", port=5001)`.
- **Config:** `app/config.py` loads `.env`, normalizes `DATABASE_URL` (adds `?sslmode=require` in production), and requires `SECRET_KEY`, `JWT_SECRET_KEY`, `DATABASE_URL`, and `CLOUDINARY_*` in production.
- **Cloudinary:** `app/extensions.py` — `CloudinaryClient.init_app()` now only calls `cloudinary.config()` when all three Cloudinary env vars are set; otherwise it skips config so the app can start in dev without Cloudinary (uploads will fail until vars are set).

### 1.2 Imports and dependencies

- **Routes:** `app/__init__.py` registers auth, admin_routes, candidate_routes, ai_routes, mfa_routes, sso_routes, analytics_routes, chat_routes, offer_routes, public_routes, and SSO. All referenced modules exist.
- **Services used by routes:** `auth` → EnrollmentService, AIParser, file_text_extractor, ai_parser_service, audit2, email_service, auth_service. `ai_cv_parser` → AdvancedOCRService, cv_pattern_matcher. `cv_tasks` → CVExtractionOrchestrator, ai_cv_parser.analyzer. All present.
- **Schemas:** `job_service` uses `job_schemas.job_create_schema`, etc.; `job_schemas.py` exists and exports them.
- **Extensions:** `redis_client` is defined in `extensions.py` and used by `email_service` and `auth_service`. `db` is re-exported via `models` (models imports db from extensions), so `from app.models import db` works.

### 1.3 Fixes applied

- **Duplicate code in `ai_cv_parser.py`:** Removed the unreachable duplicate block after `return extracted` in `offline_extract()`.
- **Cloudinary init:** Only configures when `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, and `CLOUDINARY_API_SECRET` are all set, so dev without these vars no longer crashes at startup.

### 1.4 Celery

- **Worker:** `celery_worker.py` uses `REDIS_URL` / `CELERY_BROKER_URL`, autodiscovers tasks under `app`. `app.tasks.cv_tasks` imports `CVExtractionOrchestrator` and `analyzer`; both modules exist.
- **Run:** From `server/`: `export PYTHONPATH="$PWD"` then `celery -A celery_worker.celery worker --loglevel=info`. With `CELERY_TASK_ALWAYS_EAGER=true`, tasks run in-process (no Redis required).

### 1.5 Optional / environment

- **Firebase:** Optional. If `FIREBASE_SERVICE_ACCOUNT_KEY_FILE` is unset or file missing, a warning is logged and the app continues.
- **MongoDB:** Optional (`MONGO_URI`). Used by extensions for `mongo_db`.
- **Redis:** Optional for Flask; required for Celery unless `CELERY_TASK_ALWAYS_EAGER=true`. If `REDIS_URL` is missing, extensions use `redis://localhost:6379/0` (connection will fail if Redis is not running).

---

## 2. Frontend (Flutter / Dart)

### 2.1 Entry & config

- **Entry:** `lib/main.dart` uses `Firebase.initializeApp` only when `apiKey` and `projectId` are non-empty in `firebase_options.dart`, avoiding invalid-api-key crashes. `AIService.initialize(generativeModel)` and `PathUrlStrategy()` for web.
- **API base:** `lib/utils/app_config.dart` uses `String.fromEnvironment('API_BASE', defaultValue: 'http://127.0.0.1:5001')` and `PUBLIC_API_BASE`. `lib/utils/api_endpoints.dart` imports `app_config.dart` and builds URLs from `AppConfig.apiBase` / `AppConfig.publicApiBase`. For production web build, set `BACKEND_URL` (or `API_BASE`) in `render_build.sh` so the built app hits the deployed API.

### 2.2 Routes and screens

- **GoRouter:** main.dart defines routes for login, register, candidate, hiring manager, admin, HR, landing, enrollment, auth callbacks, etc. Referenced screens (e.g. `pipeline_page.dart`, `offer_list_screen.dart`) exist under `lib/screens/`.

### 2.3 Assets and 404s

- **pubspec.yaml:** Lists assets under `assets/images/` and `assets/icons/`. Several legacy files are commented out (e.g. `Instagram1.png`, `icon.png`, `LinkedIn1.png`).
- **Fix applied:** Replaced references to missing `assets/images/icon.png` with `assets/images/logo2.png` in `hiring_manager_dashboard.dart` and `admin_dashboard.dart` to prevent 404s.
- **Still referenced in code:** Ensure all other asset paths in the app match entries in `pubspec.yaml`. Names like `Instagram.png`, `LinkedIn.png`, `facebook.png`, `YouTube.png`, `khono.png`, `dark.png`, `profile_placeholder.png`, `logo3.png`, etc. are listed in pubspec.

### 2.4 Run

- **Local web:** From `khono_recruite/`: `flutter pub get` then `flutter run -d chrome`. Backend should be on port 5001 (or set `--dart-define=API_BASE=http://...`).
- **Production build:** `render_build.sh` runs `flutter build web --release` with `API_BASE` and `PUBLIC_API_BASE` from env.

---

## 3. Database

### 3.1 SQLAlchemy and migrations

- **Models:** `app/models.py` defines User, Candidate, Requisition, Application, and other tables; uses `app.extensions.db`.
- **Migrations:** Alembic chain: `d544fdd839da` (init) and `5e59a6f99a77` (legacy) → merge `8c2b6b1a9d21` → `33f86c05b761` → `b6b9a43a3778` → `20260216_fix_requisition_duplicates` → `20260216_add_indexes`. Head: `20260216_add_indexes`.
- **Apply:** From `server/` with `DATABASE_URL` set: `flask db upgrade`. On Render, `render_start.sh` runs `flask db upgrade` before gunicorn.

### 3.2 Connection

- **PostgreSQL:** Config uses `SQLALCHEMY_DATABASE_URI` with `pool_pre_ping=True` and `pool_recycle=300`. Production URLs get `sslmode=require` appended if missing.
- **Local:** Set `DATABASE_URL` in `server/.env` (e.g. `postgresql://user:pass@localhost/recruitment_db`). For deployed DB, use External URL and optional `?sslmode=require`.

---

## 4. Checklist before run

| Area | Check |
|------|--------|
| **Backend** | `server/.env` has `DATABASE_URL`, `SECRET_KEY`, `JWT_SECRET_KEY`. Optional: `CLOUDINARY_*`, `REDIS_URL`, `FIREBASE_SERVICE_ACCOUNT_KEY_FILE`. |
| **Backend** | From `server/`: `pip install -r requirements.txt`, `flask db upgrade`, `python run.py` (or `gunicorn` via render_start.sh). |
| **Celery** | Either set `CELERY_TASK_ALWAYS_EAGER=true` (no Redis) or set `REDIS_URL` and run a Celery worker. |
| **Frontend** | `flutter pub get`. Backend running on 5001 (or set API_BASE). No references to removed assets (e.g. icon.png fixed). |
| **Firebase** | Optional. If unused, leave `firebase_options.dart` with empty apiKey/projectId or run `flutterfire configure`. |
| **Deploy** | See `DEPLOYMENT.md` and §0 for Render env vars and post-push steps. |

---

## 5. Summary

- **Backend:** Duplicate code removed in `ai_cv_parser`, Cloudinary init safe when vars are missing, imports and migration chain verified.
- **Frontend:** Missing asset references for `icon.png` replaced with `logo2.png`; API base and endpoints driven by `AppConfig` and build-time env.
- **Database:** Migrations linear; config and pool settings suitable for local and production Postgres.

With the above in place and env set correctly, the app should run smoothly locally and be deployable to Render following `DEPLOYMENT.md`.
