import json
from datetime import datetime, date
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm.exc import NoResultFound

from app.extensions import db
from app.models import Candidate, User
from app.services.audit2 import AuditService
from app.services.ai_cv_parser import AIParser


class EnrollmentService:
    """
    Handles candidate enrollment and profile initialization.
    This service is deterministic and safe:
    - No silent failures
    - Explicit field handling
    - JSON-safe for Flutter multipart payloads
    - AI CV parsing is strictly whitelisted
    """

    # -----------------------------
    # Field definitions
    # -----------------------------
    SIMPLE_FIELDS = {
        "full_name",
        "phone",
        "address",
        "gender",
        "bio",
        "title",
        "location",
        "nationality",
        "id_number",
        "linkedin",
        "github",
        "portfolio",
        "cover_letter",
        "profile_picture",
        "cv_url",
        "cv_text",
    }

    JSON_FIELDS = {
        "education",
        "skills",
        "work_experience",
        "certifications",
        "languages",
        "documents",
        "profile",
    }

    AI_ALLOWED_FIELDS = {
        "skills",
        "education",
        "work_experience",
        "certifications",
        "languages",
        "cv_text",
    }

    DATE_FORMATS = (
        "%Y-%m-%d",
        "%d/%m/%Y",
        "%Y-%m-%dT%H:%M:%S",
    )

    # -----------------------------
    # Helpers
    # -----------------------------
    @staticmethod
    def _parse_json(value):
        if isinstance(value, (dict, list)):
            return value
        if isinstance(value, str):
            try:
                return json.loads(value)
            except ValueError:
                return None
        return None

    @staticmethod
    def _parse_dob(value):
        if isinstance(value, date):
            return value
        if isinstance(value, str):
            for fmt in EnrollmentService.DATE_FORMATS:
                try:
                    parsed = datetime.strptime(value, fmt).date()
                    if parsed > date.today():
                        return None
                    return parsed
                except ValueError:
                    continue
        return None

    @staticmethod
    def _get_or_create_candidate(user_id):
        candidate = (
            db.session.query(Candidate)
            .filter_by(user_id=user_id)
            .one_or_none()
        )

        if candidate:
            return candidate

        candidate = Candidate(user_id=user_id)
        db.session.add(candidate)
        db.session.flush()
        return candidate

    # -----------------------------
    # Main API
    # -----------------------------
    @staticmethod
    def save_candidate_enrollment(user_id, payload, cv_file=None):
        """
        Create or update candidate enrollment.

        :param user_id: Authenticated user ID
        :param payload: dict of form fields (multipart safe)
        :param cv_file: optional file path to CV
        :return: (response_dict, http_status)
        """

        try:
            user = db.session.get(User, user_id)
            if not user:
                return {"error": "User not found"}, 404

            candidate = EnrollmentService._get_or_create_candidate(user.id)

            # ------------------------------------
            # AI CV parsing (optional, safe)
            # ------------------------------------
            if cv_file:
                try:
                    ai_data = AIParser.extract_cv_data(cv_file) or {}
                except Exception:
                    ai_data = {}

                ai_data = {
                    k: v for k, v in ai_data.items()
                    if k in EnrollmentService.AI_ALLOWED_FIELDS
                }

                # Manual input takes precedence
                payload = {**ai_data, **payload}

            saved_fields = set()

            # ------------------------------------
            # Simple scalar fields
            # ------------------------------------
            for field in EnrollmentService.SIMPLE_FIELDS:
                if field in payload:
                    setattr(candidate, field, payload[field])
                    saved_fields.add(field)

            # ------------------------------------
            # Date of birth
            # ------------------------------------
            if "dob" in payload:
                dob = EnrollmentService._parse_dob(payload["dob"])
                if not dob:
                    return {"error": "Invalid date of birth"}, 400
                candidate.dob = dob
                saved_fields.add("dob")

            # ------------------------------------
            # JSON fields
            # ------------------------------------
            for field in EnrollmentService.JSON_FIELDS:
                if field in payload:
                    parsed = EnrollmentService._parse_json(payload[field])
                    if parsed is None:
                        continue
                    setattr(candidate, field, parsed)
                    saved_fields.add(field)

            # ------------------------------------
            # Prevent false success
            # ------------------------------------
            if not saved_fields:
                return {"error": "No valid enrollment data provided"}, 400

            # ------------------------------------
            # Enrollment state
            # ------------------------------------
            if not user.enrollment_completed:
                user.enrollment_completed = True

            # ------------------------------------
            # Commit
            # ------------------------------------
            db.session.commit()

            # ------------------------------------
            # Audit (non-blocking)
            # ------------------------------------
            try:
                AuditService.log(
                    user_id=user.id,
                    action="candidate_enrollment_completed",
                    metadata={
                        "candidate_id": candidate.id,
                        "fields": sorted(saved_fields),
                    },
                )
            except Exception:
                pass

            return {
                "message": "Enrollment completed successfully",
                "saved_fields": sorted(saved_fields),
                "candidate": candidate.to_dict(),
            }, 200

        except SQLAlchemyError:
            db.session.rollback()
            return {"error": "Database error while saving enrollment"}, 500

        except Exception:
            db.session.rollback()
            return {"error": "Enrollment failed"}, 500
