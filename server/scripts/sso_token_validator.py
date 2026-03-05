#!/usr/bin/env python3
"""
Validate SSO (ARW/hub) JWT token against expected payload.

Payload: user_id, email, full_name, roles (ARW - Admin, ARW - Hiring Manager, etc.), iat, exp.
Reads SSO_DECRYPTION_KEY and SSO_JWT_SECRET (or ENCRYPTION_KEY / HUB_JWT_SECRET) from server/.env – same as app.

Usage:
  python scripts/sso_token_validator.py <token>
  echo "<token>" | python scripts/sso_token_validator.py
"""
import os
import sys
import json

SERVER_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, SERVER_DIR)
os.chdir(SERVER_DIR)

_env_path = os.path.join(SERVER_DIR, ".env")
if os.path.isfile(_env_path):
    from dotenv import load_dotenv
    load_dotenv(_env_path)
else:
    print("WARNING: server/.env not found; SSO_* env vars must be set elsewhere")

# Optional: load after path is set so app can be imported if needed
import jwt as pyjwt


REQUIRED_CLAIMS = ("user_id", "email", "full_name", "roles", "iat", "exp")


def _decode_token(raw: str, secret: str, decryption_key):
    """Decrypt if needed, then decode JWT. Returns (payload, None) or (None, error_msg)."""
    jwt_string = raw
    if decryption_key:
        try:
            from cryptography.fernet import Fernet
        except ImportError:
            return None, "SSO_DECRYPTION_KEY set but cryptography.fernet not available"
        try:
            key_bytes = decryption_key.encode("utf-8") if isinstance(decryption_key, str) else decryption_key
            ciphertext = raw.encode("utf-8") if isinstance(raw, str) else raw
            jwt_string = Fernet(key_bytes).decrypt(ciphertext).decode("utf-8")
        except Exception as e:
            return None, f"Decryption failed: {e}"

    try:
        payload = pyjwt.decode(jwt_string, secret, algorithms=["HS256"])
        return payload, None
    except pyjwt.ExpiredSignatureError:
        return None, "Token has expired (exp in the past)"
    except pyjwt.InvalidTokenError as e:
        return None, f"Invalid JWT: {e}"


def _validate_payload(payload: dict) -> list[str]:
    """Return list of validation errors (empty if valid)."""
    errors = []
    for key in REQUIRED_CLAIMS:
        if key not in payload:
            errors.append(f"Missing required claim: {key}")
            continue
        val = payload[key]
        if key == "user_id" and not isinstance(val, str):
            errors.append("user_id must be a string")
        elif key == "email" and not isinstance(val, str):
            errors.append("email must be a string")
        elif key == "full_name" and not isinstance(val, str):
            errors.append("full_name must be a string")
        elif key == "roles" and not isinstance(val, list):
            errors.append("roles must be a list")
        elif key in ("iat", "exp") and not isinstance(val, (int, float)):
            errors.append(f"{key} must be a number (Unix timestamp)")
    return errors


def main():
    raw = None
    if len(sys.argv) >= 2:
        raw = sys.argv[1].strip()
    if not raw and not sys.stdin.isatty():
        raw = sys.stdin.read().strip()
    if not raw:
        print("Usage: python scripts/sso_token_validator.py <token>", file=sys.stderr)
        print("   or: echo '<token>' | python scripts/sso_token_validator.py", file=sys.stderr)
        sys.exit(2)

    secret = (os.environ.get("SSO_JWT_SECRET") or os.environ.get("HUB_JWT_SECRET") or os.environ.get("JWT_SECRET_KEY") or "").strip()
    if not secret:
        print("ERROR: Set SSO_JWT_SECRET in server/.env (must match hub JWT_SECRET_KEY)", file=sys.stderr)
        sys.exit(1)

    decryption_key = (os.environ.get("SSO_DECRYPTION_KEY") or os.environ.get("ENCRYPTION_KEY") or "").strip() or None

    payload, decode_err = _decode_token(raw, secret, decryption_key)
    if decode_err:
        print("VALIDATION: FAILED")
        print(f"Reason: {decode_err}")
        sys.exit(1)

    errors = _validate_payload(payload)
    if errors:
        print("VALIDATION: FAILED")
        for e in errors:
            print(f"  - {e}")
        print("\nPayload (for reference):")
        print(json.dumps({k: payload.get(k) for k in payload if not k.startswith("_")}, indent=2))
        sys.exit(1)

    print("VALIDATION: OK")
    print("\nPayload:")
    out = {k: payload.get(k) for k in REQUIRED_CLAIMS if k in payload}
    for k, v in payload.items():
        if k not in out and not k.startswith("_"):
            out[k] = v
    print(json.dumps(out, indent=2))
    if payload.get("roles"):
        print("\nRoles (ARW): " + ", ".join(str(r) for r in payload["roles"]))
    sys.exit(0)


if __name__ == "__main__":
    main()
