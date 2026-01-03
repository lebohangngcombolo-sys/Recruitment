from functools import wraps
from flask import jsonify, request
from flask_jwt_extended import (
    verify_jwt_in_request,
    get_jwt,
    get_jwt_identity,
    decode_token,
)
from werkzeug.exceptions import HTTPException
from app.models import User
import logging


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
                return "", 200

            try:
                jwt_verified = False
                claims = None
                identity = None

                # 1️⃣ Authorization header
                try:
                    verify_jwt_in_request()
                    claims = get_jwt()
                    identity = get_jwt_identity()
                    jwt_verified = True
                except Exception:
                    pass

                # 2️⃣ Cookie
                if not jwt_verified:
                    try:
                        verify_jwt_in_request(locations=["cookies"])
                        claims = get_jwt()
                        identity = get_jwt_identity()
                        jwt_verified = True
                    except Exception:
                        pass

                # 3️⃣ Query token
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

                token_role = claims.get("role")

                # Token role check
                if token_role in allowed_roles:
                    return fn(*args, **kwargs)

                # DB fallback
                if not identity:
                    return jsonify({"error": "Token identity missing"}), 401

                user = User.query.get(int(identity))
                db_role = user.role if user else None

                if db_role in allowed_roles:
                    return fn(*args, **kwargs)

                return jsonify({
                    "error": "Unauthorized access",
                    "required_roles": allowed_roles,
                    "your_role": token_role or db_role,
                }), 403

            except HTTPException:
                # 🔴 CRITICAL FIX:
                # Let Flask handle 400/404/409/etc correctly
                raise

            except Exception as e:
                logging.error(
                    "Role decorator unexpected exception",
                    exc_info=True,
                )
                return jsonify({
                    "error": "Authentication failure",
                }), 401

        return decorator
    return wrapper
