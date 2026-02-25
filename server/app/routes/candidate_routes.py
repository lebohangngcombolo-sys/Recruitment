from flask import Blueprint, request, jsonify, current_app, Response
from flask_jwt_extended import get_jwt_identity, jwt_required
from app.extensions import db, cloudinary_client
import requests
from werkzeug.security import check_password_hash, generate_password_hash
from app.extensions import bcrypt
import cloudinary.uploader
import cloudinary.utils
from app.models import (
    User, Candidate, Requisition, Application, AssessmentResult, Notification, AuditLog, CVAnalysis
)
from datetime import datetime
from werkzeug.utils import secure_filename

# uses online analyzer via background task; do not instantiate heavy models here
# NOTE: import analyze_cv_task lazily inside upload_resume to avoid circular import
from app.services.cv_parser_service import HybridResumeAnalyzer
from app.services.job_service import JobService
from app.utils.decorators import role_required
from app.utils.helper import get_current_candidate
from app.services.audit2 import AuditService
import fitz
from flask import jsonify, request, current_app
import json
import re



candidate_bp = Blueprint("candidate_bp", __name__)

# ----------------- APPLY FOR JOB -----------------
@candidate_bp.route("/apply/<int:job_id>", methods=["POST"])
@role_required(["candidate"])
def apply_job(job_id):
    try:
        user_id = get_jwt_identity()
        user = User.query.get_or_404(user_id)
        data = request.get_json() or {}

        job = Requisition.query.get(job_id)
        if not job:
            return jsonify({"error": "Job not found"}), 404
        if not job.is_active or job.deleted_at is not None:
            return jsonify({"error": "Job is not accepting applications"}), 400

        # Fetch or create Candidate profile
        candidate = Candidate.query.filter_by(user_id=user.id).first()
        if not candidate:
            candidate = Candidate(user_id=user.id)
            db.session.add(candidate)
            db.session.commit()

        # Update candidate info
        if candidate.profile is None:
            candidate.profile = {}
        candidate.full_name = data.get("full_name", candidate.full_name)
        candidate.phone = data.get("phone", candidate.phone)
        if "portfolio" in data:
            candidate.portfolio = data.get("portfolio")
            candidate.profile["portfolio"] = candidate.portfolio
        if "cover_letter" in data:
            candidate.cover_letter = data.get("cover_letter")
            candidate.profile["cover_letter"] = candidate.cover_letter
        db.session.commit()

        # Check if candidate already has an application for this job
        existing_app = Application.query.filter_by(
            candidate_id=candidate.id,
            requisition_id=job_id
        ).first()
        if existing_app:
            # Allow resuming: if application is still in progress (or form submitted, not yet assessment), update details and return it
            if existing_app.status in ("in_progress", "draft", "applied"):
                db.session.commit()  # persist candidate info updates above
                return jsonify({
                    "message": "Application updated.",
                    "application_id": existing_app.id
                }), 200
            # Already fully applied
            return jsonify({"error": "You have already applied for this job"}), 400

        # Create new application (in_progress until assessment + required steps are complete)
        application = Application(
            candidate_id=candidate.id,
            requisition_id=job_id,
            status="in_progress",
            created_at=datetime.utcnow()
        )
        db.session.add(application)
        db.session.commit()
        
        # Audit log
        AuditService.record_action(
            admin_id=user_id,
            action="Candidate Applied for Job",
            target_user_id=user_id,
            actor_label="candidate_id",
            details=f"Applied for job ID {job_id}",
            extra_data={"job_id": job_id, "application_id": application.id}
        )

        return jsonify({"message": "Applied successfully!", "application_id": application.id}), 201

    except Exception as e:
        current_app.logger.error(f"Apply job error: {e}", exc_info=True)
        return jsonify({"error": "Internal server error"}), 500


def _job_list_item(job):
    """Build a single job item for Flutter explore listing (shared by candidate and public APIs)."""
    deadline_str = ""
    if getattr(job, "application_deadline", None) and job.application_deadline:
        deadline_str = job.application_deadline.strftime("%d %b %Y")
    return {
        "id": job.id,
        "title": job.title or "",
        "company": getattr(job, "company", None) or "",
        "location": getattr(job, "location", None) or "Remote",
        "type": getattr(job, "employment_type", None) or "Full Time",
        "salary": getattr(job, "salary_range", None) or "",
        "deadline": deadline_str,
        "company_logo": getattr(job, "banner", None),
        "role": job.category or "",
        "description": job.description or "",
        "responsibilities": job.responsibilities or [],
        "qualifications": job.qualifications or [],
        "required_skills": job.required_skills or [],
        "min_experience": job.min_experience or 0,
        "company_details": job.company_details or "",
        "published_on": job.published_on.strftime("%d %b, %Y") if job.published_on else "",
        "vacancy": job.vacancy or 1,
        "created_by": job.created_by,
    }


