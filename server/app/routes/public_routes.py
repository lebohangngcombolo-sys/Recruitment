"""Public API routes (no authentication required)."""
from flask import Blueprint, jsonify, current_app
from sqlalchemy import text
from app import db
from app.models import Requisition
from app.routes.candidate_routes import _job_list_item

public_bp = Blueprint("public_bp", __name__)


@public_bp.route("/healthz", methods=["GET"])
def healthz():
    """Lightweight health and version info.

    - status: basic process liveness.
    - git_sha: short git revision from the container (render_start.sh exports GIT_SHA).
    - alembic_revision: current DB migration revision, if available.
    """
    git_sha = current_app.config.get("GIT_SHA") or current_app.config.get("GIT_COMMIT")  # optional extra sources
    if not git_sha:
        # Fall back to environment variable exported in render_start.sh
        import os

        git_sha = os.environ.get("GIT_SHA", "unknown")

    alembic_revision = None
    try:
        # Alembic stores the current revision in alembic_version.version_num (single-row table).
        result = db.session.execute(text("SELECT version_num FROM alembic_version LIMIT 1"))
        row = result.first()
        alembic_revision = row[0] if row else None
    except Exception as e:
        current_app.logger.warning(f"healthz: could not read alembic_version: {e}")

    payload = {
        "status": "ok",
        "git_sha": git_sha,
        "alembic_revision": alembic_revision,
    }
    return jsonify(payload), 200


@public_bp.route("/jobs", methods=["GET"])
def get_public_jobs():
    """Return active job listings for explore category (no auth required)."""
    try:
        jobs = Requisition.query.filter(
            Requisition.is_active == True,
            Requisition.deleted_at == None
        ).order_by(Requisition.published_on.desc()).all()

        result = [_job_list_item(job) for job in jobs]
        return jsonify(result), 200
    except Exception as e:
        current_app.logger.error(f"Get public jobs error: {e}", exc_info=True)
        return jsonify({"error": "Internal server error"}), 500
