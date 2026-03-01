# app/routes/ai_routes.py
from flask import Blueprint, request, jsonify
from flask_jwt_extended import get_jwt_identity
from app.utils.decorators import role_required
from app.services.ai_service import AIService
from app.services.job_service import JobService
from app.services.cv_analysis_utils import truncate_for_cv_prompt, apply_cv_score_baseline
import json
import logging
import datetime

logger = logging.getLogger(__name__)
ai_bp = Blueprint("ai_bp", __name__, url_prefix="/api/ai")


@ai_bp.route("/chat", methods=["POST"])
def chat():
    """
    Public chat endpoint (optionally require auth if desired).
    body: {"message": "hello"}
    """
    data = request.get_json(silent=True) or {}
    message = (data.get("message") or "").strip()
    if not message:
        return jsonify({"error": "Message required"}), 400

    # Lazy import to avoid cycle
    from app.services.ai_service import AIService
    ai = AIService()

    try:
        reply = ai.chat(message)

        # Optionally persist conversation if authenticated
        user_id = None
        try:
            user_id = get_jwt_identity()
        except Exception:
            user_id = None

        if user_id:
            try:
                conv = Conversation(user_id=user_id, user_message=message, assistant_message=reply)
                db.session.add(conv)
                db.session.commit()
            except Exception:
                db.session.rollback()
                logger.exception("Failed to save conversation")

        return jsonify({"reply": reply}), 200

    except Exception as e:
        logger.exception("Chat error")
        return jsonify({
            "error": "AI chat failed",
            "details": str(e)
        }), 502  # use 502 Bad Gateway for upstream AI errors


@ai_bp.route("/generate_job_details", methods=["POST"])
@role_required(["admin", "hiring_manager"])
def generate_job_details():
    """
    Generate comprehensive job details using AI.
    Body: {"job_title": "Software Engineer"} or {"jobTitle": "..."}
    """
    data = request.get_json(silent=True) or {}
    job_title = (data.get("job_title") or data.get("jobTitle") or "").strip()
    if not job_title:
        return jsonify({"error": "job_title is required"}), 400
    try:
        ai = AIService()
        result = ai.generate_job_details(job_title)
        return jsonify({
            "message": "Job details generated successfully",
            "job_details": result
        }), 200
    except RuntimeError as e:
        if "OPENROUTER_API_KEY" in str(e) or "not set" in str(e).lower():
            return jsonify({"error": "AI not configured (OPENROUTER_API_KEY not set)"}), 503
        return jsonify({"error": str(e)}), 502
    except Exception as e:
        logger.exception("Job details generation error")
        return jsonify({"error": "AI job generation failed", "details": str(e)}), 502


