#!/usr/bin/env python3
"""
SSO test script: decode the test token, show payload and where the user will be taken.

Uses the same keys as the app (SSO_DECRYPTION_KEY, SSO_JWT_SECRET from .env).
Run from server/: python scripts/sso_test_script.py

The token can be pasted on the app login screen in the "ARW SSO (paste token)" field;
click "Login with token" to sign in and be redirected to the correct dashboard by role.
"""
import os
import sys
import json
import base64
import hashlib
from datetime import datetime, timezone

SERVER_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, SERVER_DIR)
os.chdir(SERVER_DIR)

_env_path = os.path.join(SERVER_DIR, ".env")
if os.path.isfile(_env_path):
    from dotenv import load_dotenv
    load_dotenv(_env_path)
else:
    print("WARNING: server/.env not found")

import jwt as pyjwt

# Test token (Fernet-encrypted JWT) – created with hub's JWT_SECRET_KEY and ENCRYPTION_KEY (set as SSO_JWT_SECRET and SSO_DECRYPTION_KEY in .env)
SSO_TEST_TOKEN = (
    "gAAAAABpqMCj_Nvjcs2UdpEW17klV9WaBIUUPLXfR_oeWMb1tyjvw9Xkeoe3O_a9iAxDSmcCVQ8Xf2bB06P1vXftHRt5J6shaYmJT8cJqniXfIuoUgFlC8mK4NelrGo0UNWCLbQz-omFeKrC-b3guGj_2MLHCS140UYhjDUqjgXzBD4Qfg7R0Jj_VnEzKaeDvqTaI-zNpF-MGiIax21MGb8n6xBkwYYJTs4ew3mbb5Jb6oDly5lbfeccICz-isEhPAWt_kvAy6mKUxJ-JRnv4m_qA2I94rT9o5Y9OxKr2dmgEJ3cvhZJCaQBdNLVhrkYOSa-vej_mszlc2m2CzCy6AjLCzphRB2KG6zqiMgQRtu2m1UU4RnpB3rCkvMMB8ak8b-nAYb0zBLn0URATVphxwv0oazQUmc8xwWsgy5Ja1DaA960TrB4GrOvmnwjAMlPTER9Yj-ghzkl"
)


def _normalize_key(s):
    """Strip whitespace and optional surrounding quotes from env value."""
    if not s or not isinstance(s, str):
        return s
    s = s.strip().strip('"\'')
    return s or None


def _decode_token(raw: str, secret: str, decryption_key, jwt_secret_fallback=None):
    """Decrypt if needed, then decode JWT. Returns (payload, None) or (None, error_msg)."""
    raw = (raw or "").strip()
    secret = _normalize_key(secret)
    decryption_key = _normalize_key(decryption_key) if decryption_key else None
    jwt_secret_fallback = _normalize_key(jwt_secret_fallback) if jwt_secret_fallback else None

    # 1) Try plain JWT decode first (unencrypted signed token)
    try:
        payload = pyjwt.decode(raw, secret, algorithms=["HS256"])
        return payload, None
    except pyjwt.ExpiredSignatureError:
        return None, "Token has expired (exp in the past)"
    except pyjwt.InvalidTokenError:
        pass

    # 2) Try decrypt then decode (Fernet-encrypted token)
    jwt_string = None
    if decryption_key or jwt_secret_fallback:
        try:
            from cryptography.fernet import Fernet, InvalidToken
        except ImportError:
            return None, "cryptography.fernet not available"
        ciphertext = raw.encode("utf-8") if isinstance(raw, str) else raw
        keys_to_try = [decryption_key] if decryption_key else []
        if jwt_secret_fallback and jwt_secret_fallback not in keys_to_try:
            keys_to_try.append(jwt_secret_fallback)
        # Some hubs derive Fernet key from secret: SHA256(secret) -> 32 bytes -> base64url
        for s in (decryption_key, jwt_secret_fallback):
            if s and s not in keys_to_try:
                derived = base64.urlsafe_b64encode(hashlib.sha256(s.encode()).digest()).decode()
                keys_to_try.append(derived)
        last_error = None
        for key in keys_to_try:
            if not key:
                continue
            try:
                key_bytes = key.encode("utf-8") if isinstance(key, str) else key
                jwt_string = Fernet(key_bytes).decrypt(ciphertext).decode("utf-8")
                break
            except InvalidToken:
                last_error = "InvalidToken (wrong key or token corrupted)"
                continue
            except Exception as e:
                last_error = f"{type(e).__name__}: {e}"
                continue
        if jwt_string is None:
            return None, last_error or "Decryption failed"

    if jwt_string is None:
        return None, "Token is not a valid JWT and decryption failed (no key worked)."
    try:
        payload = pyjwt.decode(jwt_string, secret, algorithms=["HS256"])
        return payload, None
    except pyjwt.ExpiredSignatureError:
        return None, "Token has expired (exp in the past)"
    except pyjwt.InvalidTokenError as e:
        return None, f"Invalid JWT after decryption: {e}"