# ----------------- GET AVAILABLE JOBS -----------------
@candidate_bp.route("/jobs", methods=["GET"])
@role_required(["candidate"])
def get_available_jobs():
    try:
        user_id = get_jwt_identity()

        jobs = Requisition.query.filter_by(is_active=True)\
                                .filter(Requisition.deleted_at.is_(None))\
                                .order_by(Requisition.created_at.desc())\
                                .all()
        result = []

        for job in jobs:
            result.append({
                "id": job.id,
                "title": job.title or "",
                "description": job.description or "",
                "company": job.company or "",
                "location": job.location or "",
                "salary_min": job.salary_min,
                "salary_max": job.salary_max,
                "salary_currency": job.salary_currency or "ZAR",
                "salary_period": job.salary_period or "monthly",
                "employment_type": job.employment_type or "full_time",
                "responsibilities": job.responsibilities or [],
                "qualifications": job.qualifications or [],
                "required_skills": job.required_skills or [],
                "min_experience": job.min_experience or 0,
                "knockout_rules": job.knockout_rules or [],
                "weightings": job.weightings or {
                    "cv": 60,
                    "assessment": 40,
                    "interview": 0,
                    "references": 0
                },
                "assessment_pack": job.assessment_pack or {"questions": []},
                "company_details": job.company_details or "",
                "category": job.category or "",
                "published_on": job.published_on.strftime("%d %b, %Y") if job.published_on else "",
                "vacancy": str(job.vacancy or 0),
                "created_by": job.created_by
            })

        AuditService.record_action(
            admin_id=user_id,
            action="Candidate Viewed Available Jobs",
            target_user_id=user_id,
            actor_label="candidate_id",
            details="Retrieved list of available jobs"
        )

        return jsonify(result), 200

    except Exception as e:
        current_app.logger.error(f"Get available jobs error: {e}", exc_info=True)
        return jsonify({"error": "Internal server error"}), 500


# ----------------- UPLOAD RESUME -----------------
# ----------------- UPLOAD RESUME -----------------
@candidate_bp.route("/upload_resume/<int:application_id>", methods=["POST"])
@role_required(["candidate"])
def upload_resume(application_id):
    try:
        application = Application.query.get_or_404(application_id)
        candidate = application.candidate
        job = application.requisition

        if not job or not job.is_active or job.deleted_at is not None:
            return jsonify({"error": "Job is not accepting applications"}), 400

        if application.candidate.user.id != int(get_jwt_identity()):
            return jsonify({"error": "Unauthorized"}), 403

        if getattr(application, "resume_url", None):
            return jsonify({"error": "Resume already uploaded"}), 400

        if "resume" not in request.files:
            return jsonify({"error": "No resume uploaded"}), 400

        file = request.files["resume"]

        import os
        import tempfile
        from app.services.advanced_ocr_service import AdvancedOCRService

        filename = (file.filename or "").strip()
        if not filename:
            return jsonify({"error": "No file selected"}), 400

        _, ext = os.path.splitext(filename)
        ext = (ext or "").lower().lstrip(".")

        ocr_service = AdvancedOCRService()
        if ext and ext not in ocr_service.SUPPORTED_EXTENSIONS:
            return jsonify({
                "error": f"Unsupported file type: .{ext}",
                "supported_types": sorted(list(ocr_service.SUPPORTED_EXTENSIONS)),
            }), 400

        # Save to temp file for OCR / text extraction
        with tempfile.NamedTemporaryFile(delete=False, suffix=f".{ext}" if ext else "") as tmp:
            temp_path = tmp.name
        try:
            file.save(temp_path)
            ocr_result = ocr_service.extract_text_with_metadata(temp_path, ext or "")
            resume_text = (ocr_result.get("text") or "").strip()
        finally:
            try:
                os.remove(temp_path)
            except Exception:
                pass

        # Reset stream so Cloudinary upload can read the file content
        try:
            file.stream.seek(0)
        except Exception:
            pass

        # --- Upload to Cloudinary (with original filename so it appears correctly in Candidate_CV) ---
        from app.services.cv_parser_service import HybridResumeAnalyzer
        resume_url = HybridResumeAnalyzer.upload_cv(file, filename=filename)
        if not resume_url:
            return jsonify({"error": "Failed to upload resume"}), 500

        # If client provided resume_text explicitly, prefer that.
        client_resume_text = (request.form.get("resume_text", "") or "").strip()
        if client_resume_text:
            resume_text = client_resume_text

        # --- Queue analysis (non-blocking) ---
        application.resume_url = resume_url
        # Keep candidate-level CV in sync so candidates.cv_url is set (for admin/DB views)
        candidate.cv_url = resume_url
        if resume_text:
            candidate.cv_text = resume_text
        db.session.add(application)
        db.session.add(candidate)
        db.session.commit()

        cv_analysis = CVAnalysis(
            candidate_id=candidate.id,
            job_description=job.description or "",
            cv_text=resume_text or "",
            result={
                "extraction_metadata": {
                    "extraction_method": ocr_result.get("extraction_method"),
                    "confidence": ocr_result.get("confidence"),
                    "pages": ocr_result.get("pages"),
                    "has_scanned_content": ocr_result.get("has_scanned_content"),
                }
            },
            status="pending"
        )
        db.session.add(cv_analysis)
        db.session.commit()

        try:
            # import task lazily to avoid circular import during app initialization
            from app.tasks.cv_tasks import analyze_cv_task
            analyze_cv_task.delay(cv_analysis.id, application.id)
        except Exception:
            current_app.logger.exception("Failed to enqueue CV analysis task")

        return jsonify({
            "message": "Resume uploaded; analysis queued",
            "analysis_id": cv_analysis.id,
            "resume_url": resume_url,
            "status": "queued"
        }), 202

    except Exception as e:
        current_app.logger.error(f"Upload resume error: {e}", exc_info=True)
        return jsonify({"error": "Internal server error"}), 500


