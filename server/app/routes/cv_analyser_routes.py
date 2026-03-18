from flask import Blueprint, request, jsonify, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity
import os
import requests
import time
import jwt


cv_analyser_bp = Blueprint("cv_analyser", __name__)


def _get_cv_analyser_base_url() -> str:
    return (os.getenv("CV_ANALYSER_BASE_URL") or "https://cv-analyser-kt1u.onrender.com").rstrip("/")


def _get_cv_analyser_signing_secret() -> str | None:
    return os.getenv("CV_ANALYSER_SIGNING_SECRET") or os.getenv("SIGNING_SECRET")


def _make_upstream_bearer_token(signing_secret: str) -> str:
    now = int(time.time())
    payload = {
        "sub": "recruitment-backend-proxy",
        "iat": now,
        "exp": now + 60 * 5,
    }
    return jwt.encode(payload, signing_secret, algorithm="HS256")


def _should_retry_with_jwt(resp: requests.Response) -> bool:
    if resp.status_code != 403:
        return False
    try:
        payload = resp.json()
    except Exception:
        payload = None
    if isinstance(payload, dict) and payload.get("detail") == "invalid token":
        return True
    return False


def _post_upstream_with_auth_fallback(
    upstream_url: str,
    signing_secret: str,
    *,
    data: dict,
    files: dict,
    timeout: int,
) -> requests.Response:
    # Prefer raw secret first (matches simple equality checks), then retry with JWT.
    resp = requests.post(
        upstream_url,
        headers={"Authorization": f"Bearer {signing_secret}"},
        data=data,
        files=files,
        timeout=timeout,
    )
    if _should_retry_with_jwt(resp):
        upstream_token = _make_upstream_bearer_token(signing_secret)
        resp = requests.post(
            upstream_url,
            headers={"Authorization": f"Bearer {upstream_token}"},
            data=data,
            files=files,
            timeout=timeout,
        )
    return resp


def _get_upstream_with_auth_fallback(
    upstream_url: str,
    signing_secret: str,
    *,
    timeout: int,
) -> requests.Response:
    resp = requests.get(
        upstream_url,
        headers={"Authorization": f"Bearer {signing_secret}"},
        timeout=timeout,
    )
    if _should_retry_with_jwt(resp):
        upstream_token = _make_upstream_bearer_token(signing_secret)
        resp = requests.get(
            upstream_url,
            headers={"Authorization": f"Bearer {upstream_token}"},
            timeout=timeout,
        )
    return resp


def _json_or_text_response(resp: requests.Response):
    try:
        return resp.json()
    except Exception:
        return {"detail": resp.text}


@cv_analyser_bp.route("/cv-analyser/upload", methods=["POST"])
@jwt_required()
def proxy_upload():
    signing_secret = _get_cv_analyser_signing_secret()
    if not signing_secret:
        return jsonify({"detail": "CV analyser signing secret not configured"}), 500

    if "file" not in request.files:
        return jsonify({"detail": "Missing file"}), 400

    f = request.files["file"]
    if not f or not getattr(f, "filename", None):
        return jsonify({"detail": "Missing file"}), 400

    max_upload_mb = int(os.getenv("CV_ANALYSER_MAX_UPLOAD_MB", os.getenv("MAX_UPLOAD_MB", "15")) or "15")
    max_bytes = max_upload_mb * 1024 * 1024

    allowed_mimetypes = {
        "application/pdf",
        "application/msword",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "text/plain",
        "image/png",
        "image/jpeg",
    }

    mimetype = getattr(f, "mimetype", None)
    if mimetype and mimetype not in allowed_mimetypes:
        return jsonify({"detail": f"Unsupported file type: {mimetype}"}), 400

    content_length = request.content_length
    if content_length is not None and content_length > max_bytes:
        return jsonify({"detail": f"File too large. Max is {max_upload_mb}MB"}), 413

    job_description = request.form.get("job_description")
    current_user_id = get_jwt_identity()

    base_url = _get_cv_analyser_base_url()
    upstream_url = f"{base_url}/upload"

    data = {}
    if job_description:
        data["job_description"] = job_description
    if current_user_id is not None:
        data["uploaded_by"] = str(current_user_id)

    files = {
        "file": (f.filename, f.stream, mimetype or "application/octet-stream"),
    }

    try:
        resp = _post_upstream_with_auth_fallback(
            upstream_url,
            signing_secret,
            data=data,
            files=files,
            timeout=60,
        )
    except requests.RequestException as e:
        current_app.logger.error(f"CV analyser upload proxy failed: {e}")
        return jsonify({"detail": "Failed to reach CV analyser"}), 502

    return jsonify(_json_or_text_response(resp)), resp.status_code


@cv_analyser_bp.route("/cv-analyser/analyses/<string:analysis_id>/status", methods=["GET"])
@jwt_required()
def proxy_status(analysis_id: str):
    signing_secret = _get_cv_analyser_signing_secret()
    if not signing_secret:
        return jsonify({"detail": "CV analyser signing secret not configured"}), 500

    base_url = _get_cv_analyser_base_url()
    upstream_url = f"{base_url}/analyses/{analysis_id}/status"

    try:
        resp = _get_upstream_with_auth_fallback(
            upstream_url,
            signing_secret,
            timeout=30,
        )
    except requests.RequestException as e:
        current_app.logger.error(f"CV analyser status proxy failed: {e}")
        return jsonify({"detail": "Failed to reach CV analyser"}), 502

    return jsonify(_json_or_text_response(resp)), resp.status_code


@cv_analyser_bp.route("/cv-analyser/analyses/<string:analysis_id>/result", methods=["GET"])
@jwt_required()
def proxy_result(analysis_id: str):
    signing_secret = _get_cv_analyser_signing_secret()
    if not signing_secret:
        return jsonify({"detail": "CV analyser signing secret not configured"}), 500

    base_url = _get_cv_analyser_base_url()
    upstream_url = f"{base_url}/analyses/{analysis_id}/result"

    try:
        resp = _get_upstream_with_auth_fallback(
            upstream_url,
            signing_secret,
            timeout=60,
        )
    except requests.RequestException as e:
        current_app.logger.error(f"CV analyser result proxy failed: {e}")
        return jsonify({"detail": "Failed to reach CV analyser"}), 502

    return jsonify(_json_or_text_response(resp)), resp.status_code
