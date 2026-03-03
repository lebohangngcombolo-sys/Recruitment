# Deployment Readiness — Redeploy Checklist

Use this checklist when redeploying to **Render** (branch `mabunda_deployment` or your deploy branch). It covers codebase, database, and required environment variables (including **SendGrid** for mail).

---

## 1. Backend (recruitment-api)

### Required env vars (Render dashboard → recruitment-api → Environment)

| Variable | Purpose |
|----------|---------|
| **DATABASE_URL** | PostgreSQL connection string (from linked DB or external). App adds `?sslmode=require` for non-localhost. |
| **SECRET_KEY** | Flask secret (e.g. `openssl rand -hex 32`). |
| **JWT_SECRET_KEY** | JWT signing secret. |
| **FRONTEND_URL** | Deployed web app URL (e.g. `https://recruitment-web-xxx.onrender.com`). Used for CORS and links in emails. |
| **BACKEND_URL** | This API’s public URL (e.g. `https://recruitment-api-xxx.onrender.com`). |

### Email (SendGrid on Render)

Render typically uses **SendGrid** for mail. The app supports two paths:

1. **SendGrid HTTP API (recommended on Render)**  
   - Set **SENDGRID_API_KEY** to your SendGrid API key.  
   - Optional: **SENDGRID_API_URL** (default: `https://api.sendgrid.com/v3/mail/send`).  
   - Optional: **MAIL_TIMEOUT** (seconds; default 60).  
   - **MAIL_DEFAULT_SENDER** must be set and must be a **verified sender** in SendGrid (Settings → Sender Authentication). Format: `"Display Name <email@domain.com>"` or `email@domain.com`.

2. **SMTP fallback**  
   If SENDGRID_API_KEY is not set or the API call fails, the app falls back to SMTP using **MAIL_SERVER**, **MAIL_PORT**, **MAIL_USE_TLS**, **MAIL_USERNAME**, **MAIL_PASSWORD**, **MAIL_DEFAULT_SENDER**. For SendGrid SMTP: MAIL_USERNAME = `apikey`, MAIL_PASSWORD = your API key.

**Redeploy:** Ensure **SENDGRID_API_KEY** and **MAIL_DEFAULT_SENDER** are set on recruitment-api and that the sender is verified in SendGrid. See `RENDER_FEEDBACK.md` for verification-email troubleshooting.

### Optional env vars

- **REDIS_URL** (if using Redis/Celery; otherwise tasks run eager).
- **CLOUDINARY_*** (uploads).
- **GEMINI_API_KEY**, **OPENROUTER_API_KEY**, **DEEPSEEK_API_KEY** (AI).
- **SSO_*** (SSO integration).
- **TEST_EMAIL_SECRET** (for `POST /api/auth/test-email`).

---

## 2. Database and migrations

- **Migrations** run on deploy via `server/render_start.sh`: it runs `flask db upgrade` before starting Gunicorn.
- **Existing DB:** If you use an existing Postgres (e.g. from a previous deploy), set **DATABASE_URL** in the dashboard to that instance’s URL (with `?sslmode=require` if needed; the app adds it when missing for non-localhost).
- **New DB:** If `render.yaml` uses `fromDatabase` for `recruitment-db`, create/link that Postgres in Render so **DATABASE_URL** is set automatically.
- **Legacy schema:** If the DB has tables but no `alembic_version`, `render_start.sh` stamps to `8c2b6b1a9d21` then runs `flask db upgrade`.

---

## 3. Frontend (recruitment-web)

| Variable | Purpose |
|----------|---------|
| **BACKEND_URL** | **Required.** Live API URL. `render_build.sh` passes it as `API_BASE` so the built app calls the deployed API. |
| **FRONTEND_URL** | Optional; your recruitment-web URL. |

After changing **BACKEND_URL**, **redeploy recruitment-web** so the next build uses the correct API.

---

## 4. Health and verify

1. **API:** `GET https://<recruitment-api-url>/api/public/healthz` → `{"status":"ok"}`.
2. **Web:** Open the recruitment-web URL, log in, and hit a page that uses the API (e.g. jobs list) to confirm it talks to the deployed backend.
3. **Mail:** Register a test user and check recruitment-api logs for `Sending verification email to ...` and either `Email sent successfully to ...` or `Failed to send email to ...`. If using SendGrid, ensure **MAIL_DEFAULT_SENDER** is verified in SendGrid.

---

## 5. Files and config summary

| Item | Location |
|------|----------|
| Render blueprint | `render.yaml` (root). Defines recruitment-api, recruitment-web, optional recruitment-db. |
| API start + migrations | `server/render_start.sh` (runs migrations then Gunicorn). |
| Web build | `khono_recruite/render_build.sh` (Flutter build with BACKEND_URL as API_BASE). |
| Server config | `server/app/config.py` (DATABASE_URL, SECRET_KEY, JWT, MAIL_*, SENDGRID_API_KEY, MAIL_TIMEOUT, etc.). |
| Email sending | `server/app/services/email_service.py` (SendGrid API when SENDGRID_API_KEY set, else SMTP). |
| Env template | `render.env.template` (reference for keys; do not commit secrets). |

---

## 6. Quick redeploy steps

1. **Commit and push** to your deploy branch (e.g. `mabunda_deployment`).
2. In **Render**: set **Branch** for recruitment-api and recruitment-web to that branch; trigger deploy (or rely on auto-deploy).
3. In **recruitment-api** env: confirm **DATABASE_URL**, **SECRET_KEY**, **JWT_SECRET_KEY**, **SENDGRID_API_KEY**, **MAIL_DEFAULT_SENDER**, **FRONTEND_URL**, **BACKEND_URL**.
4. In **recruitment-web** env: confirm **BACKEND_URL** = your recruitment-api URL.
5. After deploy: hit `/api/public/healthz`, then test login and one API call from the web app; optionally test registration and verification email.

For detailed troubleshooting (e.g. verification email, 409, CORS), see **RENDER_FEEDBACK.md** and **DEPLOYMENT.md**.

---

## 7. CORS and Render free-tier cold start

**CORS:** The API sends `Access-Control-Allow-Origin` on every response (including errors). In production, set **FRONTEND_URL** on **recruitment-api** to your web app URL exactly, e.g. `https://recruitment-web-59qy.onrender.com` (no trailing slash). If unset, all origins are allowed.

**“No 'Access-Control-Allow-Origin' header” / “Failed to fetch”:** On the free tier, the API **spins down after ~15 min of no traffic**. The first request after that can take 30–60s to wake the service. Render’s proxy may return **502/503** before the app is up; those responses do not include CORS headers, so the browser reports a CORS error. **Fix options:** (1) Open `https://<recruitment-api-url>/api/public/healthz` in a tab, wait until it returns `{"status":"ok"}`, then use the app; (2) Use a cron (e.g. cron-job.org) to GET the healthz URL every 10–14 minutes to keep the service awake; (3) Upgrade to a paid plan so the service does not spin down.

**401 “Missing or invalid JWT”:** Expected when the user is not logged in or the token expired. The frontend should redirect to login and store/refresh the token after successful auth.