# ----------------- CV ANALYSIS STATUS -----------------
@candidate_bp.route("/cv-analyses/<int:analysis_id>", methods=["GET"])
@role_required(["candidate"])
def get_cv_analysis_status(analysis_id):
    try:
        user_id = get_jwt_identity()
        candidate = Candidate.query.filter_by(user_id=user_id).first()
        if not candidate:
            return jsonify({"error": "Candidate not found"}), 404

        analysis = CVAnalysis.query.get_or_404(analysis_id)
        if analysis.candidate_id != candidate.id:
            return jsonify({"error": "Unauthorized"}), 403

        return jsonify({
            "analysis_id": analysis.id,
            "candidate_id": analysis.candidate_id,
            "status": analysis.status,
            "result": analysis.result,
            "started_at": analysis.started_at.isoformat() if analysis.started_at else None,
            "finished_at": analysis.finished_at.isoformat() if analysis.finished_at else None,
            "created_at": analysis.created_at.isoformat() if analysis.created_at else None,
        }), 200
    except Exception as e:
        current_app.logger.error(f"Get CV analysis status error: {e}", exc_info=True)
        return jsonify({"error": "Internal server error"}), 500


# ----------------- CANDIDATE APPLICATIONS -----------------
@candidate_bp.route("/applications", methods=["GET"])
@role_required(["candidate"])
def get_applications():
    try:
        user_id = get_jwt_identity()
        candidate = Candidate.query.filter_by(user_id=user_id).first()
        if not candidate:
            return jsonify([])

        applications = Application.query.filter_by(candidate_id=candidate.id).all()
        result = []
        for app in applications:
            assessment_result = AssessmentResult.query.filter_by(application_id=app.id).first()
            job = app.requisition
            result.append({
                "application_id": app.id,
                "job_id": app.requisition_id,
                "job_title": job.title if job else None,
                "company": job.company if job else None,
                "location": job.location if job else None,
                "status": app.status,
                "last_saved_screen": getattr(app, "last_saved_screen", None),
                "saved_at": app.saved_at.isoformat() if getattr(app, "saved_at", None) else None,
                "draft_data": app.draft_data,
                "resume_url": app.resume_url,
                "cv_score": app.cv_score,
                "cv_parser_result": app.cv_parser_result,
                "assessment_score": app.assessment_score,
                "overall_score": app.overall_score,
                "scoring_breakdown": app.scoring_breakdown,
                "knockout_rule_violations": app.knockout_rule_violations,
                "recommendation": app.recommendation,
                "assessed_date": app.assessed_date.isoformat() if app.assessed_date else None,
                "created_at": app.created_at.isoformat() if app.created_at else None,
                "interview_status": app.interview_status,
                "interview_feedback_score": app.interview_feedback_score,
                "assessment_result": assessment_result.to_dict() if assessment_result else None,
            })
            
        # Audit log
        AuditService.record_action(
            admin_id=user_id,
            action="Candidate Viewed Applications",
            target_user_id=user_id,
            actor_label="candidate_id",
            details="Retrieved list of candidate applications"
        )
        return jsonify(result)
    except Exception as e:
        current_app.logger.error(f"Get applications error: {e}", exc_info=True)
        return jsonify({"error": "Internal server error"}), 500


