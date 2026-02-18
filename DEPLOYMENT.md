# Deployment Guide — Render & PostgreSQL

**Just pushed?** → Go to **§0. Right after you push** and follow the steps on Render.

This document covers deployment readiness, the deployed database (PostgreSQL), and a checklist before pushing to your deployed branch.

---

## 0. Right after you push (do this on Render)

Follow these steps **after** you’ve run `git push origin mabunda1` (or your deploy branch).

### Step 1: Branch and deploy

1. Open [Render Dashboard](https://dashboard.render.com).
2. For **recruitment-api** and **recruitment-web**, open each service → **Settings**.
3. Set **Branch** to the branch you push (e.g. `mabunda1` or `mabunda_deployment`). Save.
4. If auto-deploy is on, Render will build and deploy. Otherwise click **Manual Deploy** → **Deploy latest commit**.

**If you deploy from `mabunda_deployment` instead of `mabunda1`:**  
You pushed `mabunda1`. If Render (or your process) is set to deploy from `mabunda_deployment`, merge and push:

```bash
git checkout mabunda_deployment
git merge mabunda1
git push origin mabunda_deployment
```

Then trigger or wait for deployment from `mabunda_deployment`. In Render, set **Branch** to `mabunda_deployment` for both services.

### Step 2: Environment variables — recruitment-api

In **recruitment-api** → **Environment**:

| Variable | What to set |
|----------|-------------|
| **DATABASE_URL** | Your Postgres URL (see §1 below). For existing DB `recruitment_db_vexi`, use its External URL; app adds `?sslmode=require` in production. |
| **SECRET_KEY** | Strong random string (e.g. `openssl rand -hex 32`). |
| **JWT_SECRET_KEY** | Another strong random string. |
| **FRONTEND_URL** | Your web app URL, e.g. `https://recruitment-web.onrender.com`. |
| **BACKEND_URL** | Your API URL, e.g. `https://recruitment-api.onrender.com`. |
| **REDIS_URL** | If you use Redis/Celery; otherwise leave unset (eager tasks). |
| **CLOUDINARY_*** | Cloud name, API key, API secret (if you use uploads). |
| **MAIL_*** | If you use password reset / email. |

Save. Redeploy the API so it picks up new values.

### Step 3: Environment variables — recruitment-web

In **recruitment-web** → **Environment**:

| Variable | What to set |
|----------|-------------|
| **BACKEND_URL** | **Required.** Your live API URL, e.g. `https://recruitment-api.onrender.com`. The Flutter build uses this so the app calls the deployed API. |
| **FRONTEND_URL** | Optional; e.g. `https://recruitment-web.onrender.com`. |

Save. **Redeploy recruitment-web** so the next build uses this `BACKEND_URL` (otherwise the app may still call `127.0.0.1`).

### Step 4: Verify

1. **API:** Open `https://<your-recruitment-api-url>/api/public/healthz` in a browser. You should see a healthy response.
2. **Web:** Open your recruitment-web URL. Log in and load a page that calls the API (e.g. jobs list). Confirm it uses the deployed backend (no CORS or connection errors).

If the API fails, check **recruitment-api** → **Logs** (e.g. migrations, `DATABASE_URL`, missing env). If the web app shows “failed to fetch” or wrong API, confirm **BACKEND_URL** is set for recruitment-web and redeploy.

### Step 5: SPA routes (fix 404 on /verify-email and other client routes)

The Flutter web app uses client-side routing (e.g. `/verify-email`, `/login`, `/candidate-dashboard`). When a user opens a direct link like `https://<recruitment-web>/verify-email?email=...`, the static server looks for a file at that path and returns **404** if you do not serve the app for all paths.

**Fix on Render:** In **recruitment-web** go to **Redirects/Rewrites** in the dashboard and add a **Rewrite** rule: Source `/*`, Destination `/index.html`, Action **Rewrite**. This returns `index.html` for any path that does not match a real file so the Flutter app loads and GoRouter can show the correct screen. Do not use Redirect.

---

## 1. Database (PostgreSQL) — Ready for Deploy

### Your deployed database

- **Internal URL** (use from another Render service in the same account):  
  `postgresql://USER:PASSWORD@HOST_INTERNAL/DATABASE`  
  (Get from Render Dashboard → your Postgres service → Internal Database URL.)
- **External URL** (use from your machine, CI, or if the app is not on Render):  
  `postgresql://USER:PASSWORD@HOST.oregon-postgres.render.com/DATABASE`  
  (Get from Render Dashboard → your Postgres service → External Database URL.)

**Do not commit real credentials.** Set DATABASE_URL in Render env (or .env locally) only.

Render Postgres requires SSL. The app **automatically appends `?sslmode=require`** in production when not already in the URL, so you can use either URL as-is.

### Option A: Use this existing database on Render (recruitment_db_vexi)

1. In **Render Dashboard** → your **recruitment-api** service → **Environment**.
2. Set **DATABASE_URL** to the External (or Internal) URL from your Render Postgres service. The app adds `?sslmode=require` in production if missing.
3. So that Render does not try to link a database named `recruitment-db`, either:
   - **Link** your existing Postgres to the service and in the service env **override** **DATABASE_URL** with the External URL from the Render Postgres dashboard, or  
   - In `render.yaml`, replace the `DATABASE_URL` entry with:
     ```yaml
     - key: DATABASE_URL
       sync: false
     ```
     and remove or comment out the `databases:` section if you do not need a new Postgres. Then set **DATABASE_URL** in the dashboard to the External URL.

### Option B: Create a new Render Postgres and link it

1. In `render.yaml`, the API service has:
   ```yaml
   - key: DATABASE_URL
     fromDatabase:
       name: recruitment-db
       property: connectionString
   ```
2. Create a **PostgreSQL** instance in Render named **recruitment-db** and link it to the **recruitment-api** service. Render will set `DATABASE_URL` automatically.

### Run migrations so the deployed DB is ready

Migrations run automatically on deploy via `render_start.sh` (`flask db upgrade`). To run them manually against the deployed DB (e.g. from your machine):

```bash
cd server
export DATABASE_URL="postgresql://recruitment_db_vexi_user:...@dpg-d64aam8gjchc739jpt5g-a.oregon-postgres.render.com/recruitment_db_vexi"
# Optional: add ?sslmode=require if your client needs it; the app adds it in production.
flask db upgrade
```

Migration chain (already in repo): `d544fdd839da` (init) → `33f86c05b761` → `b6b9a43a3778` → `20260216_fix_requisition_duplicates` → `20260216_add_indexes`.

---

## 2. Backend (recruitment-api) — Checklist

| Item | Status / Action |
|------|------------------|
| **FLASK_ENV** | Set to `production` in Render (already in `render.yaml`). |
| **DATABASE_URL** | Set to your Postgres URL (see §1). |
| **SECRET_KEY**, **JWT_SECRET_KEY** | Set strong secrets in Render; never commit. |
| **REDIS_URL** | Set for session/cache/celery (or use Redis from Render). |
| **FRONTEND_URL** | Your deployed Flutter web URL (e.g. `https://recruitment-web.onrender.com`). |
| **BACKEND_URL** | Your deployed API URL (e.g. `https://recruitment-api.onrender.com`). |
| **Cloudinary** | CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET set (required in production). |
| **Email** | MAIL_* set if you use password reset / notifications. |
| **AI keys** | OPENROUTER_API_KEY / DEEPSEEK_API_KEY / GEMINI_API_KEY if you use those features. |
| **CORS** | Backend allows origins via config; set FRONTEND_URL so only your frontend is allowed if you tighten CORS later. |
| **Health check** | `GET /api/public/healthz` used in Render; no auth. |
| **Start** | `render_start.sh` runs `flask db upgrade` then gunicorn with eventlet. |

---

## 3. Frontend (recruitment-web, Flutter) — Checklist

| Item | Status / Action |
|------|------------------|
| **API base URL** | Set **BACKEND_URL** (or **API_BASE**) in the **recruitment-web** service env on Render to your **recruitment-api** URL. `render_build.sh` passes it as `--dart-define=API_BASE` and `PUBLIC_API_BASE` so the built app calls the deployed API. |
| **FRONTEND_URL** | Optional for static site; can match the web app URL for consistency. |
| **Build** | `render_build.sh` runs `flutter build web --release` with the above dart-defines. |

---

## 4. Codebase changes made for deployment

- **Email reset link**: Uses `FRONTEND_URL` from config (no hardcoded localhost).
- **Flutter web**: Build uses `BACKEND_URL` / `API_BASE` from env so production build points to the deployed API.
- **Database URL**: In production, `sslmode=require` is appended if missing.
- **Render**: `render.yaml` sets `FLASK_ENV=production`; static site has `BACKEND_URL` and `FRONTEND_URL` for build-time config.
- **OpenRouter referer**: Uses `BACKEND_URL` from env when set.

---

## 5. Before you push to the deployed branch

1. **Secrets**: Ensure no real secrets in repo; use Render env (and `.env` only locally, in `.gitignore`).
2. **.env**: Keep `.env` out of git; use `render.env.template` as a reference for required keys.
3. **Migrations**: All migrations committed and in order; run `flask db upgrade` against the deployed DB (or rely on deploy).
4. **API ↔ Web**: After deploy, set **BACKEND_URL** for recruitment-web to the live API URL and redeploy the web service (see **§0 Step 3**).
5. **Smoke test**: Open the deployed web app, log in, and call one API (e.g. jobs list) to confirm the app uses the deployed backend and DB.

---

## 6. Optional: MongoDB, Redis, Celery

- **MongoDB**: Set **MONGO_URI** and **MONGO_DB_NAME** if you use MongoDB (e.g. CV storage).
- **Redis**: Set **REDIS_URL** (or REDIS_HOST/PORT/PASSWORD) for cache/sessions; Celery can use the same for broker/backend.
- **Celery**: On Render free tier, `CELERY_TASK_ALWAYS_EAGER=true` runs tasks in-process (no separate worker). For a dedicated worker, add a background worker service and set the broker/backend URLs.

Your deployed PostgreSQL (recruitment_db_vexi) is ready to use: set **DATABASE_URL** for the API to the External (or Internal) URL above and run or deploy so that `flask db upgrade` has been applied.
