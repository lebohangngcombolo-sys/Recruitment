# Full Codebase Analysis — Recruitment (Flask + Flutter)

This document provides a structured analysis of the entire Recruitment codebase: architecture, backend, frontend, API alignment, and recommendations. It complements `CODEBASE_ANALYSIS.md` and `RUN_SMOOTHLY_ANALYSIS.md`.

---

## 1. High-level architecture

| Layer | Stack | Location |
|-------|--------|----------|
| **Backend API** | Flask, SQLAlchemy, JWT, Socket.IO, Celery | `server/` |
| **Frontend** | Flutter (Web primary), GoRouter, Provider | `khono_recruite/` |
| **Database** | PostgreSQL (production), Alembic migrations | `server/migrations/` |
| **Deploy** | Render (API + static web), `render.yaml` | Repo root |

**Entry points**
- Backend: `server/run.py` → `create_app()`, `socketio.run(app, port=5001)`
- Frontend: `khono_recruite/lib/main.dart` → Firebase (optional), AIService, GoRouter
- Celery: `server/celery_worker.py` (CV analysis task); can run eager with `CELERY_TASK_ALWAYS_EAGER=true`

---

## 2. Backend (Flask)

### 2.1 Config (`server/app/config.py`)

- **Secrets:** `SECRET_KEY`, `JWT_SECRET_KEY` required in production.
- **Database:** `DATABASE_URL`; production URLs get `?sslmode=require` appended.
- **Optional:** `MONGO_URI`, `REDIS_URL`, `FRONTEND_URL`, `BACKEND_URL`, Cloudinary (required in prod), Mail, OAuth, SSO, Google Calendar.
- **Rate limit:** `RATELIMIT_STORAGE_URI = "memory://"` (single-process; use Redis for multi-worker).

### 2.2 Extensions (`server/app/extensions.py`)

- **Core:** `db` (SQLAlchemy), `jwt`, `mail`, `migrate`, `cors`, `bcrypt`, `oauth`, `limiter`, `socketio`.
- **Cloudinary:** Initialized only when all three env vars are set (avoids startup failure in dev).
- **MongoDB:** `mongo_client`, `mongo_db` (optional).
- **Redis:** URL from env or built from REDIS_HOST/PORT/PASSWORD (used by limiter, email, etc.).

### 2.3 Blueprints and routes

| Blueprint | Prefix | Purpose |
|-----------|--------|---------|
| **auth** (init_auth_routes) | (direct on app) | `/api/auth/*` (login, register, verify, forgot/reset password, me, dashboards, enrollment, admin-enroll, change-password, cv/parse), OAuth, SSO stub |
| **admin_routes** | `/api/admin` | Jobs CRUD, candidates, applications, interviews, MFA enroll, analytics, pipeline, PowerBI, shared notes, meetings, offers, search |
| **candidate_routes** | `/api/candidate` | Apply, jobs, upload resume, profile, settings, notifications, drafts |
| **ai_routes** | `/api/ai` | `/chat`, `/parse_cv`, `/analysis/<id>` |
| **mfa_routes** | `/api/auth` | `/mfa/enable`, `/mfa/verify`, `/mfa/login`, etc. |
| **sso_routes** | (routes define full path) | `/api/auth/sso`, `/api/auth/sso/callback`, status, logout |
| **analytics_routes** | `/api` | `/analytics/*` (applications, conversion, dropoff, time-per-stage, etc.) |
| **chat_routes** | `/api/chat` | Threads, messages, presence, search |
| **offer_routes** | `/api/offer` | Create, review, approve, sign, reject, expire, list, analytics, my-offers |
| **public_routes** | `/api/public` | `/healthz`, `/jobs` |

All registered in `app/__init__.py`; WebSocket handlers registered via `register_websocket_handlers(app)`.

### 2.4 Models (`server/app/models.py`)

- **Identity/auth:** `User`, `OAuthConnection`, `VerificationCode`
- **Recruitment:** `Requisition`, `Candidate`, `Application`, `AssessmentResult`, `Interview`, `InterviewNote`, `InterviewFeedback`, `InterviewReminder`, `CVAnalysis`, `Offer`
- **Activity:** `JobActivityLog`, `AuditLog`, `Notification`
- **Collaboration:** `SharedNote`, `Meeting`, `ChatThread`, `ChatMessage`, `MessageReadStatus`, `UserPresence`
- **Conversation:** `Conversation` (legacy?)

Relationships and `to_dict`/serialization are defined; soft delete on `Requisition` via `deleted_at`, `is_active`.

### 2.5 Services (selected)

