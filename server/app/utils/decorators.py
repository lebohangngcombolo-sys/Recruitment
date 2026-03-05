from functools import wraps
import jwt as pyjwt
from flask import jsonify, request, current_app, g
from werkzeug.exceptions import HTTPException
from flask_jwt_extended import verify_jwt_in_request, get_jwt, get_jwt_identity, decode_token
from app.models import User
import logging


def _normalize_key(s):
    """Strip whitespace and optional surrounding quotes from env/config value."""
    if s is None:
        return None
    if not isinstance(s, str):
        return s
    s = s.strip().strip('"\'')
    return s or None


def _decode_khonobuzz_token(raw, secret, decryption_key, secret_as_fallback_key=False):
    """
    Decode Khonobuzz token: validate with SSO_JWT_SECRET; if token is encrypted, decrypt with SSO_DECRYPTION_KEY first.
    Returns (payload dict, None) on success or (None, error_response_tuple) on failure.
    """
    raw = (raw or "").strip()
    secret = _normalize_key(secret)
    decryption_key = _normalize_key(decryption_key) if decryption_key else None

    # 1) Try direct JWT decode (plain signed token)
    try:
        payload = pyjwt.decode(raw, secret, algorithms=["HS256"])
        return payload, None
    except pyjwt.ExpiredSignatureError:
        logging.error("Khonobuzz JWT invalid: token has expired")
        return None, ({"error": "Khonobuzz SSO token has expired"}, 401)
    except pyjwt.InvalidTokenError:
        pass  # Not a valid JWT; try decrypt then decode if we have a decryption key

    # 2) If direct decode failed, try decrypt then validate JWT
    keys_to_try = []
    if decryption_key:
        keys_to_try.append(decryption_key)
    if secret_as_fallback_key and secret and secret not in keys_to_try:
        keys_to_try.append(secret)
    if not keys_to_try:
        logging.error("Khonobuzz JWT invalid: token could not be decoded and no decryption key configured")
        return None, ({"error": "Invalid Khonobuzz SSO token"}, 401)
    try:
        from cryptography.fernet import Fernet, InvalidToken
    except ImportError:
        logging.error("Khonobuzz JWT: decryption key set but cryptography.fernet not available")
        return None, ({"error": "Server misconfiguration: decryption not available"}, 500)
    ciphertext = raw.encode("utf-8") if isinstance(raw, str) else raw
    jwt_string = None
    for key in keys_to_try:
        try:
            key_bytes = key.encode("utf-8") if isinstance(key, str) else key
            jwt_string = Fernet(key_bytes).decrypt(ciphertext).decode("utf-8")
            break
        except InvalidToken:
            continue
    if jwt_string is None:
        logging.error("Khonobuzz JWT decryption failed: InvalidToken (wrong key or corrupted token)")
        return None, ({"error": "Invalid or corrupted Khonobuzz SSO token (decryption failed)"}, 401)
    try:
        payload = pyjwt.decode(jwt_string, secret, algorithms=["HS256"])
        return payload, None
    except pyjwt.ExpiredSignatureError:
        logging.error("Khonobuzz JWT invalid: decrypted token has expired")
        return None, ({"error": "Khonobuzz SSO token has expired"}, 401)
    except pyjwt.InvalidTokenError as e:
        logging.error("Khonobuzz JWT invalid after decryption: %s", str(e))
        return None, ({"error": "Invalid Khonobuzz SSO token"}, 401)


