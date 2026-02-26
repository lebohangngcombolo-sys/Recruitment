"""
Test pack (assessment pack) CRUD and listing for recruiters.
"""
from flask import Blueprint, request, jsonify, current_app
from flask_jwt_extended import jwt_required
from datetime import datetime

from app.extensions import db
from app.models import TestPack
from app.utils.decorators import role_required

test_pack_bp = Blueprint("test_packs", __name__)


@test_pack_bp.route("/test-packs", methods=["GET"])
@jwt_required()
@role_required(["admin", "hiring_manager", "hr"])
def list_test_packs():
    """List all active (non-deleted) test packs. Optional filter: ?category=technical|role-specific"""
    category = request.args.get("category")
    query = TestPack.query.filter(TestPack.deleted_at.is_(None))
    if category and category in ("technical", "role-specific"):
        query = query.filter(TestPack.category == category)
    packs = query.order_by(TestPack.name).all()
    return jsonify({"test_packs": [p.to_dict() for p in packs]}), 200


@test_pack_bp.route("/test-packs/<int:test_pack_id>", methods=["GET"])
@jwt_required()
@role_required(["admin", "hiring_manager", "hr"])
def get_test_pack(test_pack_id):
    """Get a single test pack by id. Returns 404 if not found or soft-deleted."""
    pack = TestPack.query.filter(
        TestPack.id == test_pack_id,
        TestPack.deleted_at.is_(None)
    ).first()
    if not pack:
        return jsonify({"error": "Test pack not found"}), 404
    return jsonify(pack.to_dict()), 200


@test_pack_bp.route("/test-packs", methods=["POST"])
@jwt_required()
@role_required(["admin", "hiring_manager", "hr"])
def create_test_pack():
    """Create a new test pack. Body: name, category (technical|role-specific), description?, questions (list)."""
    data = request.get_json()
    if not data:
        return jsonify({"error": "Request body must be JSON"}), 400
    name = (data.get("name") or "").strip()
    if not name:
        return jsonify({"error": "name is required"}), 400
    category = (data.get("category") or "").strip().lower()
    if category not in ("technical", "role-specific"):
        return jsonify({"error": "category must be 'technical' or 'role-specific'"}), 400
    description = (data.get("description") or "").strip()
    questions = data.get("questions")
    if not isinstance(questions, list):
        questions = []
    pack = TestPack(
        name=name,
        category=category,
        description=description,
        questions=questions,
    )
    db.session.add(pack)
    try:
        db.session.commit()
        return jsonify(pack.to_dict()), 201
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Create test pack error: {e}", exc_info=True)
        return jsonify({"error": "Failed to create test pack"}), 500


@test_pack_bp.route("/test-packs/<int:test_pack_id>", methods=["PUT"])
@jwt_required()
@role_required(["admin", "hiring_manager", "hr"])
def update_test_pack(test_pack_id):
    """Update a test pack. Body: name?, category?, description?, questions? (partial update)."""
    pack = TestPack.query.filter(
        TestPack.id == test_pack_id,
        TestPack.deleted_at.is_(None)
    ).first()
    if not pack:
        return jsonify({"error": "Test pack not found"}), 404
    data = request.get_json()
    if not data:
        return jsonify({"error": "Request body must be JSON"}), 400
    if "name" in data and data["name"] is not None:
        name = (data["name"] or "").strip()
        if name:
            pack.name = name
    if "category" in data and data["category"] is not None:
        cat = (str(data["category"]).strip().lower())
        if cat in ("technical", "role-specific"):
            pack.category = cat
    if "description" in data:
        pack.description = (data["description"] or "").strip()
    if "questions" in data and isinstance(data["questions"], list):
        pack.questions = data["questions"]
    pack.updated_at = datetime.utcnow()
    try:
        db.session.commit()
        return jsonify(pack.to_dict()), 200
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Update test pack error: {e}", exc_info=True)
        return jsonify({"error": "Failed to update test pack"}), 500


@test_pack_bp.route("/test-packs/<int:test_pack_id>", methods=["DELETE"])
@jwt_required()
@role_required(["admin", "hiring_manager", "hr"])
def delete_test_pack(test_pack_id):
    """Soft-delete a test pack. Requisitions linked to it will keep test_pack_id; resolver ignores deleted packs."""
    pack = TestPack.query.get(test_pack_id)
    if not pack:
        return jsonify({"error": "Test pack not found"}), 404
    if pack.deleted_at:
        return jsonify({"message": "Test pack already deleted"}), 200
    pack.deleted_at = datetime.utcnow()
    pack.updated_at = datetime.utcnow()
    try:
        db.session.commit()
        return jsonify({"message": "Test pack deleted"}), 200
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Delete test pack error: {e}", exc_info=True)
        return jsonify({"error": "Failed to delete test pack"}), 500
