#!/usr/bin/env python3
"""
Hit multiple API services and report status. Use to see if anything budges (local or Render).

Usage:
  python scripts/test_services.py [BASE_URL]
  # Or set env and run:
  set BASE_URL=https://recruitment-api.onrender.com
  set TEST_EMAIL_SECRET=your_secret
  set TEST_EMAIL=you@example.com
  python scripts/test_services.py

Defaults: BASE_URL=http://localhost:5001
"""

import os
import sys
import json
import urllib.request
import urllib.error
import ssl

def req(method, url, data=None, headers=None, timeout=15):
    headers = dict(headers or {})
    headers.setdefault("Content-Type", "application/json")
    if data is not None and isinstance(data, (dict, list)):
        data = json.dumps(data).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    ctx = ssl.create_default_context()
    if url.startswith("https://"):
        ctx.check_hostname = True
        ctx.verify_mode = ssl.CERT_REQUIRED
    return urllib.request.urlopen(req, timeout=timeout, context=ctx)

def test(name, method, path, base, **kwargs):
    url = base.rstrip("/") + path
    try:
        r = req(method, url, **kwargs)
        body = r.read().decode("utf-8", errors="replace")
        try:
            j = json.loads(body) if body else {}
            summary = json.dumps(j)[:80] + ("..." if len(body) > 80 else "")
        except Exception:
            summary = body[:80] or "(empty)"
        print(f"  {name}: {r.status} OK — {summary}")
        return r.status, None
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace") if e.fp else ""
        print(f"  {name}: {e.code} — {body[:100] or e.reason}")
        return e.code, body
    except Exception as e:
        print(f"  {name}: ERROR — {e}")
        return None, str(e)

def main():
    base = (sys.argv[1] if len(sys.argv) > 1 else None) or os.environ.get("BASE_URL", "http://localhost:5001")
    secret = os.environ.get("TEST_EMAIL_SECRET", "").strip()
    test_email = os.environ.get("TEST_EMAIL", "").strip() or "test@example.com"
    # Render free tier cold start can take 30–60s; first request may timeout
    health_timeout = int(os.environ.get("TEST_SERVICES_HEALTH_TIMEOUT", "60"))
    other_timeout = int(os.environ.get("TEST_SERVICES_TIMEOUT", "25"))

    print(f"Testing services at: {base}\n")
    if "onrender.com" in base:
        print("  (Render: first request may take 30–60s if instance was sleeping.)\n")

    # 1) Health (no DB) — should always 200 if process is up; use long timeout to wake Render
    test("GET /api/public/healthz", "GET", "/api/public/healthz", base, timeout=health_timeout)

    # 2) Public jobs (hits DB) — 200 or 500
    test("GET /api/public/jobs", "GET", "/api/public/jobs", base, timeout=other_timeout)

    # 3) Login with bad body — expect 400/422 (service is up)
    test("POST /api/auth/login (bad body)", "POST", "/api/auth/login", base, data={}, timeout=other_timeout)

    # 4) Resend verification no body — expect 400
    test("POST /api/auth/resend-verification (no body)", "POST", "/api/auth/resend-verification", base, data={}, timeout=other_timeout)

    # 5) Test email (async) — only if secret set
    if secret:
        test(
            "POST /api/auth/test-email (async)",
            "POST",
            "/api/auth/test-email",
            base,
            data={"email": test_email},
            headers={"X-Test-Email-Secret": secret},
            timeout=other_timeout,
        )
        # 6) Test email sync — longer timeout (SMTP can be slow)
        test(
            "POST /api/auth/test-email?sync=1 (sync)",
            "POST",
            "/api/auth/test-email?sync=1",
            base,
            data={"email": test_email},
            headers={"X-Test-Email-Secret": secret},
            timeout=35,
        )
    else:
        print("  POST /api/auth/test-email: skipped (set TEST_EMAIL_SECRET to enable)")

    print("\nDone. Check Render logs for 'queued' / 'Sending verification email' / 'Email sent successfully'.")

if __name__ == "__main__":
    main()
