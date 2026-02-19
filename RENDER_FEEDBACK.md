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

## 3. “I only see healthz in the logs” / Nothing about email

If recruitment-api logs show **only** `GET /api/public/healthz` (every few seconds from `Render/1.0`), that’s **normal** when no one is triggering email or auth flows.

| What it means | What to do |
|---------------|------------|
| **Only healthz** | The only traffic is Render’s health checker. No register, resend, or test-email requests have hit the API. |
| **To see email-related lines** | 1) **Deploy** the branch that has the verification/resend/test-email routes and logging. 2) **Trigger** one of: a new **registration** from the deployed site, **Resend** on the verify screen, or **POST /api/auth/test-email** (with TEST_EMAIL_SECRET). Then check logs for: `Verification email queued for ...`, `Sending verification email to ...`, and either `Email sent successfully to ...` or `Failed to send email to ...`. |
| **POST /api/auth/resend-verification → 404** | The **deployed** build doesn’t have that route yet (older branch or not redeployed). Deploy the branch that adds `resend-verification`, then redeploy recruitment-api. After that, the same request should return 400 (e.g. “Email is required”) when called with no body, not 404. |

So: **email service** is used only when register, resend, or test-email is called. If those aren’t in the logs, either the routes aren’t deployed or no one has hit them yet.

---

## 4. 409 on register

| Meaning | User message |
|--------|---------------|
| **409 Conflict** | “User already exists” – the email is already registered. |
| In the app | User now sees: *“An account with this email already exists. Please log in or use a different email.”* They should log in or register with another email. |

---

## 5. Other browser messages

| Message | Meaning |
|---------|--------|
| **Failed to load resource: 409** | Same as above – register returned 409 (email already exists). |
| **Form field should have id or name** | Accessibility/autofill hint; does not block verification or login. |
| **Node cannot be found in the current page** | Usually from an extension or DevTools; not from your app. |

---

## 6. Quick verification-email debug

1. In **recruitment-api** → Environment, confirm **MAIL_USERNAME**, **MAIL_PASSWORD**, **MAIL_DEFAULT_SENDER** are set. Save and redeploy if you changed them.
2. Open **recruitment-api** → **Logs** and keep “Live tail” or refresh.
3. From the **deployed** site, register with a **new** email (not one that already exists).
4. In the logs, within a few seconds you should see either:
   - `Sending verification email to <that email>` then `Email sent successfully to ...`, or  
   - `Failed to send email to ...` with an error (e.g. SMTP auth, sender not verified).
5. If you see **no** “Sending verification email” line, the register request may not be reaching the API (e.g. wrong API URL) or MAIL_* is unset so the backend returns tokens and no email.

---

## 7. Email works locally but not on Render

When verification email works on your machine but not on Render, the cause is usually **environment-specific** (SendGrid or network), not the code.

| Check | Action |
|-------|--------|
| **SendGrid sender verification** | Render uses a different outbound IP than your PC. In SendGrid: **Settings → Sender Authentication**. Ensure **MAIL_DEFAULT_SENDER** (e.g. `cyriltrump3@gmail.com`) is under **Single Sender Verification**. If not, add and verify it. |
| **API logs on register** | Right after someone registers on the **deployed** site, open recruitment-api → **Logs**. Look for **`Sending verification email to ...`** then either **`Email sent successfully to ...`** or **`Failed to send email to ...`** with the exact error (e.g. `Sender address rejected: not owned by auth user`). |
| **Test-email endpoint** | Set **TEST_EMAIL_SECRET** on recruitment-api. **Wake the instance first:** `curl https://<your-api>/api/public/healthz` then immediately `POST .../api/auth/test-email?sync=1` with header `X-Test-Email-Secret: <secret>` and body `{"email": "your@email.com"}`. **Use `?sync=1`** so the response returns 200 (success), 500 (error + message), or **504** (SMTP timed out after 25s — cold instance or slow SendGrid). |
| **Env var types** | MAIL_USE_TLS is already normalized in the app (`"True"`/`"true"` → boolean). No change needed unless you use a different config source. |
| **Outbound SMTP from Render** | Uncommon, but if logs show timeouts or connection refused, test from Render: **Shell** (or a one-off job) run: `python -c "import smtplib; s=smtplib.SMTP('smtp.sendgrid.net', 587); s.starttls(); s.login('apikey', 'YOUR_SENDGRID_API_KEY'); print('OK')"` (replace with your real key only in a private shell). If this fails, the error (auth, network, etc.) tells you the next step. |

After fixing sender verification or credentials, redeploy recruitment-api and test again with the test-email endpoint or a new registration.

---

## 8. “We used to see a pin” / verification code not visible

The **6-digit verification code (pin)** is **only sent by email**. The app never shows it in the UI or returns it in the register API (for security). So if the email doesn’t arrive, the user has nothing to type on the verify screen.

| What to do | Details |
|------------|--------|
| **Check email + spam** | The code is in the “Verify Your Email Address” email. If it’s not there, follow §2 and §6 (MAIL_*, SendGrid sender verification, API logs). |
| **Test with a known code (no email)** | For debugging only: `POST .../api/auth/test-send-verification-email` with header `X-Test-Email-Secret: <secret>` and body `{"email": "your@email.com"}`. The **response** includes `"code": "123456"`. You can enter **123456** on the verify screen to complete verification for that email (the test endpoint sends that code to the inbox too, if mail is working). |
| **curl test-email times out** | Free tier can be cold; sync send has a **25s timeout**. If you get **504** or curl times out: (1) Wake the instance: `GET .../api/public/healthz`, wait a few seconds. (2) Call `POST .../api/auth/test-email?sync=1` again. You should get 200, 500, or 504 in the response body. |

---

## 9. Summary

- **No verification code (pin):** The code is only in the email (§7). Set MAIL_* on recruitment-api, redeploy, then check API logs when someone registers (see §2 and §5). If it works locally but not on Render, see §6. For testing without email you can use test-send-verification-email (code 123456).
- **Test-email curl times out:** Wake the instance with healthz, then retry test-email?sync=1. Sync send now times out after 25s and returns 504 so you get a response.
- **409 on register:** Email already registered; user should log in or use another email (message is now clear in the app).
- **Web app calling wrong API:** Set BACKEND_URL on recruitment-web to your API URL and redeploy (see §1).
