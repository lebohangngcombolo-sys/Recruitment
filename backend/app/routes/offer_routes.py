
from flask import Blueprint, request, jsonify
from flask_jwt_extended import get_jwt, get_jwt_identity
from datetime import datetime

from app.extensions import db
from app.models import Offer, OfferStatus, Application, Candidate
from app.services.email_service import EmailService
from app.services.audit_service import AuditService, audit_action
from app.services.pdf_service import PDFService
from app.utils.decorators import role_required

import cloudinary.uploader

offer_bp = Blueprint("offer", __name__)

# ---------------- VALID STATUS TRANSITIONS ----------------
VALID_TRANSITIONS = {
    OfferStatus.DRAFT: {OfferStatus.REVIEWED},
    OfferStatus.REVIEWED: {OfferStatus.APPROVED, OfferStatus.REJECTED},
    OfferStatus.APPROVED: {OfferStatus.SENT, OfferStatus.WITHDRAWN},
    OfferStatus.SENT: {OfferStatus.SIGNED, OfferStatus.EXPIRED},
}

def ensure_transition(current, target):
    if target not in VALID_TRANSITIONS.get(current, set()):
        raise ValueError(f"Invalid transition: {current.value} → {target.value}")

# ---------------- CREATE / UPDATE OFFERS ----------------
@offer_bp.route("/", methods=["POST"])
@role_required("admin")
@audit_action("Drafted offer")
def draft_offer():
    data = request.json
    application = Application.query.get_or_404(data["application_id"])

    offer = Offer(
        application_id=application.id,
        drafted_by=get_jwt_identity(),
        base_salary=data.get("base_salary"),
        allowances=data.get("allowances", {}),
        bonuses=data.get("bonuses", {}),
        contract_type=data.get("contract_type"),
        start_date=data.get("start_date"),
        work_location=data.get("work_location"),
        notes=data.get("notes"),
    )

    db.session.add(offer)
    db.session.commit()
    return jsonify(offer.to_dict()), 201

@offer_bp.route("/<int:offer_id>/review", methods=["POST"])
@role_required("hiring_manager")
@audit_action("Reviewed offer")
def review_offer(offer_id):
    offer = Offer.query.get_or_404(offer_id)
    ensure_transition(offer.status, OfferStatus.REVIEWED)

    offer.status = OfferStatus.REVIEWED
    offer.hiring_manager_id = get_jwt_identity()
    offer.notes = request.json.get("review_comments")

    db.session.commit()
    return jsonify(offer.to_dict()), 200

@offer_bp.route("/<int:offer_id>/approve", methods=["POST"])
@role_required("hr")
@audit_action("Approved and sent offer")
def approve_offer(offer_id):
    offer = Offer.query.get_or_404(offer_id)
    ensure_transition(offer.status, OfferStatus.APPROVED)

    offer.status = OfferStatus.APPROVED
    offer.approved_by = get_jwt_identity()

    # Generate PDF + upload (single responsibility)
    pdf_url = PDFService.generate_offer_pdf(offer)

    offer.pdf_url = pdf_url
    offer.pdf_generated_at = datetime.utcnow()
    offer.status = OfferStatus.SENT

    EmailService.send_async_email(
        subject="Your Job Offer",
        recipients=[offer.application.candidate.user.email],
        html_body=f"<a href='{pdf_url}'>Download Offer</a>",
        text_body=f"Download your offer: {pdf_url}",
    )

    db.session.commit()
    return jsonify(offer.to_dict()), 200


@offer_bp.route("/<int:offer_id>/sign", methods=["POST"])
@role_required("candidate")
@audit_action("Signed offer")
def sign_offer(offer_id):
    offer = Offer.query.get_or_404(offer_id)
    current_user_id = get_jwt_identity()

    # Fetch candidate record for logged-in user
    candidate = Candidate.query.filter_by(user_id=current_user_id).first()
    if not candidate or offer.application.candidate_id != candidate.id:
        return jsonify({"error": "Unauthorized"}), 403

    # Ensure status transition is valid
    ensure_transition(offer.status, OfferStatus.SIGNED)

    # Update offer
    offer.status = OfferStatus.SIGNED
    offer.signed_by = current_user_id
    offer.signed_at = datetime.utcnow()
    offer.candidate_ip = request.remote_addr
    offer.candidate_user_agent = request.headers.get("User-Agent")

    db.session.commit()
    return jsonify(offer.to_dict()), 200


