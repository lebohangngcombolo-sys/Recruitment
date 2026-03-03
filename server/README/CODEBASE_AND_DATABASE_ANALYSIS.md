# Codebase and database analysis — verification email and register flow

This document traces the registration and verification-email flow through the codebase and database to identify why new candidates may not receive the verification code.

---

## 1. Flow overview

```
[Flutter] POST /api/auth/register { email, password }
    → [auth.py] register()
    → AuthService.create_user(email, password)  → User created, committed
    → _email_configured() ?
        → NO: return 201 + access_token, user goes to enrollment
        → YES: create VerificationCode, commit, EmailService.send_verification_email(email, code), return 201 + message
    → [Flutter] 201 + no access_token → navigate to /verify-email?email=...
```

---

## 2. Backend: auth routes (`server/app/routes/auth.py`)

### 2.1 Register (lines 324–406)

- **Input:** `email`, `password` only (first_name/last_name in body are ignored for this route).
- **User creation:** `AuthService.create_user(email, password)` commits the user; on duplicate email raises `ValueError` → 409 "User already exists".
- **Email configured?** `_email_configured()` requires:
  - `MAIL_USERNAME` (truthy)
  - `MAIL_PASSWORD` (truthy)
  - `MAIL_DEFAULT_SENDER` or `MAIL_USERNAME` (as sender)
- **When email is configured:**
  - Code: `secrets.randbelow(1_000_000)` formatted to 6 digits.
  - Old unused codes for that email are deleted; new `VerificationCode` row is added and committed.
  - `EmailService.send_verification_email(email, code)` is called (fire-and-forget thread).
  - Response: 201 with `{ "message": "User registered successfully. Please check your email for verification code." }` (no tokens).

### 2.2 Verify email (lines 446–480)

- **Input:** `email`, `code`.
- Looks up `VerificationCode` by email + code, `is_used=False`, newest first; checks `is_valid()` (not used, not expired).
- Marks code used, sets `user.is_verified = True`, returns tokens.

---

## 3. Database: relevant models

### 3.1 `users` (model `User`)

- `email` unique, not null.
- `is_verified` default False.
- Register creates one row per new email; 409 if email already exists.

### 3.2 `verification_codes` (model `VerificationCode`)

- Columns: `id`, `email`, `code`, `is_used`, `created_at`, `expires_at`.
- No unique constraint on `(email, code)`; multiple rows possible for same email (old ones deleted before insert for that email).
- `is_valid()`: `not is_used and datetime.utcnow() < expires_at`.
- Verify endpoint uses `.order_by(VerificationCode.created_at.desc()).first()` so the latest code wins.

**Conclusion:** Schema and usage are consistent. Code is stored before the email is sent.

---

## 4. Email service (`server/app/services/email_service.py`)

### 4.1 `send_verification_email(email, verification_code)`

- Builds HTML from template `email_templates/verification_email.html` (or plain fallback).
- Logs: `Sending verification email to <email>`.
- Calls `send_async_email(subject, [email], html)` (no `text_body`; Flask-Mail will use HTML).

### 4.2 `send_async_email(subject, recipients, html_body, text_body=None)`

- **Current behavior:** Creates a **new** Flask app with `create_app()` and starts a background thread that runs `send_email(app, ...)` with `app.app_context()`.
- **Possible issue:** The global `mail` extension is bound to the **worker’s** app (the one that served the request). The thread pushes a **different** app’s context (the one from `create_app()`). Flask-Mail uses `current_app` when sending; in the thread `current_app` is the new app. Config for that app is loaded from the same `Config` (env vars), so in practice it’s usually the same. However, using the **request app** in the thread is safer and avoids any per-app state confusion.
- **Error visibility:** Exceptions in the thread are only logged (`logging.error("Failed to send email to ...")`). The HTTP response is already 201, so the client never sees send failures. To see why emails don’t arrive, you **must** check **recruitment-api** logs on Render for:
  - `Sending verification email to <email>`
  - `Email sent successfully to ...` or `Failed to send email to ...`

