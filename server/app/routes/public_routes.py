"""Public API routes (no authentication required)."""
from flask import Blueprint, jsonify, current_app
from app.models import Requisition
from app.routes.candidate_routes import _job_list_item

public_bp = Blueprint("public_bp", __name__)


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