def _cloudinary_public_id_from_url(url):
    """Extract public_id from a Cloudinary raw URL (e.g. .../raw/upload/v123/folder/file.pdf)."""
    if not url or "/upload/" not in url:
        return None
    after_upload = url.split("/upload/")[-1]
    parts = after_upload.split("/", 1)
    if len(parts) < 2:
        return None
    return parts[1]  # e.g. "Candidate_CV/BongiweM_-_CV.pdf"


# ----------------- CV PREVIEW (proxy so app can embed PDF without 401 / new tab) -----------------
@candidate_bp.route("/applications/<int:application_id>/cv-preview", methods=["GET"])
@role_required(["candidate"])
def cv_preview(application_id):
    """Stream the application's CV PDF so the app can display it inline (avoids Cloudinary 401 in browser)."""
    try:
        application = Application.query.get_or_404(application_id)
        candidate = Candidate.query.filter_by(user_id=get_jwt_identity()).first_or_404()
        if application.candidate_id != candidate.id:
            return jsonify({"error": "Unauthorized"}), 403
        resume_url = getattr(application, "resume_url", None)
        if not resume_url or not resume_url.strip():
            return jsonify({"error": "No CV uploaded for this application"}), 404

        fetch_url = resume_url
        public_id = _cloudinary_public_id_from_url(resume_url)
        if public_id:
            try:
                signed_url, _ = cloudinary.utils.cloudinary_url(
                    public_id, resource_type="raw", sign_url=True
                )
                fetch_url = signed_url
            except Exception as e:
                current_app.logger.warning(f"CV preview: could not build signed URL: {e}")

        r = requests.get(
            fetch_url,
            timeout=15,
            stream=True,
            headers={
                "User-Agent": "Mozilla/5.0 (compatible; KhonoRecruit/1.0)",
                "Accept": "application/pdf,*/*",
            },
        )
        r.raise_for_status()
        headers = {
            "Content-Type": r.headers.get("Content-Type") or "application/pdf",
            "Content-Disposition": "inline; filename=\"cv.pdf\"",
            "Access-Control-Allow-Origin": "*",
        }
        return Response(r.iter_content(chunk_size=8192), status=r.status_code, headers=headers)
    except requests.RequestException as e:
        current_app.logger.warning(f"CV preview fetch failed: {e}")
        return jsonify({"error": "Could not load CV"}), 502
    except Exception as e:
        current_app.logger.error(f"CV preview error: {e}", exc_info=True)
        return jsonify({"error": "Internal server error"}), 500


# ----------------- GET ASSESSMENT -----------------
@candidate_bp.route("/applications/<int:application_id>/assessment", methods=["GET"])
@role_required(["candidate"])
def get_assessment(application_id):
    try:
        application = Application.query.get_or_404(application_id)
        candidate = Candidate.query.filter_by(user_id=get_jwt_identity()).first_or_404()
        if application.candidate_id != candidate.id:
            return jsonify({"error": "Unauthorized"}), 403

        job = application.requisition
        if not job or not job.is_active or job.deleted_at is not None:
            return jsonify({"error": "Job is not accepting applications"}), 400

        result = AssessmentResult.query.filter_by(application_id=application.id).first()
        return jsonify({
            "job_title": application.requisition.title if application.requisition else None,
            "assessment_pack": application.requisition.assessment_pack if application.requisition else {},
            "submitted_result": result.to_dict() if result else None
        })
    except Exception as e:
        current_app.logger.error(f"Get assessment error: {e}", exc_info=True)
        return jsonify({"error": "Internal server error"}), 500