- **Auth:** `auth_service`, `email_service`, `mfa_service`; auth routes use `EnrollmentService`, `AIParser`, `file_text_extractor`, `ai_parser_service`, `audit2`.
- **CV/AI:** `AdvancedOCRService`, `CVPatternMatcher`, `CVExtractionOrchestrator`, `ai_cv_parser` (singleton `analyzer`), `cv_parser_service`, `ai_service`.
- **Jobs:** `job_service` (uses `job_schemas`).
- **Other:** `chat_service`, `notification_service`, `assessment_service`, `pdf_service`, `google_calendar_service`, `audit_service`, `audit2`.

### 2.6 Celery

- **Worker:** `celery_worker.py`; autodiscovers tasks under `app`.
- **CV task:** `app.tasks.cv_tasks.analyze_cv_task` uses `ai_cv_parser.analyzer` and `CVExtractionOrchestrator`; writes `structured_data`, `confidence_scores`, `warnings`, `suggestions` into `CVAnalysis` result.
- **Eager mode:** `CELERY_TASK_ALWAYS_EAGER=true` runs tasks in-process (no Redis required).

### 2.7 Backend TODOs / notes

- `admin_routes.py` ~line 2215: `timezone="UTC"  # TODO: Get from user profile`.
- Two util modules: `app/utils/helper.py` (e.g. `get_current_candidate`) and `app/utils/helpers.py` (validate_email, paginate_query, job/offer helpers); consider merging for clarity.

---

## 3. Frontend (Flutter)

### 3.1 Entry and config

- **main.dart:** Optional Firebase init (only if apiKey/projectId set); `AIService.initialize(generativeModel)`; `PathUrlStrategy()` for web; MultiProvider (ThemeProvider, GenerativeModel); GoRouter.
- **API base:** `lib/utils/app_config.dart` — `AppConfig.apiBase` and `AppConfig.publicApiBase` are getters: when running on **web** and host is not localhost, they return `https://recruitment-api-zovg.onrender.com`; otherwise compile-time `String.fromEnvironment('API_BASE', defaultValue: 'http://127.0.0.1:5001')`. So deployed web app uses production API without requiring BACKEND_URL at build time (BACKEND_URL still recommended for flexibility).

### 3.2 Routing (GoRouter)

- **Public:** `/`, `/login`, `/register`, `/verify-email`, `/forgot-password`, `/find-talent`, `/about-us`, `/contact`, `/job-details`, `/sso-enterprise`, `/reset-password`, `/oauth-callback`, `/sso-redirect`.
- **Role dashboards (token in query):** `/candidate-dashboard`, `/enrollment`, `/admin-dashboard`, `/hiring-manager-dashboard`, `/hiring-manager-pipeline`, `/hiring-manager-offers`, `/hr-dashboard`, `/profile`.
- **MFA:** `/mfa-verification` (query: mfa_session_token, user_id).

All referenced screens exist under `lib/screens/`.

### 3.3 API usage (`lib/utils/api_endpoints.dart`)

- **Bases:** `authBase`, `candidateBase`, `adminBase`, `chatbotBase` (= `/api/ai`), `publicBase`, `analyticsBase`, `offerBase`, `chatBase`, `webSocketUrl` — all derived from `AppConfig.apiBase` / `AppConfig.publicApiBase`.
- **Auth:** login, register, verify, logout, forgot/reset password, change-password, me, adminEnroll, OAuth, SSO, MFA endpoints, `parserCV` = `/api/auth/cv/parse`.
- **Candidate:** enrollment, apply, applications, jobs, upload resume, drafts.
- **Admin/Pipeline:** pipeline stats, filtered applications, interviews, etc.
- **AI:** `askBot` = `/api/ai/chat`, `parseCV` (AI) = `/api/ai/parse_cv`.
- **Offers, chat, analytics:** Endpoints defined; some interview/feedback/notes endpoints may not have backend implementations (see CODEBASE_ANALYSIS.md).

### 3.4 Screens and roles

- **Auth:** Login, Register, Verification, Forgot/Reset password, SSO enterprise, OAuth callback, MFA verification.
- **Candidate:** Dashboard, job details, find talent, applications, profile, settings, assessments, offers, enrollment, CV upload.
- **Hiring manager:** Dashboard, pipeline, job management, candidate management, interviews, analytics, profile, notifications, meetings, offers list.
- **Admin:** Dashboard, job management, candidate management, interviews, analytics, user management, profile, notifications, HM analytics.
- **HR:** Dashboard, offer analytics, approve offer.
- **Shared:** Landing, about us, contact; shared job form, pipeline, offer list.

### 3.5 Frontend TODOs / notes

