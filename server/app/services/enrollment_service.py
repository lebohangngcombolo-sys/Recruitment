import json
from datetime import datetime, date
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm.exc import NoResultFound
import requests

from app.extensions import db
from app.models import Candidate, User, CVAnalysis
from app.services.audit2 import AuditService
from app.services.ai_cv_parser import AIParser
from app.services.cv_to_candidate_mapper import map_extraction_to_candidate
from app.services.ai_service import AIService


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
        "%b %Y",
        "%B %Y",
        "%m/%Y",
    )

    CV_TEXT_MIN_LENGTH = 120
    HF_ANALYSIS_URL = "https://dzunisani007-cv-analyser.hf.space/api/v1/analyze"
    HF_HEALTH_URL = "https://dzunisani007-cv-analyser.hf.space/health"

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
    def _normalize_date(value):
        if not value:
            return None

        if isinstance(value, date):
            return value

        value = str(value).strip()
        if value.lower() in ("present", "current", "now", "today"):  # map to today (or keep None)
            return date.today()

        for fmt in EnrollmentService.DATE_FORMATS:
            try:
                parsed = datetime.strptime(value, fmt).date()
                return parsed
            except ValueError:
                continue

        # Generic fallback for YYYY and YYYY-MM
        try:
            if re.match(r"^\d{4}$", value):
                return date(int(value), 1, 1)
            if re.match(r"^\d{4}-\d{2}$", value):
                year, month = map(int, value.split("-"))
                return date(year, month, 1)
        except Exception:
            pass

        return None

    @staticmethod
    def _dedupe_skills(*lists):
        merged = []
        seen = set()
        for skills in lists:
            if not skills:
                continue
            if isinstance(skills, str):
                items = [s.strip() for s in skills.split(",") if s.strip()]
            elif isinstance(skills, list):
                items = [str(s).strip() for s in skills if str(s).strip()]
            else:
                continue

            for skill in items:
                key = skill.lower()
                if key not in seen:
                    seen.add(key)
                    merged.append(skill)

        return merged

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
    def analyze_cv_with_hf(cv_text):
        """
        Analyze CV text using HuggingFace CV analyser service
        Returns structured data for autofill
        """
        if not cv_text or not isinstance(cv_text, str) or len(cv_text.strip()) < EnrollmentService.CV_TEXT_MIN_LENGTH:
            return None

        try:
            payload = {
                "cv_text": cv_text,
                "job_description": "General candidate profile analysis for enrollment autofill",
                "extract_structured": True,
                "generate_questions": False,
                "generate_suggestions": True,
            }

            # Submit analysis
            response = requests.post(EnrollmentService.HF_ANALYSIS_URL, json=payload, timeout=30)
            if response.status_code != 200:
                return None

            data = response.json() if response.content else {}
            external_analysis_id = data.get("analysis_id")
            if not external_analysis_id:
                return None

            # Poll for results
            for _ in range(30):
                status_response = requests.get(f"{EnrollmentService.HF_ANALYSIS_URL}/{external_analysis_id}/status", timeout=10)
                if status_response.status_code == 200:
                    status = status_response.json()
                    status_code = status.get("status")

                    if status_code == "completed":
                        result_response = requests.get(f"{EnrollmentService.HF_ANALYSIS_URL}/{external_analysis_id}/result", timeout=30)
                        if result_response.status_code == 200:
                            result_payload = result_response.json()
                            result_payload["external_analysis_id"] = external_analysis_id
                            return result_payload
                    elif status_code in {"failed", "error"}:
                        return None

                import time
                time.sleep(2)

            return None

        except requests.RequestException as e:
            print(f"HF CV analysis request failed: {e}")
            return None
        except Exception as e:
            print(f"HF CV analysis failed: {e}")
            return None

    @staticmethod
    def map_cv_analysis_to_form_fields(cv_analysis_data):
        """
        Map HuggingFace CV analysis results to enrollment form fields
        Returns dict with field names as keys and extracted values
        """
        if not cv_analysis_data or not isinstance(cv_analysis_data, dict):
            return {}

        structured_data = cv_analysis_data.get("structured_data", {}) or {}
        match_analysis = cv_analysis_data.get("match_analysis", {}) or {}

        mapped_fields = {}

        # Personal Details
        personal_info = structured_data.get("personal_details") or structured_data.get("personal_info") or {}
        mapped_fields["full_name"] = personal_info.get("full_name") or personal_info.get("name") or ""
        mapped_fields["phone"] = personal_info.get("phone") or personal_info.get("contact") or ""
        mapped_fields["email"] = personal_info.get("email") or personal_info.get("email_address") or ""
        mapped_fields["address"] = personal_info.get("address") or ""
        mapped_fields["linkedin"] = personal_info.get("linkedin") or ""
        mapped_fields["github"] = personal_info.get("github") or ""
        mapped_fields["portfolio"] = personal_info.get("portfolio") or personal_info.get("website") or ""
        mapped_fields["bio"] = structured_data.get("professional_summary") or structured_data.get("summary") or personal_info.get("bio") or ""

        if personal_info.get("dob"):
            dob = EnrollmentService._normalize_date(personal_info.get("dob"))
            if dob:
                mapped_fields["dob"] = dob.isoformat()

        # Education
        education_data = structured_data.get("education") or []
        if isinstance(education_data, list):
            mapped_fields["education"] = education_data
            if education_data:
                latest = education_data[0]
                if isinstance(latest, dict):
                    mapped_fields["university"] = latest.get("institution") or latest.get("school") or ""
                    mapped_fields["graduation_year"] = latest.get("year") or latest.get("graduation_year") or ""
        elif isinstance(education_data, str):
            mapped_fields["education"] = [education_data]

        # Work experience
        experience_data = structured_data.get("work_experience") or structured_data.get("experience") or []
        if isinstance(experience_data, list):
            mapped_fields["work_experience"] = experience_data
            companies = [e.get("company") for e in experience_data if isinstance(e, dict) and e.get("company")]
            titles = [e.get("title") for e in experience_data if isinstance(e, dict) and e.get("title")]
            descriptions = [e.get("description") for e in experience_data if isinstance(e, dict) and e.get("description")]
            if companies:
                mapped_fields["previous_companies"] = ", ".join(dict.fromkeys(companies))
            if titles:
                mapped_fields["position"] = titles[0]
            if descriptions:
                mapped_fields["experience"] = "\n\n".join(descriptions)
        elif isinstance(experience_data, str):
            mapped_fields["work_experience"] = [{"description": experience_data}]
            mapped_fields["experience"] = experience_data

        # Skills & dedupe
        extracted_skills = structured_data.get("skills", [])
        matched_skills = (match_analysis.get("matched_skills") if isinstance(match_analysis.get("matched_skills"), list) else [])
        merged_skills = EnrollmentService._dedupe_skills(extracted_skills, matched_skills)
        if merged_skills:
            mapped_fields["skills"] = merged_skills

        # Certifications / languages
        certs = structured_data.get("certifications") or []
        if isinstance(certs, list):
            mapped_fields["certifications"] = certs
        elif isinstance(certs, str):
            mapped_fields["certifications"] = [s.strip() for s in certs.split(",") if s.strip()]

        langs = structured_data.get("languages") or []
        if isinstance(langs, list):
            mapped_fields["languages"] = langs
        elif isinstance(langs, str):
            mapped_fields["languages"] = [s.strip() for s in langs.split(",") if s.strip()]

        # Additional fields
        mapped_fields["cv_text"] = cv_analysis_data.get("cv_text") or ""
        if cv_analysis_data.get("external_analysis_id"):
            mapped_fields["analysis_id"] = cv_analysis_data.get("external_analysis_id")

        # Remove empty keys from mapped output if no value
        mapped_fields = {k: v for k, v in mapped_fields.items() if v not in (None, "", [], {})}

        return mapped_fields

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
            # Enhanced CV Processing with HuggingFace
            # ------------------------------------
            cv_analysis_data = None
            
            if cv_file:
                try:
                    # Step 1: Extract CV text
                    cv_text = AIParser.read_cv_file(cv_file)
                    if cv_text and cv_text.strip():
                        # Step 2: Analyze with HuggingFace
                        cv_analysis_data = EnrollmentService.analyze_cv_with_hf(cv_text)
                        
                        if cv_analysis_data:
                            # Step 3: Map to form fields
                            hf_mapped_fields = EnrollmentService.map_cv_analysis_to_form_fields(cv_analysis_data)
                            # Manual input takes precedence over AI
                            payload = {**hf_mapped_fields, **payload}

                            # Persist CV analysis for audit/tracing
                            try:
                                cv_analysis_result = cv_analysis_data if isinstance(cv_analysis_data, dict) else {}
                                cv_analysis = CVAnalysis(
                                    candidate_id=candidate.id,
                                    job_description="Enrollment autofill analysis",
                                    cv_text=cv_text,
                                    result=cv_analysis_result,
                                    status="completed" if cv_analysis_data else "failed",
                                    external_analysis_id=(cv_analysis_data or {}).get("external_analysis_id"),
                                    started_at=datetime.utcnow(),
                                    finished_at=datetime.utcnow(),
                                )
                                db.session.add(cv_analysis)
                            except Exception as e:
                                print(f"Warning: unable to record CVAnalysis: {e}")

                        # Step 4: Fallback to local AI parser
                        ai_data = AIParser.extract_cv_data(cv_file) or {}
                        
                        # Use AI to structure raw experience into multiple work_experience entries
                        work_structured = None
                        try:
                            raw_exp = (ai_data.get("experience") or "") if isinstance(ai_data.get("experience"), str) else ""
                            if raw_exp and len(raw_exp.strip()) > 20:
                                ai = AIService()
                                work_structured = ai.structure_cv_experience(
                                    raw_exp,
                                    position_hint=ai_data.get("position") or "",
                                    companies_hint=ai_data.get("previous_companies")
                                    if isinstance(ai_data.get("previous_companies"), list)
                                    else None,
                                )
                        except Exception:
                            work_structured = None

                        # Map extraction keys to Candidate fields
                        candidate_mapped = map_extraction_to_candidate(
                            ai_data, work_experience_structured=work_structured
                        )
                        # Manual input takes precedence over AI
                        payload = {**candidate_mapped, **payload}
                        
                except Exception as e:
                    print(f"CV processing failed: {e}")
                    # Continue without CV processing

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
            # Sync display name to User.profile so /api/auth/me and users table stay consistent
            # (CV upload and manual enrollment both save here; users.profile will have full_name)
            # ------------------------------------
            full_name = getattr(candidate, "full_name", None) or payload.get("full_name")
            if full_name:
                name_str = (full_name if isinstance(full_name, str) else str(full_name)).strip()
                if name_str:
                    existing = dict(user.profile) if user.profile else {}
                    parts = name_str.split(None, 1)
                    user.profile = {
                        **existing,
                        "full_name": name_str,
                        "first_name": parts[0] if parts else "",
                        "last_name": parts[1] if len(parts) > 1 else "",
                    }

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
                    actor_label="candidate_id",
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