def khonobuzz_jwt_required(fn):
    """
    Decorator that decrypts (if SSO_DECRYPTION_KEY set) and validates Khonobuzz (hub) JWT using SSO_JWT_SECRET.
    Expects payload: user_id, email, full_name, roles (list; ARW prefix e.g. ARW - Admin, ARW - Hiring Manager), iat, exp.
    On success, attaches to g.khonobuzz_user: user_id, email, full_name, roles, iat, exp.
    Expects token in Authorization: Bearer <token> or query param 'token'.
    """
    @wraps(fn)
    def decorator(*args, **kwargs):
        if request.method == "OPTIONS":
            return "", 200

        raw = None
        auth_header = request.headers.get("Authorization")
        if auth_header and auth_header.startswith("Bearer "):
            raw = auth_header[7:].strip()
        if not raw:
            raw = request.args.get("token")
        if not raw and request.method == "POST":
            body = request.get_json(silent=True) or {}
            raw = body.get("token") if isinstance(body, dict) else None
        if not raw:
            logging.error("Khonobuzz JWT missing: no token in Authorization header, query param 'token', or POST body 'token'")
            return jsonify({"error": "Khonobuzz JWT required: provide token in query, Authorization: Bearer <token>, or POST body { \"token\": \"...\" }"}), 401

        secret = current_app.config.get("SSO_JWT_SECRET")
        if not secret:
            logging.error("Khonobuzz JWT config error: SSO_JWT_SECRET is not set")
            return jsonify({"error": "Server misconfiguration: SSO not configured"}), 500

        decryption_key = (current_app.config.get("SSO_DECRYPTION_KEY") or "").strip() or None
        payload, err = _decode_khonobuzz_token(
            raw, secret, decryption_key, secret_as_fallback_key=True
        )
        if err:
            body, status = err
            return jsonify(body), status

        email = payload.get("email")
        if not email:
            logging.error("Khonobuzz JWT invalid: payload missing required claim 'email'")
            return jsonify({"error": "Invalid Khonobuzz SSO token: missing email"}), 401

        roles = payload.get("roles")
        if not isinstance(roles, list):
            roles = [payload.get("role")] if payload.get("role") else []

        g.khonobuzz_user = {
            "user_id": payload.get("user_id"),
            "email": email,
            "full_name": payload.get("full_name", ""),
            "roles": roles,
            "iat": payload.get("iat"),
            "exp": payload.get("exp"),
        }
        return fn(*args, **kwargs)

    return decorator

def role_required(*roles):
    allowed_roles = []
    for r in roles:
        if isinstance(r, (list, tuple)):
            allowed_roles.extend(r)
        else:
            allowed_roles.append(r)

    def wrapper(fn):
        @wraps(fn)
        def decorator(*args, **kwargs):
            # Allow CORS preflight
            if request.method == "OPTIONS":
                return '', 200

            try:
                jwt_verified = False
                claims = None
                identity = None

                # 1️⃣ Try JWT from Authorization Header
                try:
                    verify_jwt_in_request()
                    claims = get_jwt()
                    identity = get_jwt_identity()
                    jwt_verified = True
                except Exception:
                    pass

                # 2️⃣ Try JWT from Cookie
                if not jwt_verified:
                    try:
                        verify_jwt_in_request(locations=["cookies"])
                        claims = get_jwt()
                        identity = get_jwt_identity()
                        jwt_verified = True
                    except Exception:
                        pass

                # 3️⃣ Try JWT from URL Query (?access_token=...)
                if not jwt_verified:
                    access_token = request.args.get("access_token")
                    if access_token:
                        try:
                            claims = decode_token(access_token)
                            identity = claims.get("sub")
                            jwt_verified = True
                        except Exception as e:
                            logging.error(f"Failed to decode query token: {e}")

                if not jwt_verified:
                    return jsonify({"error": "Missing or invalid JWT"}), 401

                logging.info(f"JWT claims: {claims}, identity: {identity}")

                token_role = claims.get("role")
                logging.info(f"Token role: {token_role}, Allowed roles: {allowed_roles}")

                # ✅ Check role from token
                if token_role and token_role in allowed_roles:
                    return fn(*args, **kwargs)

                # ✅ Fallback to DB lookup if needed
                if not identity:
                    return jsonify({"error": "Token identity missing"}), 401

                user = User.query.get(int(identity))
                db_role = user.role if user else None
                logging.info(f"DB role: {db_role}")

                if db_role in allowed_roles:
                    return fn(*args, **kwargs)

                # ❌ Unauthorized role
                return jsonify({
                    "error": "Unauthorized access",
                    "required_roles": allowed_roles,
                    "your_role": token_role or db_role
                }), 403

            except HTTPException:
                raise
            except Exception as e:
                logging.error(f"Role decorator exception: {e}", exc_info=True)
                return jsonify({"error": "Invalid or expired token", "details": str(e)}), 401

        return decorator
    return wrapper