---

## 5. Config (`server/app/config.py`)

- **MAIL_***: `MAIL_SERVER`, `MAIL_PORT`, `MAIL_USE_TLS`, `MAIL_USERNAME`, `MAIL_PASSWORD`, `MAIL_DEFAULT_SENDER` all from env; no defaults for USERNAME/PASSWORD/SENDER (so they can be unset).
- On Render, if any of the three required for `_email_configured()` are missing or empty, the backend **does not** send email and returns tokens instead; the user would go to enrollment, not the verify screen.

---

## 6. Frontend: register and verify

### 6.1 Register (`khono_recruite/lib/screens/auth/register_screen.dart`)

- Sends `email`, `password`, `first_name`, `last_name`, `role` to `AuthService.register()`.
- On 201 with `access_token`: saves tokens and user, navigates to dashboard/enrollment.
- On 201 without `access_token`: navigates to `/verify-email?email=...`.
- On 409: shows “An account with this email already exists. Please log in or use a different email.”
- Token storage is web-safe (SharedPreferences on web).

### 6.2 Verify screen (`verification_screen.dart`)

- Shows “Code sent to &lt;email&gt;” and “Check your spam folder if you don’t see it in a few minutes.”
- Submits `email` + `code` to `AuthService.verifyEmail()` → POST `/api/auth/verify`.
- On success, navigates to enrollment with token.

---

## 7. Root-cause checklist (why verification code not received)

| # | Check | Where / how |
|---|--------|-------------|
| 1 | **MAIL_* set on Render?** | recruitment-api → Environment: MAIL_USERNAME, MAIL_PASSWORD, MAIL_DEFAULT_SENDER (and MAIL_SERVER, MAIL_PORT, MAIL_USE_TLS). If not, backend returns tokens and no email is sent. |
| 2 | **Register request hits API?** | In Render logs, after a register you should see a POST to `/api/auth/register` (or similar) and then `Sending verification email to <email>`. If you never see “Sending verification email”, either the request didn’t reach the API or _email_configured() is False. |
| 3 | **SMTP failure?** | In recruitment-api logs, look for `Failed to send email to ['...']: <error>`. That message includes the exception (e.g. auth failure, sender not verified). |
| 4 | **SendGrid sender** | If using SendGrid: MAIL_USERNAME = `apikey`, MAIL_PASSWORD = API key (no spaces). MAIL_DEFAULT_SENDER must be a **verified sender** in SendGrid. |
| 5 | **Spam / delivery** | User should check spam/junk. Some domains filter or delay mail. |
| 6 | **Background thread** | Email is sent in a daemon thread. Using the request app in that thread (see fix below) avoids any cross-app config/state issues. |

---

## 8. Recommended fix for email thread

Use the **request app** in the background thread when available, so the same app (and mail config/state) that served the request is used to send the email. Only create a new app when there is no request context (e.g. script or cron).

**In `email_service.py` → `send_async_email`:**

- Before starting the thread, try `app = current_app._get_current_object()` (inside a try/except for `RuntimeError`); if that fails, use `app = create_app()`.
- Pass this `app` into the thread and use it in `with app.app_context():` as now.

This keeps behavior the same when there is no request context but ensures that when register (or any view) triggers the email, the thread uses the same app that has the correct MAIL_* and initialized mail.

---

## 9. Summary

- **Database and register/verify logic:** Verification codes are created and committed before sending; verify endpoint and models are consistent. No DB bug identified for “code not received.”
- **Email path:** Sending is asynchronous and failures only appear in logs. You must check **recruitment-api** logs on Render for “Sending verification email” and “Failed to send email to” to see the real error.
- **Config:** Ensure MAIL_* is set on Render so the backend actually sends email and the user sees the verify screen (and so logs show the send attempt).
- **Improvement:** Use the request app in the email thread when in a request context to avoid any cross-app/mail-state issues.