# ----------------- SUBMIT ASSESSMENT -----------------
@candidate_bp.route("/applications/<int:application_id>/assessment", methods=["POST"])
@role_required(["candidate"])
def submit_assessment(application_id):
    try:
        application = Application.query.get_or_404(application_id)
        candidate = Candidate.query.filter_by(user_id=get_jwt_identity()).first_or_404()
        if application.candidate_id != candidate.id:
            return jsonify({"error": "Unauthorized"}), 403

        job = application.requisition
        if not job or not job.is_active or job.deleted_at is not None:
            return jsonify({"error": "Job is not accepting applications"}), 400

        existing_result = AssessmentResult.query.filter_by(application_id=application.id).first()
        if existing_result:
            return jsonify({"error": "Assessment already submitted"}), 400

        data = request.get_json()
        answers = data.get("answers", {})

        questions = application.requisition.assessment_pack.get("questions", []) if application.requisition else []
        scores = {}
        total_score = 0

        for idx, q in enumerate(questions):
            qid = str(idx)
            correct_index = q.get("correct_answer", 0)
            correct_letter = ["A","B","C","D"][correct_index]
            candidate_answer = answers.get(qid)
            scores[qid] = q.get("weight", 1) if candidate_answer == correct_letter else 0
            total_score += scores[qid]

        max_score = sum(q.get("weight", 1) for q in questions)
        percentage_score = (total_score / max_score * 100) if max_score else 0

        result = AssessmentResult(
            application_id=application.id,
            candidate_id=candidate.id,
            answers=answers,
            scores=scores,
            total_score=total_score,
            percentage_score=percentage_score,
            recommendation="pass" if percentage_score >= 60 else "fail"
        )
        db.session.add(result)

        # Update application with assessment score
        application.assessment_score = percentage_score

        weightings = (job.weightings if job else None) or {
            "cv": 60,
            "assessment": 40,
            "interview": 0,
            "references": 0
        }

        cv_score = application.cv_score or 0
        interview_score = application.interview_feedback_score or 0
        references_score = 0

        overall_score = (
            (cv_score * weightings.get("cv", 0) / 100) +
            (percentage_score * weightings.get("assessment", 0) / 100) +
            (interview_score * weightings.get("interview", 0) / 100) +
            (references_score * weightings.get("references", 0) / 100)
        )

        application.overall_score = overall_score
        application.scoring_breakdown = {
            "cv": cv_score,
            "assessment": percentage_score,
            "interview": interview_score,
            "references": references_score,
            "weightings": weightings,
            "overall": overall_score
        }

        violations = []
        if job:
            violations = JobService.evaluate_knockout_rules(job, candidate)

        application.knockout_rule_violations = violations
        application.status = "disqualified" if violations else "assessment_submitted"
        application.assessed_date = datetime.utcnow()
        db.session.commit()

        return jsonify({
            "message": "Assessment submitted",
            "assessment_score": percentage_score,
            "overall_score": application.overall_score,
            "recommendation": result.recommendation,
            "knockout_rule_violations": violations
        }), 201

    except Exception as e:
        current_app.logger.error(f"Submit assessment error: {e}", exc_info=True)
        return jsonify({"error": "Internal server error"}), 500

@candidate_bp.route("/profile", methods=["GET"])
@role_required(["candidate", "admin", "hiring_manager"])
def get_profile():
    try:
        candidate = get_current_candidate()
        if not candidate:
            return jsonify({"success": False, "message": "Candidate not found"}), 404

        # Return user + candidate data
        return jsonify({
            "success": True,
            "data": {
                "user": candidate.user.to_dict() if candidate.user else {},
                "candidate": candidate.to_dict(),
            }
        }), 200

    except Exception as e:
        current_app.logger.error(f"Get profile error: {e}", exc_info=True)
        return jsonify({"success": False, "message": "Internal server error"}), 500

# ----------------- UPDATE PROFILE -----------------

@candidate_bp.route("/profile", methods=["PUT"])
@role_required(["candidate", "admin", "hiring_manager"])
def update_profile():
    try:
        candidate = get_current_candidate()

        # Auto-create candidate if missing but user exists
        if not candidate:
            user_id = get_jwt_identity()
            user = User.query.get(user_id)
            if not user:
                return jsonify({"success": False, "message": "User not found"}), 404

            candidate = Candidate(user_id=user.id)
            db.session.add(candidate)
            db.session.commit()
            current_app.logger.info(f"Created missing candidate for user id {user.id}")

        user = candidate.user
        data = request.get_json() or {}

        for key, value in data.items():
            # Prevent email from being updated
            if key == "email":
                continue

            # Handle date fields
            if key == "dob":
                if value:
                    try:
                        value = datetime.strptime(value, "%Y-%m-%d").date()
                    except ValueError:
                        return jsonify({"success": False, "message": "Invalid date format, expected YYYY-MM-DD"}), 400
                else:
                    value = None

            # Validate ID number: must be 13 digits, numbers only
            if key == "id_number":
                if value:
                    if not re.fullmatch(r"\d{13}", str(value)):
                        return jsonify({"success": False, "message": "ID number must be exactly 13 digits"}), 400
                    
            # Validate phone number: must be exactly 10 digits, numbers only
            if key == "phone":
                if value:
                    if not re.fullmatch(r"\d{10}", str(value)):
                        return jsonify({
                            "success": False,
                            "message": "Phone number must be exactly 10 digits and contain numbers only"
                        }), 400
         
            # Handle JSON fields if sent as string
            if key in ["skills", "work_experience", "education", "certifications", "languages", "documents"] and isinstance(value, str):
                try:
                    value = json.loads(value)
                except json.JSONDecodeError:
                    value = []

            # Update Candidate attributes
            if hasattr(candidate, key):
                setattr(candidate, key, value)
            # Update User attributes if they exist on User
            elif hasattr(user, key):
                setattr(user, key, value)

        # Keep User.profile in sync with candidate name (for greeting / profile display)
        name_str = (getattr(candidate, "full_name", None) or "").strip()
        if name_str:
            existing = user.profile or {}
            parts = name_str.split(None, 1)
            user.profile = {
                **existing,
                "full_name": name_str,
                "first_name": parts[0] if parts else "",
                "last_name": parts[1] if len(parts) > 1 else "",
            }

        db.session.commit()

        return jsonify({
            "success": True,
            "message": "Profile updated successfully",
            "data": {
                "user": user.to_dict(),
                "candidate": candidate.to_dict(),
            },
        }), 200

    except Exception as e:
        current_app.logger.error(f"Update profile error: {e}", exc_info=True)
        db.session.rollback()
        return jsonify({"success": False, "message": "Internal server error"}), 500



