from flask import Blueprint, request, jsonify
from flask_jwt_extended import get_jwt_identity
from datetime import datetime

from app.extensions import db
from app.models import Offer, OfferStatus, Application
from app.services.email_service import EmailService
from app.services.audit_service import AuditService, audit_action
from app.services.pdf_service import PDFService
from app.utils.decorators import role_required

import cloudinary.uploader
import logging
import os

offer_bp = Blueprint("offer", __name__)


VALID_TRANSITIONS = {
    OfferStatus.DRAFT: {OfferStatus.REVIEWED},
    OfferStatus.REVIEWED: {OfferStatus.APPROVED, OfferStatus.REJECTED},
    OfferStatus.APPROVED: {OfferStatus.SENT, OfferStatus.WITHDRAWN},
    OfferStatus.SENT: {OfferStatus.SIGNED, OfferStatus.EXPIRED},
}


def ensure_transition(current, target):
    if target not in VALID_TRANSITIONS.get(current, set()):
        raise ValueError(f"Invalid transition: {current.value} → {target.value}")

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

    # Generate PDF
    pdf_path = f"/tmp/offer_{offer.id}.pdf"
    PDFService.generate_offer_pdf(offer, pdf_path)

    upload = cloudinary.uploader.upload(
        pdf_path,
        resource_type="auto",
        folder="offers",
        public_id=f"offer_{offer.id}_v{offer.offer_version}",
        overwrite=True
    )

    offer.pdf_url = upload["secure_url"]
    offer.pdf_public_id = upload["public_id"]
    offer.pdf_generated_at = datetime.utcnow()
    offer.status = OfferStatus.SENT

    EmailService.send_async_email(
        subject="Your Job Offer",
        recipients=[offer.application.candidate.user.email],
        html_body=f"<a href='{offer.pdf_url}'>Download Offer</a>",
        text_body=f"Download your offer: {offer.pdf_url}",
    )

    db.session.commit()
    return jsonify(offer.to_dict()), 200

@offer_bp.route("/<int:offer_id>/sign", methods=["POST"])
@role_required("candidate")
@audit_action("Signed offer")
def sign_offer(offer_id):
    offer = Offer.query.get_or_404(offer_id)
    candidate_user_id = get_jwt_identity()

    # Ownership check (CRITICAL FIX)
    if offer.application.candidate.user_id != candidate_user_id:
        return jsonify({"error": "Unauthorized"}), 403

    ensure_transition(offer.status, OfferStatus.SIGNED)

    offer.status = OfferStatus.SIGNED
    offer.signed_by = candidate_user_id
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