@offer_bp.route("/<int:offer_id>/reject", methods=["POST"])
@role_required(["hiring_manager", "hr"])
@audit_action("Rejected offer")
def reject_offer(offer_id):
    offer = Offer.query.get_or_404(offer_id)
    ensure_transition(offer.status, OfferStatus.REJECTED)

    offer.status = OfferStatus.REJECTED
    offer.notes = request.json.get("reason")

    db.session.commit()
    return jsonify(offer.to_dict()), 200

@offer_bp.route("/<int:offer_id>/expire", methods=["POST"])
@role_required("hr")
@audit_action("Expired offer")
def expire_offer(offer_id):
    offer = Offer.query.get_or_404(offer_id)
    ensure_transition(offer.status, OfferStatus.EXPIRED)

    offer.status = OfferStatus.EXPIRED
    db.session.commit()
    return jsonify(offer.to_dict()), 200

# ---------------- GET OFFERS ----------------
@offer_bp.route("/", methods=["GET"])
@role_required(["admin", "hr", "hiring_manager"])
def get_offers():
    status = request.args.get("status", "").lower()  # normalize to lowercase
    query = Offer.query

    # Filter by status if provided
    if status:
        try:
            query = query.filter_by(status=OfferStatus(status))
        except ValueError:
            return jsonify({"error": f"Invalid status: {status}"}), 400

    # Role-based filtering
    current_user_role = get_jwt_identity()
    if isinstance(current_user_role, str):
        # Only the role string is returned from get_jwt_identity
        role = current_user_role
    else:
        role = current_user_role.get("role", "")

    if role == "hiring_manager":
        query = query.filter_by(status=OfferStatus.DRAFT)
    elif role == "hr":
        query = query.filter_by(status=OfferStatus.REVIEWED)

    offers = query.all()
    return jsonify([offer.to_dict() for offer in offers]), 200


@offer_bp.route("/<int:offer_id>", methods=["GET"])
@role_required(["admin", "hr", "hiring_manager", "candidate"])
def get_offer(offer_id):
    offer = Offer.query.get_or_404(offer_id)

    claims = get_jwt()
    current_user_role = claims.get("role")
    current_user_id = get_jwt_identity()

    if current_user_role == "candidate":
        if offer.application.candidate.user_id != current_user_id:
            return jsonify({"error": "Unauthorized"}), 403

    return jsonify(offer.to_dict()), 200

# ---------------- CANDIDATE OFFERS ----------------
@offer_bp.route("/candidate/<int:candidate_id>", methods=["GET"])
@role_required(["candidate", "admin", "hr"])
def get_candidate_offers(candidate_id):
    claims = get_jwt()
    current_user_role = claims.get("role")
    current_user_id = get_jwt_identity()

    if current_user_role == "candidate" and current_user_id != candidate_id:
        return jsonify({"error": "Unauthorized"}), 403

    offers = Offer.query.join(Application).filter(
        Application.candidate_id == candidate_id
    ).all()
    return jsonify([offer.to_dict() for offer in offers]), 200

# ---------------- APPLICATION OFFERS ----------------
@offer_bp.route("/application/<int:application_id>", methods=["GET"])
@role_required(["admin", "hr", "hiring_manager"])
def get_application_offers(application_id):
    offers = Offer.query.filter_by(application_id=application_id).all()
    return jsonify([offer.to_dict() for offer in offers]), 200

# ---------------- ANALYTICS ----------------
@offer_bp.route("/analytics", methods=["GET"])
@role_required(["admin", "hr", "hiring_manager"])
def get_offer_analytics():
    from sqlalchemy import func

    counts = db.session.query(
        Offer.status,
        func.count(Offer.id)
    ).group_by(Offer.status).all()

    result = {status.value: count for status, count in counts}
    return jsonify(result), 200

# ---------------- CURRENT CANDIDATE OFFERS ----------------
@offer_bp.route("/my-offers", methods=["GET"])
@role_required("candidate")
def get_my_offers():
    """
    Fetch all offers for the currently authenticated candidate.
    Only accessible by candidates.
    """
    current_user_id = get_jwt_identity()

    # Get offers via candidate -> applications -> offers
    offers = Offer.query.join(Application).join(Application.candidate).filter(
        Candidate.user_id == current_user_id
    ).all()

    return jsonify([offer.to_dict() for offer in offers]), 200