# ----------------- UPLOAD DOCUMENT -----------------
@candidate_bp.route("/upload_document", methods=["POST"])
@role_required(["candidate", "admin", "hiring_manager"])
def upload_document():
    try:
        candidate = get_current_candidate()

        if "document" not in request.files:
            return jsonify({"success": False, "message": "No document uploaded"}), 400

        file = request.files["document"]
        filename = secure_filename(file.filename or "")
        if not filename:
            return jsonify({"success": False, "message": "Invalid filename"}), 400

        allowed_docs = {"pdf", "doc", "docx"}
        if not ('.' in filename and filename.rsplit('.', 1)[1].lower() in allowed_docs):
            return jsonify({"success": False, "message": "Invalid file type"}), 400

        url = HybridResumeAnalyzer.upload_cv(file, filename=filename)
        if not url:
            return jsonify({"success": False, "message": "Failed to upload document"}), 500

        candidate.cv_url = url
        db.session.commit()

        return jsonify({
            "success": True,
            "message": "Document uploaded successfully",
            "data": {"cv_url": url},
        }), 200

    except Exception as e:
        current_app.logger.error(f"Upload document error: {e}", exc_info=True)
        db.session.rollback()
        return jsonify({"success": False, "message": "Internal server error"}), 500


# ----------------- UPLOAD PROFILE PICTURE -----------------
@candidate_bp.route("/upload_profile_picture", methods=["POST"])
@role_required(["candidate", "admin", "hiring_manager"])
def upload_profile_picture():
    try:
        # ---- Get or create Candidate ----
        candidate = get_current_candidate()
        if not candidate:
            user_id = get_jwt_identity()
            user = User.query.get(user_id)
            if not user:
                return jsonify({"success": False, "message": "User not found"}), 404

            candidate = Candidate(user_id=user.id)
            db.session.add(candidate)
            db.session.commit()
            current_app.logger.info(f"Created missing candidate for user id {user.id}")

        # ---- Validate file ----
        if "image" not in request.files:
            return jsonify({"success": False, "message": "No image uploaded"}), 400

        file = request.files["image"]
        filename = secure_filename(file.filename or "")
        if not filename:
            return jsonify({"success": False, "message": "Invalid filename"}), 400

        allowed_images = {"png", "jpg", "jpeg", "webp"}
        ext = filename.rsplit('.', 1)[-1].lower()
        if ext not in allowed_images:
            return jsonify({"success": False, "message": "Invalid image type"}), 400

        # ---- Upload to Cloudinary ----
        result = cloudinary.uploader.upload(
            file,
            folder="profile_pics/",
            format="jpg",  # convert everything to jpg
            resource_type="image",
            public_id=f"candidate_{candidate.id}"
        )
        url = result.get("secure_url")
        if not url:
            return jsonify({"success": False, "message": "Failed to upload image"}), 500

        # ---- Save to candidate profile ----
        candidate.profile_picture = url
        db.session.commit()

        return jsonify({
            "success": True,
            "message": "Profile picture updated successfully",
            "data": {"profile_picture": url},
        }), 200

    except Exception as e:
        current_app.logger.error(f"Upload profile picture error: {e}", exc_info=True)
        db.session.rollback()
        return jsonify({"success": False, "message": "Internal server error"}), 500

# ----------------- UPDATE GENERAL SETTINGS -----------------
@candidate_bp.route("/settings", methods=["PUT"])
@role_required(["candidate", "admin", "hiring_manager"])
def update_settings():
    try:
        user_id = get_jwt_identity()
        user = User.query.get_or_404(user_id)
        data = request.get_json() or {}

        # Merge new settings into existing
        current_settings = user.settings or {}
        updated_settings = {**current_settings, **data}
        user.settings = updated_settings

        db.session.commit()
        return jsonify({
            "success": True,
            "message": "Settings updated successfully",
            "data": user.settings,
        }), 200
    except Exception as e:
        current_app.logger.error(f"Update settings error: {e}", exc_info=True)
        db.session.rollback()
        return jsonify({"success": False, "message": "Internal server error"}), 500


