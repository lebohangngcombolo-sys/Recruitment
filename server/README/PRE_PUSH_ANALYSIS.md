# Pre-push codebase analysis

**Date:** Before push to deployed branch (e.g. `mabunda_deployment`).  
**Purpose:** Confirm readiness and catch regressions before deploy.

---

## 1. Summary

| Area | Status | Notes |
|------|--------|--------|
| **Secrets** | OK | `.env` in `.gitignore`; no real credentials in repo |
| **Backend** | OK | Config, auth, email, CORS, migrations, test endpoint |
| **Frontend** | OK | API base, auth flow, apply URL uses `localhostToEnv` |
| **Render** | OK | `render.yaml` has SPA rewrite, env vars, health check |
| **Docs** | OK | DEPLOYMENT.md, PRE_PUSH_CHECKLIST.md no secrets |

**Verdict:** Safe to push after confirming no `*.env` or secrets in `git status`.

---

## 2. Backend

### 2.1 Config (`server/app/config.py`)

- **FLASK_ENV** is now set on `Config` from `os.getenv("FLASK_ENV", ...)` so `app.config.get("FLASK_ENV")` in `create_app()` is correct and CORS production logic runs on Render.
- **IS_PRODUCTION** and production-only requirements (SECRET_KEY, JWT_SECRET_KEY, DATABASE_URL, CLOUDINARY_*) are unchanged.
- **TEST_EMAIL_SECRET** and **MAIL_*** documented; `sslmode=require` appended for Postgres in production.

### 2.2 CORS (`server/app/__init__.py`)

- When `FLASK_ENV == "production"` and `FRONTEND_URL` is set, CORS origins are restricted to `[FRONTEND_URL]`. Otherwise `["*"]` (e.g. local dev).
- **Action:** Set **FRONTEND_URL** in **recruitment-api** on Render so production CORS is restricted.

### 2.3 Auth & email

- Register/verify/forgot-password use `FRONTEND_URL` for links.
- Test endpoint: `POST /api/auth/test-send-verification-email` (header `X-Test-Email-Secret`); requires `TEST_EMAIL_SECRET` in env. Safe to leave unset to disable.

### 2.4 Migrations

- Chain: `d544fdd839da` → `33f86c05b761` → `b6b9a43a3778` → `20260216_fix_requisition_duplicates` → `20260216_add_indexes`.
- Legacy handling in `render_start.sh`: stamp `8c2b6b1a9d21` when existing DB has no/legacy alembic version.
- Health: `GET /api/public/healthz` (no auth).

### 2.5 TODOs (non-blocking)

- `admin_routes.py` ~line 2215: `timezone="UTC"  # TODO: Get from user profile` — optional.

---

## 3. Frontend

### 3.1 API base

- **app_config.dart:** `apiBase` / `publicApiBase` from `String.fromEnvironment('API_BASE', ...)` or, on web when host ≠ localhost, `_productionApiBase` (`https://recruitment-api-zovg.onrender.com`).
- **render_build.sh** passes `API_BASE` and `PUBLIC_API_BASE` from `BACKEND_URL` so deployed build targets the correct API.
- **Action:** Set **BACKEND_URL** for **recruitment-web** on Render and redeploy after first deploy.

### 3.2 Auth and apply

- Register/verify: null-safe handling; 201 with `access_token` saves tokens and navigates (with try/catch around storage).
- Logout uses `context.go('/login')` where needed (no empty stack).
- **job_details_page.dart:** Apply URL uses `localhostToEnv("http://127.0.0.1:5000/api/candidate/apply/...")` — correct; replaces with configured base.

### 3.3 API endpoints

- `api_endpoints.dart` uses `AppConfig.apiBase` / `publicApiBase`; auth, candidate, admin, AI, chat, offers, public aligned with backend.

---

## 4. Deployment (Render)

### 4.1 render.yaml

- **recruitment-api:** `rootDir: server`, `buildCommand: pip install -r requirements.txt`, `startCommand: bash render_start.sh`, `healthCheckPath: /api/public/healthz`. Env: FLASK_ENV=production, DATABASE_URL (from DB or override in dashboard), MAIL_*, FRONTEND_URL, BACKEND_URL, CLOUDINARY_*, TEST_EMAIL_SECRET, etc.
- **recruitment-web:** `rootDir: khono_recruite`, `buildCommand: bash render_build.sh`, `staticPublishPath: build/web`. **routes:** rewrite `/*` → `/index.html` (SPA fix). Env: BACKEND_URL, FRONTEND_URL.
- **databases:** Optional `recruitment-db`; to use existing DB (e.g. recruitment_db_vexi), set **DATABASE_URL** in dashboard and optionally set `sync: false` for DATABASE_URL in yaml (see DEPLOYMENT.md).

### 4.2 Scripts

- **render_start.sh:** Pre-migration check (stamp legacy if needed), `flask db upgrade`, then gunicorn with eventlet. Uses `PORT` from Render.
- **render_build.sh:** Flutter install/build, `flutter build web --release` with `API_BASE` and `PUBLIC_API_BASE` from env.

---

## 5. Before you push

1. Run tests if present: `pytest` (server), `flutter test` (khono_recruite).
2. Confirm no secrets in working tree: `git status` should not show `.env`, `*.pem`, or Firebase JSON keys.
3. Confirm DEPLOYMENT.md and PRE_PUSH_CHECKLIST.md (and this file) contain no real credentials.
4. After deploy: set **BACKEND_URL** (and **FRONTEND_URL**) for recruitment-web and **FRONTEND_URL** for recruitment-api on Render, then redeploy as needed.

---

## 6. Files changed in this pass

- **server/app/config.py:** Added `FLASK_ENV` on `Config` so CORS production check works.
- **PRE_PUSH_CHECKLIST.md:** CORS line updated to reflect FRONTEND_URL restriction.
- **PRE_PUSH_ANALYSIS.md:** This analysis.

No other code changes required for push readiness.
