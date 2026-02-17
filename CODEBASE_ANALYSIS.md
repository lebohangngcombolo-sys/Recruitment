# Codebase Analysis – Backend & Frontend

This document summarizes a full pass over the Recruitment app (Flask backend + Flutter frontend) and lists **gaps, bugs, and recommendations**.

---

## 1. Fixes applied during analysis

| Issue | Location | Fix |
|-------|----------|-----|
| **Wrong admin MFA route** | `server/app/routes/admin_routes.py` | Route was `@admin_bp.route('/api/auth/enroll_mfa/...')` so the full path became `/api/admin/api/auth/enroll_mfa/...`. Changed to `@admin_bp.route('/enroll_mfa/<int:user_id>', ...)` so it is `/api/admin/enroll_mfa/<id>`. |
| **Chatbot API mismatch** | Flutter `api_endpoints.dart` | Frontend used `chatbotBase` = `/api/chatbot` but backend exposes AI at `/api/ai`. Updated `chatbotBase` to `${AppConfig.apiBase}/api/ai`. |
| **Wrong ask endpoint** | Flutter `api_endpoints.dart` | `askBot` pointed to `$chatbotBase/ask`; backend has `POST /api/ai/chat`. Updated to `askBot = "$chatbotBase/chat"`. |

---

## 2. Backend – structure and coverage

### 2.1 Blueprints and prefixes

- **auth** – mounted on `app` (routes under `/api/auth/`, `/api/candidate/enrollment`, `/api/dashboard/*`, `/api/auth/cv/parse`).
- **admin_routes** – `/api/admin`.
- **candidate_routes** – `/api/candidate`.
- **ai_routes** – `/api/ai` (chat, parse_cv, analysis).
- **mfa_routes** – `/api/auth` (mfa/*).
- **sso_routes** – `/api/auth` (sso, sso/callback, sso/status, sso/logout).
- **analytics_routes** – `/api` (so analytics under `/api/analytics/...`).
- **chat_routes** – `/api/chat`.
- **offer_routes** – `/api/offer`.
- **public_routes** – `/api/public` (healthz, jobs).

All of these are registered in `app/__init__.py`; no missing blueprints detected.

### 2.2 Utils – two helper modules

- **`app/utils/helper.py`** – defines `get_current_candidate` (and related); used by `candidate_routes`.
- **`app/utils/helpers.py`** – defines `validate_email`, `validate_phone`, `paginate_query`, job/offer helpers, etc.

Recommendation: consider merging into a single module (e.g. `helpers.py`) and updating imports to avoid confusion between `helper` and `helpers`.

### 2.3 Backend TODOs

- `server/app/routes/admin_routes.py` (around line 2215): `timezone="UTC"  # TODO: Get from user profile` – use profile timezone when available.

---

## 3. Frontend – structure and coverage

### 3.1 API base alignment

- **Auth:** `ApiEndpoints.login`, `register`, etc. use `authBase` → `/api/auth` ✓  
- **Candidate:** `candidateBase` → `/api/candidate` ✓  
- **Admin/HM:** `adminBase` → `/api/admin` ✓  
- **Public jobs:** `publicBase` → `/api/public` (and `publicApiBase` default same as `apiBase`) ✓  
- **AI/Chatbot:** `chatbotBase` → `/api/ai` (fixed), `askBot` → `/api/ai/chat`, `parseCV` → `/api/ai/parse_cv` ✓  
- **Chat:** `chatBase` → `/api/chat` ✓  
- **Offers:** `offerBase` → `/api/offer` ✓  
- **Analytics:** `analyticsBase` → `/api/analytics` ✓  

### 3.2 Two CV parse flows

- **Enrollment / file upload:** `AuthService.parseCV()` uses `ApiEndpoints.parserCV` = `/api/auth/cv/parse` (multipart with file). Backend implements this in auth routes ✓  
- **Landing chatbot CV analysis:** Uses `ApiEndpoints.parseCV` = `/api/ai/parse_cv` with JSON `cv_text` and `job_description`. Backend supports this ✓  

### 3.3 Frontend TODOs

- **hiring_manager_dashboard.dart**  
  - “TODO: Implement actual API calls for chart data”  
  - “TODO: Handle the selected image”  
  - “TODO: Implement PowerBI status fetching”  

These are product/feature TODOs, not structural gaps.

---

## 4. Possible gaps and improvements

### 4.1 Backend

- **CORS:** Currently `origins=["*"]`. For production, restrict to the actual frontend origin(s).
- **Rate limiting:** `RATELIMIT_STORAGE_URI = "memory://"` – in multi-worker/production, use Redis (or similar) so limits are shared.
- **Health check:** `/api/public/healthz` exists; ensure load balancers/monitoring use it.
- **Offer role:** `offer_routes` uses `@role_required("admin")` for draft; confirm whether hiring_manager should also draft offers and add role if needed.

### 4.2 Frontend

- **Logout / go_router:** If the app uses `context.pop()` after logout and the stack is empty, go_router can throw. Prefer `context.go('/')` or a dedicated login route after logout so the stack is valid.
- **KnockoutRulesBuilder:** Uses `DropdownButtonFormField(initialValue: ...)`. On current Flutter this is valid; if you see deprecation or odd behavior, switch to a stateful widget with explicit `value` and `onChanged` if the API changes.
- **setState after dispose:** Notifications and job save flows were fixed with `if (!mounted) return;`; keep using the same pattern for any new async UI updates.

### 4.3 Security / config

- **Secrets in .env:** Ensure `.env` is in `.gitignore` and not committed; use env-specific values in production.
- **Firebase:** Backend uses a service account key file; Flutter uses optional Firebase init and falls back to OpenRouter/DeepSeek when Firebase is not configured. No structural gap.

### 4.4 Optional backend routes not (or barely) used by Flutter

Many interview-related endpoints are defined in `api_endpoints.dart` (feedback summary, notes, workflow, templates, conflict-check, analytics, etc.). Backend may not implement all of them. If a screen calls one of these and gets 404, add or align the backend route. No exhaustive call-site check was done for every endpoint.

---

## 5. Summary

- **Critical fixes applied:**  
  - Admin MFA enroll route path corrected.  
  - Chatbot/ask and parse_cv frontend endpoints pointed to `/api/ai` and `/api/ai/chat`.  
- **Backend:** Structure is consistent; small cleanups (helpers merge, CORS, rate-limit storage, timezone TODO) recommended.  
- **Frontend:** API base and main flows (auth, candidate, admin, public, AI, chat, offers) align with the backend; remaining TODOs are feature-level.  
- **Next steps:** Restrict CORS and move rate limiting to Redis for production; implement or remove unused interview/analytics endpoints; and address dashboard/PowerBI TODOs when prioritised.