# ----------------- CHANGE PASSWORD -----------------
@candidate_bp.route("/settings/change_password", methods=["POST"])
@role_required(["candidate", "admin", "hiring_manager"])
def change_password():
    try:
        # Get current user
        user_id = get_jwt_identity()
        user = User.query.get_or_404(user_id)

        data = request.get_json() or {}
        current_pw = data.get("current_password")
        new_pw = data.get("new_password")

        if not all([current_pw, new_pw]):
            return jsonify({
                "success": False,
                "message": "Both current and new passwords are required."
            }), 400

        # Verify password using bcrypt
        if not bcrypt.check_password_hash(user.password, current_pw):
            return jsonify({
                "success": False,
                "message": "Incorrect current password."
            }), 400

        # Validate new password length
        if len(new_pw) < 8:
            return jsonify({
                "success": False,
                "message": "New password must be at least 8 characters long."
            }), 400

        # Update password
        user.password = bcrypt.generate_password_hash(new_pw).decode('utf-8')
        db.session.commit()  # commit password change first

        # Log audit using the shorthand
        AuditService.log(
            user_id=user.id,
            action="Change Password",
            target_user_id=user.id,
            metadata={"info": "Candidate changed their password successfully."}
        )

        return jsonify({
            "success": True,
            "message": "Password updated successfully."
        }), 200

    except Exception as e:
        current_app.logger.error(f"Change password error: {e}", exc_info=True)
        db.session.rollback()
        return jsonify({
            "success": False,
            "message": "An error occurred while updating password. Please try again."
        }), 500
# ----------------- UPDATE NOTIFICATION PREFERENCES -----------------
@candidate_bp.route("/settings/notifications", methods=["PUT"])
@role_required(["candidate", "admin", "hiring_manager"])
def update_notification_preferences():
    try:
        user_id = get_jwt_identity()
        user = User.query.get_or_404(user_id)
        data = request.get_json() or {}

        prefs = user.settings.get("notifications", {}) if user.settings else {}
        prefs.update(data)
        user.settings = {**(user.settings or {}), "notifications": prefs}

        db.session.commit()
        return jsonify({
            "success": True,
            "message": "Notification preferences updated",
            "data": user.settings.get("notifications"),
        }), 200
    except Exception as e:
        current_app.logger.error(f"Notification preferences error: {e}", exc_info=True)
        db.session.rollback()
        return jsonify({"success": False, "message": "Internal server error"}), 500


# ----------------- DEACTIVATE ACCOUNT -----------------
@candidate_bp.route("/settings/deactivate", methods=["POST"])
@role_required(["candidate", "admin", "hiring_manager"])
def deactivate_account():
    try:
        user_id = get_jwt_identity()
        user = User.query.get_or_404(user_id)
        reason = (request.get_json() or {}).get("reason", "")

        user.is_active = False
        db.session.commit()

        current_app.logger.info(f"User {user.email} deactivated account. Reason: {reason}")
        return jsonify({"success": True, "message": "Account deactivated successfully"}), 200
    except Exception as e:
        current_app.logger.error(f"Deactivate account error: {e}", exc_info=True)
        db.session.rollback()
        return jsonify({"success": False, "message": "Internal server error"}), 500
    
@candidate_bp.route("/settings", methods=["GET"])
@role_required(["candidate", "admin", "hiring_manager"])
def get_settings():
    user_id = get_jwt_identity()
    user = User.query.get_or_404(user_id)
    return jsonify({
        "success": True,
        "data": user.settings or {}
    }), 200
    
@candidate_bp.route('/notifications', methods=['GET', 'OPTIONS'])
@jwt_required(optional=True)
def get_candidate_notifications():
    """
    Get all notifications for the current candidate.
    OPTIONS allowed for CORS preflight. Returns 401 if not authenticated.
    """
    if request.method == 'OPTIONS':
        return '', 204

    try:
        current_user_id = get_jwt_identity()
        if current_user_id is None:
            return jsonify({'error': 'Unauthorized', 'notifications': []}), 401

        current_user_id = int(current_user_id) if current_user_id is not None else None
        if current_user_id is None:
            return jsonify({'error': 'Invalid token', 'notifications': []}), 401

        notifications = Notification.query.filter_by(
            user_id=current_user_id
        ).order_by(Notification.created_at.desc()).all()

        notifications_data = [n.to_dict() for n in notifications]
        return jsonify(notifications_data), 200

    except Exception as e:
        current_app.logger.error("Get notifications error: %s", e, exc_info=True)
        return jsonify({'error': 'Failed to fetch notifications', 'notifications': []}), 500


