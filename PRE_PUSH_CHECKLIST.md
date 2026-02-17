# Pre-push checklist — Deployed branch

Analysis date: before push to deployed branch. Use this to confirm readiness and avoid regressions.

---

## 1. Secrets & env

| Check | Status |
|-------|--------|
| `.env` is in `.gitignore` and not committed | OK (root + server) |
| No real DB/API keys in repo (DEPLOYMENT.md uses placeholders) | OK |
| Firebase key file path in .gitignore (`server/...firebase-adminsdk-*.json`) | OK |
| `render.env.template` documents required vars; no secrets in template | OK |

**Action:** Ensure production secrets (SECRET_KEY, JWT_SECRET_KEY, DATABASE_URL, etc.) are set only in Render dashboard or CI secrets, never in committed files.

---

## 2. Backend (server)

| Area | Status | Notes |
|------|--------|--------|
| Config | OK | DATABASE_URL, FRONTEND_URL, BACKEND_URL from env; production adds `sslmode=require` |
| Auth | OK | Login/register/verify fixed; bcrypt used consistently (candidate change_password uses Flask-Bcrypt) |
| Password verification | OK | Invalid salt handled; no 500 on bad hashes |
| Email reset link | OK | Uses FRONTEND_URL from config |
| OpenRouter referer | OK | Uses BACKEND_URL from env |
| CORS | OK | Configured; can restrict to FRONTEND_URL later |
| Migrations | OK | Chain complete; `render_start.sh` runs `flask db upgrade` |
| Health check | OK | `GET /api/public/healthz` (no auth) |
| Unused import | Fixed | Removed werkzeug password helpers from candidate_routes (use bcrypt only) |

**Optional for deploy:** MONGO_URI, REDIS_URL, FIREBASE_SERVICE_ACCOUNT_KEY_FILE (or secret file). SSO vars only if using SSO.

---

## 3. Frontend (Flutter)

| Area | Status | Notes |
|------|--------|--------|
| API base | OK | `AppConfig.apiBase` / `PUBLIC_API_BASE`; build uses `--dart-define` in `render_build.sh` |
| Register/verify flow | OK | Null-safe response handling; navigates to verify-email on 201 |
| Auth service | OK | Register returns `{status, body}`; verifyEmail null-safe |
| Logout (HM dashboard) | OK | Uses `context.go('/login')` (no pop of last route) |
| localhostToEnv | OK | Replaces 127.0.0.1:5000/5001 with configured base |

**Action:** Set BACKEND_URL (or API_BASE) for recruitment-web on Render so the built app targets the deployed API.

---

## 4. Deployment config

| File | Status |
|------|--------|
| `render.yaml` | OK — FLASK_ENV=production, DATABASE_URL from DB or sync:false, static site has BACKEND_URL/FRONTEND_URL |
| `server/render_start.sh` | OK — `flask db upgrade` then gunicorn |
| `khono_recruite/render_build.sh` | OK — passes API_BASE/PUBLIC_API_BASE from env |
| `DEPLOYMENT.md` | OK — No real credentials; placeholders only |

---

## 5. Localhost / defaults

- **Backend:** localhost only in default fallbacks (e.g. config, cv_parser_service, sso_routes) when env is unset; production should set FRONTEND_URL, BACKEND_URL.
- **Frontend:** Defaults to 127.0.0.1:5001 in `app_config.dart`; overridden at build time when BACKEND_URL is set on Render.
- **.env (local):** May contain localhost; do not commit.

---

## 6. TODOs (non-blocking)

- `hiring_manager_dashboard.dart`: chart data API, image handler, PowerBI (feature TODOs).
- `admin_routes.py`: timezone from user profile (optional).
- These do not block push; track in issues if needed.

---

## 7. Before you push

1. Run tests (if any): `pytest` / `flutter test` from repo and fix failures.
2. Confirm no `*.env` or `*.pem` or Firebase JSON in `git status`.
3. Confirm `DEPLOYMENT.md` and `PRE_PUSH_CHECKLIST.md` have no real credentials.
4. After first deploy: set BACKEND_URL (and FRONTEND_URL) for recruitment-web and redeploy so the Flutter build uses the live API.

---

## 8. Summary

- **Secrets:** Not in repo; use env / Render dashboard.
- **Backend:** Config and auth safe for production; migrations run on deploy.
- **Frontend:** Register/verify and logout fixed; build uses env for API URL.
- **Deploy:** render.yaml and scripts aligned; DEPLOYMENT.md has no credentials.

Safe to push to the deployed branch after the checks above.