def _hub_roles_to_app_role(roles):
    """Map hub roles (e.g. ARW - Admin, ARW - Hiring Manager) to app role."""
    if not roles:
        return "candidate"
    roles_lower = [r.lower() if isinstance(r, str) else "" for r in roles]
    if any("admin" in r for r in roles_lower):
        return "admin"
    if any("hr" in r for r in roles_lower):
        return "hr"
    if any("manager" in r for r in roles_lower):
        return "hiring_manager"
    return "candidate"


def _app_role_to_destination(role: str) -> tuple:
    """Return (screen name, Flutter route) for the given app role."""
    destinations = {
        "admin": ("Admin Dashboard", "/admin-dashboard"),
        "hiring_manager": ("Hiring Manager Screen", "/hiring-manager-dashboard"),
        "hr": ("HR Dashboard", "/hr-dashboard"),
        "candidate": ("Candidate Dashboard", "/candidate-dashboard"),
    }
    return destinations.get(role, ("Candidate Dashboard", "/candidate-dashboard"))


def main():
    print("=" * 60)
    print("SSO Test Script – token decode and destination")
    print("=" * 60)

    secret = _normalize_key(os.environ.get("SSO_JWT_SECRET") or os.environ.get("HUB_JWT_SECRET") or os.environ.get("JWT_SECRET_KEY"))
    if not secret:
        print("\nERROR: Set SSO_JWT_SECRET in server/.env (must match hub JWT_SECRET_KEY)")
        sys.exit(1)

    decryption_key = os.environ.get("SSO_DECRYPTION_KEY") or os.environ.get("ENCRYPTION_KEY")
    decryption_key = _normalize_key(decryption_key) if decryption_key else None
    if not decryption_key:
        print("\nWARNING: SSO_DECRYPTION_KEY not set; token may be encrypted (decrypt will be skipped).")

    payload, err = _decode_token(
        SSO_TEST_TOKEN, secret, decryption_key, jwt_secret_fallback=secret
    )
    if err:
        print(f"\nDecode FAILED: {err}")
        print("  Ensure SSO_JWT_SECRET and SSO_DECRYPTION_KEY in server/.env match the hub ENCRYPTION_KEY and JWT_SECRET_KEY.")
        print("  If the hub uses one secret for both signing and encryption, the script will try both.")
        sys.exit(1)

    roles = payload.get("roles") or []
    if isinstance(payload.get("role"), str):
        roles = roles or [payload["role"]]
    app_role = _hub_roles_to_app_role(roles)
    screen_name, flutter_route = _app_role_to_destination(app_role)

    # ---- Token info ----
    print("\n--- Token payload (info when app works with this token) ---")
    for key in ("user_id", "email", "full_name", "roles", "iat", "exp"):
        v = payload.get(key)
        if key in ("iat", "exp") and v is not None:
            try:
                ts = int(v)
                v = f"{v}  ({datetime.fromtimestamp(ts, tz=timezone.utc).isoformat()})"
            except (TypeError, ValueError):
                pass
        print(f"  {key}: {json.dumps(v) if v is not None else 'N/A'}")
    extra = {k: v for k, v in payload.items() if k not in ("user_id", "email", "full_name", "roles", "iat", "exp")}
    if extra:
        print("  (other):", json.dumps(extra))

    print("\n--- Where the user will be taken ---")
    print(f"  Hub roles (ARW): {roles or ['(none)']}")
    print(f"  Mapped app role: {app_role}")
    print(f"  Screen:          {screen_name}")
    print(f"  Flutter route:   {flutter_route}")

    base_url = (os.environ.get("BASE_URL") or os.environ.get("FLASK_URL") or "").strip().rstrip("/")
    if base_url:
        sso_url = f"{base_url}/api/auth/sso-login?token={SSO_TEST_TOKEN[:20]}..."
        print(f"\n--- Optional: live SSO login ---")
        print(f"  If server is running at {base_url}, opening sso-login with this token")
        print(f"  would redirect the user to: {screen_name} ({flutter_route})")
        print(f"  URL (token truncated): {sso_url}")
    else:
        print("\n  Tip: Set BASE_URL in .env (e.g. http://localhost:5000) to see live sso-login URL.")

    print("\n" + "=" * 60)
    print("SSO test finished successfully.")
    print("=" * 60)


if __name__ == "__main__":
    main()