# ----------------- SAVE APPLICATION DRAFT -----------------
@candidate_bp.route("/applications/<int:application_id>/draft", methods=["POST"])
@role_required(["candidate"])
def save_application_draft(application_id):
    """
    Save or update a draft for an existing application.
    Supports multiple screens (job_details, assessment, etc.) with merged draft data.
    """
    try:
        user_id = get_jwt_identity()
        candidate = Candidate.query.filter_by(user_id=user_id).first()
        if not candidate:
            return jsonify({"error": "Candidate profile not found"}), 404

        data = request.get_json() or {}
        draft_data = data.get("draft_data", {})  # The actual form/answers
        last_saved_screen = data.get("last_saved_screen", "job_details")

        application = Application.query.filter_by(
            id=application_id, candidate_id=candidate.id
        ).first()
        if not application:
            return jsonify({"error": "Application not found"}), 404

        job = application.requisition
        if not job or not job.is_active or job.deleted_at is not None:
            return jsonify({"error": "Job is not accepting applications"}), 400

        # Merge per-screen draft data
        existing_draft = application.draft_data or {}
        existing_draft[last_saved_screen] = draft_data

        # Update application
        application.draft_data = existing_draft
        application.is_draft = True
        application.status = "draft"
        application.last_saved_screen = last_saved_screen
        application.saved_at = datetime.utcnow()

        db.session.commit()
        
        # Audit log
        AuditService.record_action(
            admin_id=user_id,
            action="Candidate Saved Application Draft",
            target_user_id=user_id,
            actor_label="candidate_id",
            details=f"Saved draft for application ID {application_id}",
            extra_data={"application_id": application_id, "last_saved_screen": last_saved_screen}
        )

        return jsonify({
            "message": "Draft saved successfully",
            "application_id": application.id,
            "draft_data": application.draft_data,  # structured per page
            "last_saved_screen": last_saved_screen,
            "saved_at": application.saved_at.isoformat() if application.saved_at else None
        }), 200

    except Exception as e:
        current_app.logger.error(f"Save draft error: {e}", exc_info=True)
        db.session.rollback()
        return jsonify({"error": "Internal server error"}), 500


# ----------------- GET ALL DRAFT APPLICATIONS -----------------
@candidate_bp.route("/applications/drafts", methods=["GET"])
@role_required(["candidate"])
def get_application_drafts():
    """
    Retrieve all saved (draft) applications for the current candidate.
    Each draft includes per-screen saved data for resuming the application.
    """
    try:
        user_id = get_jwt_identity()
        candidate = Candidate.query.filter_by(user_id=user_id).first()
        if not candidate:
            return jsonify([]), 200

        drafts = Application.query.filter_by(candidate_id=candidate.id, is_draft=True).all()

        draft_list = []
        for d in drafts:
            draft_dict = d.to_dict()
            # Ensure draft_data is structured per screen
            draft_dict["draft_data"] = d.draft_data or {}
            draft_list.append(draft_dict)

        return jsonify(draft_list), 200

    except Exception as e:
        current_app.logger.error(f"Get application drafts error: {e}", exc_info=True)
        return jsonify({"error": "Internal server error"}), 500



# ----------------- SUBMIT SAVED DRAFT -----------------
@candidate_bp.route("/applications/submit_draft/<int:draft_id>", methods=["PUT"])
@role_required(["candidate"])
def submit_draft(draft_id):
    """
    Converts a saved draft back to in_progress so the candidate can continue.
    Application is only considered complete after assessment is submitted (assessment_submitted).
    """
    try:
        user_id = get_jwt_identity()
        candidate = Candidate.query.filter_by(user_id=user_id).first_or_404()

        draft = Application.query.filter_by(
            id=draft_id, candidate_id=candidate.id, is_draft=True
        ).first_or_404()

        job = draft.requisition
        if not job or not job.is_active or job.deleted_at is not None:
            return jsonify({"error": "Job is not accepting applications"}), 400

        draft.is_draft = False
        draft.status = "in_progress"  # Stay in progress until assessment is submitted
        draft.created_at = datetime.utcnow()
        db.session.commit()
        
        # Audit log
        AuditService.record_action(
            admin_id=user_id,
            action="Candidate Submitted Draft Application",
            target_user_id=user_id,
            actor_label="candidate_id",
            details=f"Submitted draft application ID {draft_id}",
            extra_data={"draft_id": draft_id, "application_id": draft.id}
        )

        return jsonify({
            "message": "Draft submitted successfully",
            "application": draft.to_dict()
        }), 200

    except Exception as e:
        current_app.logger.error(f"Submit draft error: {e}", exc_info=True)
        db.session.rollback()
        return jsonify({"error": "Internal server error"}), 500
