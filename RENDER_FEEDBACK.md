# Render feedback checklist

Use this when something isn’t working on Render (e.g. no verification email, 409 errors, API not reached).

---

## 1. Recruitment-web build

| What to check | Where | What to do |
|---------------|--------|------------|
| **BACKEND_URL set?** | recruitment-web → Environment | If missing, build log will show `API_BASE=http://127.0.0.1:5001`. Set **BACKEND_URL** = `https://recruitment-api-zovg.onrender.com` (or your API URL), save, then **redeploy** so the next build uses it. |
| Build log | recruitment-web → Logs (build) | Look for `Building Flutter web with API_BASE=...`. It should be your API URL, not `http://127.0.0.1:5001`. |

---

## 2. Recruitment-api – verification email not received

| What to check | Where | What to do |
|---------------|--------|------------|
| **MAIL_*** | recruitment-api → Environment | Need **MAIL_USERNAME**, **MAIL_PASSWORD**, **MAIL_DEFAULT_SENDER** (and MAIL_SERVER, MAIL_PORT, MAIL_USE_TLS). If any missing, backend does **not** send email and returns tokens instead (user goes to enrollment). |
| **Logs right after register** | recruitment-api → Logs (live tail) | Have someone register, then immediately check logs. Look for: **`Sending verification email to <email>`** (attempt), **`Email sent successfully to ...`** (OK), **`Failed to send email to ...`** (SMTP error + reason). If you see none of these, either no request hit the API or email path wasn’t used. |
| SendGrid | If using SendGrid | MAIL_USERNAME = exactly `apikey`; MAIL_PASSWORD = API key (no spaces). **MAIL_DEFAULT_SENDER** must be a **verified sender** in SendGrid (Settings → Sender Authentication). |
| Spam | User’s inbox | Ask user to check spam/junk for the verification email. |

---

## 3. 409 on register

| Meaning | User message |
|--------|---------------|
| **409 Conflict** | “User already exists” – the email is already registered. |
| In the app | User now sees: *“An account with this email already exists. Please log in or use a different email.”* They should log in or register with another email. |

---

## 4. Other browser messages

| Message | Meaning |
|---------|--------|
| **Failed to load resource: 409** | Same as above – register returned 409 (email already exists). |
| **Form field should have id or name** | Accessibility/autofill hint; does not block verification or login. |
| **Node cannot be found in the current page** | Usually from an extension or DevTools; not from your app. |

---

## 5. Quick verification-email debug

1. In **recruitment-api** → Environment, confirm **MAIL_USERNAME**, **MAIL_PASSWORD**, **MAIL_DEFAULT_SENDER** are set. Save and redeploy if you changed them.
2. Open **recruitment-api** → **Logs** and keep “Live tail” or refresh.
3. From the **deployed** site, register with a **new** email (not one that already exists).
4. In the logs, within a few seconds you should see either:
   - `Sending verification email to <that email>` then `Email sent successfully to ...`, or  
   - `Failed to send email to ...` with an error (e.g. SMTP auth, sender not verified).
5. If you see **no** “Sending verification email” line, the register request may not be reaching the API (e.g. wrong API URL) or MAIL_* is unset so the backend returns tokens and no email.

---

## 6. Summary

- **No verification code:** Set MAIL_* on recruitment-api, redeploy, then check API logs when someone registers (see §2 and §5).
- **409 on register:** Email already registered; user should log in or use another email (message is now clear in the app).
- **Web app calling wrong API:** Set BACKEND_URL on recruitment-web to your API URL and redeploy (see §1).