@ai_bp.route("/parse_cv", methods=["POST"])
@role_required(["candidate"])
def parse_cv():
    """
    Accepts:
    - JSON: { "cv_text": "...", "job_description": "..." }
    - or multipart: file field "resume" and job_description form field.
    """
    user_id = get_jwt_identity()
    user = User.query.get_or_404(user_id)
    candidate = Candidate.query.filter_by(user_id=user_id).first()
    if not candidate:
        candidate = Candidate(user_id=user_id)
        db.session.add(candidate)
        db.session.commit()

    # Accept cv_text, job_description, or job_id (to build full job spec server-side)
    cv_text = request.form.get("cv_text") or (request.json and request.json.get("cv_text"))
    job_description = request.form.get("job_description") or (request.json and request.json.get("job_description"))
    job_id_raw = request.form.get("job_id") or (request.json and request.json.get("job_id"))

    if job_id_raw is not None:
        try:
            job_id = int(job_id_raw)
        except (TypeError, ValueError):
            job_id = None
    else:
        job_id = None

    # If a file is uploaded, push to Cloudinary
    resume_url = None
    if "resume" in request.files:
        file = request.files["resume"]
        try:
            upload_result = cloudinary.uploader.upload(file, folder="Candidate_CV", resource_type="raw")
            resume_url = upload_result.get("secure_url")
            candidate.cv_url = resume_url
        except Exception:
            logger.exception("Cloudinary upload failed")

    if job_id and not job_description:
        from app.models import Requisition
        job = Requisition.query.get(job_id)
        if job:
            job_description = JobService.build_job_spec_for_cv(job)
    if not job_description:
        return jsonify({"error": "job_description or job_id is required"}), 400

    if not cv_text:
        cv_text = candidate.cv_text or ""
        if not cv_text:
            return jsonify({"error": "cv_text is required (or upload text)"}), 400

    cv_text, job_description = truncate_for_cv_prompt(cv_text, job_description)

    # Run Gemini CV analysis with safe fallback
    parser_result = analyse_resume_gemini(cv_text=cv_text, job_description=job_description)

    raw_score = parser_result.get("match_score", 0) or 0
    final_score = apply_cv_score_baseline(raw_score)
    parser_result["match_score"] = final_score
    if parser_result.get("raw_score") is None:
        parser_result["raw_score"] = raw_score

    # Save analysis record
    try:
        analysis = CVAnalysis(
            candidate_id=candidate.id,
            job_description=job_description,
            cv_text=cv_text,
            result=parser_result,
            created_at=datetime.datetime.utcnow(),
        )
        db.session.add(analysis)

        candidate.profile = candidate.profile or {}
        candidate.profile["cv_parser_result"] = parser_result
        candidate.cv_score = final_score
        db.session.commit()
    except Exception:
        db.session.rollback()
        logger.exception("Failed to save CV analysis")

    # Notify admins
    try:
        from app.models import User as UserModel, Notification
        admins = UserModel.query.filter_by(role="admin").all()
        for admin in admins:
            n = Notification(user_id=admin.id, message=f"{user.email} performed CV analysis for a job.")
            db.session.add(n)
        db.session.commit()
    except Exception:
        db.session.rollback()
        logger.exception("Failed to create admin notifications")

    return jsonify({
        "message": "Analysis completed",
        "parser_result": parser_result,
        "cv_url": resume_url,
    }), 200


@ai_bp.route("/generate_questions", methods=["POST"])
@role_required(["admin", "hiring_manager"])
def generate_questions():
    """
    Generate assessment questions for a job role.
    Body: {"job_title": "...", "difficulty": "medium", "question_count": 5}
    """
    data = request.get_json(silent=True) or {}
    job_title = (data.get("job_title") or data.get("jobTitle") or "").strip()
    difficulty = (data.get("difficulty") or "medium").strip()
    question_count = int(data.get("question_count") or data.get("questionCount") or 5)
    question_count = max(1, min(20, question_count))
    if not job_title:
        return jsonify({"error": "job_title is required"}), 400
    from app.services.ai_service import AIService
    ai = AIService()
    try:
        questions = ai.generate_assessment_questions(job_title, difficulty, question_count)
        return jsonify({"questions": questions}), 200
    except RuntimeError as e:
        logger.warning("generate_questions AI failed: %s", e)
        return jsonify({
            "error": "AI service temporarily unavailable. Try again later or check API configuration.",
        }), 503
    except Exception as e:
        logger.exception("generate_questions failed")
        return jsonify({
            "error": "AI service temporarily unavailable. Try again later.",
        }), 503


@ai_bp.route("/analysis/<int:analysis_id>", methods=["GET"])
@role_required(["candidate"])
def get_analysis(analysis_id):
    try:
        user_id = get_jwt_identity()
        analysis = CVAnalysis.query.get_or_404(analysis_id)
        candidate = Candidate.query.filter_by(user_id=user_id).first_or_404()

        if analysis.candidate_id != candidate.id:
            return jsonify({"error": "Unauthorized"}), 403

        return jsonify({"analysis": analysis.to_dict()}), 200
    except Exception:
        logger.exception("Failed to fetch analysis")
        return jsonify({"error": "Internal server error"}), 500