- `hiring_manager_dashboard.dart`: “Handle the selected image when upload flow is implemented”; chart data API and PowerBI status may be TODOs.
- `job_details_page.dart`: Comment about handling nested response structure (already handled in code).

---

## 4. API contract alignment

- **Auth:** Flutter `authBase` → `/api/auth`; backend auth routes under `/api/auth/*` — aligned.
- **Candidate:** `candidateBase` → `/api/candidate`; backend `candidate_bp` prefix `/api/candidate` — aligned.
- **Admin/HM:** `adminBase` → `/api/admin`; backend `admin_bp` prefix `/api/admin` — aligned.
- **Public:** `publicBase` → `/api/public`; backend `public_bp` → `/api/public/healthz`, `/api/public/jobs` — aligned.
- **AI/Chatbot:** `chatbotBase` → `/api/ai`, `askBot` → `/api/ai/chat`, `parseCV` (AI) → `/api/ai/parse_cv` — aligned.
- **Chat:** `chatBase` → `/api/chat` — aligned.
- **Offers:** `offerBase` → `/api/offer` — aligned.
- **Analytics:** `analyticsBase` → `/api/analytics`; backend analytics_bp prefix `/api` so routes are `/api/analytics/...` — aligned.
- **CV parse (upload):** Flutter `parserCV` = `/api/auth/cv/parse` (multipart); backend auth route `/api/auth/cv/parse` — aligned.

Some Flutter endpoints (e.g. interview feedback summary, notes, workflow, conflict-check) may have no or partial backend implementation; 404s possible if those screens call them.

---

## 5. Auth and deployment

- **Login flow:** POST `/api/auth/login` → JWT; optional MFA step (`/api/auth/mfa/login`). Flutter stores token and passes in headers; dashboard routes receive token in query for deep links.
- **CORS:** Backend allows all origins (`origins=["*"]`); production should restrict to `FRONTEND_URL` when set.
- **Deploy (Render):** `render.yaml` defines recruitment-api (Python, `render_start.sh`, healthCheckPath `/api/public/healthz`) and recruitment-web (static, `render_build.sh`, `build/web`). Set `BACKEND_URL` (and optionally `FRONTEND_URL`) for recruitment-web so builds use correct API base; runtime fallback in `app_config.dart` still uses production URL when served from non-localhost.
- **Database:** Migrations in `server/migrations/versions/`; chain from `d544fdd839da` through `20260216_add_indexes`; `render_start.sh` runs `flask db upgrade` before gunicorn.

---

## 6. Gaps and recommendations

### 6.1 Backend

- **CORS:** Restrict to `FRONTEND_URL` (or list of origins) in production.
- **Rate limiting:** Use Redis (`RATELIMIT_STORAGE_URI`) when running multiple workers.
- **Utils:** Merge `helper.py` and `helpers.py` into one module to avoid confusion.
- **Timezone:** Use user profile timezone where applicable (admin_routes TODO).
- **Optional routes:** Implement or remove Flutter endpoints that return 404 (interview/analytics-related).

### 6.2 Frontend

- **Logout:** Prefer `context.go('/login')` (or dedicated route) after logout to avoid empty stack with `pop`.
- **setState after dispose:** Keep using `if (!mounted) return` in async callbacks.
- **PowerBI / chart data:** Implement or stub the TODOs in hiring manager dashboard if those features are required.

### 6.3 Security and config

- **Secrets:** Never commit `.env` or real keys; use Render env (or CI secrets).
- **Firebase:** Optional; app runs without it (OpenRouter/DeepSeek fallback for AI).

### 6.4 Repo hygiene

- **e64,os:** Appears to be a `less` help file; consider removing or adding to `.gitignore` if not needed.
- **Dart tooling:** `khono_recruite/.dart_tool/` is in `.gitignore`; avoid committing generated files.

---

## 7. Summary

| Area | Status |
|------|--------|
| **Backend structure** | Coherent; blueprints, models, services, and Celery task wired; config and extensions support dev/prod. |
| **Frontend structure** | Coherent; GoRouter, AppConfig, ApiEndpoints; role-based dashboards and screens present. |
| **API alignment** | Auth, candidate, admin, public, AI, chat, offers, analytics base URLs and main endpoints aligned. |
| **Deployment** | Render-ready; migrations on start; BACKEND_URL for web build; runtime fallback for API URL on deployed web. |
| **TODOs** | Backend: timezone, helper merge. Frontend: PowerBI/chart data, image upload handling. Non-blocking. |

The codebase is in good shape for development and deployment. Remaining work is mostly optional hardening (CORS, rate-limit storage, utils merge) and feature-level TODOs (PowerBI, charts, timezone).
