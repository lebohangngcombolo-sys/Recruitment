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
        # 🆕 Autofill columns for easier data access and validation
        "education_level",
        "university",
        "graduation_year",
        "previous_companies",
        "experience_summary",
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
    @staticmethod
    def _get_analysis_url():
        from flask import current_app
        base = current_app.config.get("ANALYSIS_SERVICE_URL", "http://localhost:8000")
        return f"{base.rstrip('/')}/api/v1/analyze"

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
            analysis_url = EnrollmentService._get_analysis_url()
            response = requests.post(analysis_url, json=payload, timeout=30)
            if response.status_code != 200:
                return None

            data = response.json() if response.content else {}
            external_analysis_id = data.get("analysis_id")
            if not external_analysis_id:
                return None

            # Poll for results
            for _ in range(30):
                status_response = requests.get(f"{analysis_url}/{external_analysis_id}/status", timeout=10)
                if status_response.status_code == 200:
                    status = status_response.json()
                    status_code = status.get("status")

                    if status_code == "completed":
                        result_response = requests.get(f"{analysis_url}/{external_analysis_id}/result", timeout=30)
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
        Prefer autofill_data if available, otherwise fallback to structured_data.
        """
        if not cv_analysis_data or not isinstance(cv_analysis_data, dict):
            return {}

        # 1. Prefer autofill_data (pre-normalized)
        autofill = cv_analysis_data.get("autofill_data") or {}
        structured_data = cv_analysis_data.get("structured_data") or {}
        match_analysis = cv_analysis_data.get("match_analysis") or {}
        cv_text = cv_analysis_data.get("cv_text") or cv_analysis_data.get("raw_text") or cv_analysis_data.get("raw_payload", {}).get("cv_text") or ""
        autofill = cv_analysis_data.get("autofill_data") or {}

        # 🛡️ FATAL FALLBACK: If HF didn't provide autofill natively (e.g. Space not updated), generate it dynamically!
        if not autofill and cv_text:
            try:
                from app.services.autofill_mapper import AutofillMapper
                # Ensure cv_text is formatted correctly for mapper
                if "raw_text" not in cv_analysis_data:
                    cv_analysis_data["raw_text"] = cv_text
                mapper = AutofillMapper()
                autofill_resp = mapper.map_to_autofill(cv_analysis_data)
                
                def serialize_model(m):
                    if hasattr(m, 'model_dump'): return m.model_dump()
                    if hasattr(m, '__dict__'): return m.__dict__
                    return dict(m)
                    
                autofill = {
                    "personal": serialize_model(autofill_resp.personal) if autofill_resp.personal else {},
                    "experience": [serialize_model(e) for e in autofill_resp.experience] if autofill_resp.experience else [],
                    "education": [serialize_model(e) for e in autofill_resp.education] if autofill_resp.education else [],
                    "skills": autofill_resp.skills or [],
                    "certifications": autofill_resp.certifications or [],
                    "languages": autofill_resp.languages or []
                }
            except Exception as e:
                import logging
                logging.getLogger(__name__).warning(f"EnrollmentService dynamically generating autofill failed: {e}")

        mapped_fields = {}

        # Helper to get field with fallback - scrubs "None" strings
        def get_field(path, default=""):
            parts = path.split('.')
            val = autofill
            for part in parts:
                if isinstance(val, dict):
                    val = val.get(part)
                elif isinstance(val, list) and isinstance(part, int):
                    val = val[part] if part < len(val) else None
                else:
                    val = None
                    break
            # Scrub "None" strings and empty values
            if val is None or val == "None" or val == "null" or str(val).strip() in ["", "None", "null"]:
                return default
            return val

        # Personal Details
        mapped_fields["full_name"] = get_field("personal.full_name") or \
                                     structured_data.get("personal_details", {}).get("full_name") or \
                                     structured_data.get("personal_info", {}).get("name") or ""
        
        # Fallback: Extract name from raw CV text using regex if still empty
        if not mapped_fields["full_name"] and cv_text:
            import re
            # Look for name patterns in first 20 lines
            lines = cv_text.split('\n')[:20]
            for line in lines:
                line = line.strip()
                # Pattern: 2-3 capitalized words (exclude common non-name words)
                if re.match(r"^[A-Z][a-z]+\s+[A-Z][a-z]+(\s+[A-Z][a-z]+)?$", line):
                    # Exclude common headers
                    exclude = ['CURRICULUM VITAE', 'RESUME', 'PROFILE', 'CONTACT', 'EDUCATION', 'EXPERIENCE', 'SKILLS']
                    if line.upper() not in exclude and not any(e in line.upper() for e in exclude):
                        mapped_fields["full_name"] = line
                        break
        
        mapped_fields["phone"] = get_field("personal.phone") or \
                                 structured_data.get("personal_details", {}).get("phone") or ""
        
        mapped_fields["email"] = get_field("personal.email") or \
                                 structured_data.get("personal_details", {}).get("email") or ""
        
        mapped_fields["address"] = get_field("personal.address") or \
                                   structured_data.get("personal_details", {}).get("address") or ""
        
        mapped_fields["linkedin"] = get_field("personal.linkedin") or ""
        mapped_fields["github"] = get_field("personal.github") or ""
        mapped_fields["portfolio"] = get_field("personal.portfolio") or ""
        
        mapped_fields["bio"] = get_field("personal.summary") or \
                               structured_data.get("professional_summary") or \
                               structured_data.get("summary") or ""
        
        # Gender extraction
        mapped_fields["gender"] = get_field("personal.gender") or \
                                  structured_data.get("personal_details", {}).get("gender") or ""

        dob_val = get_field("personal.dob")
        if dob_val:
            dob = EnrollmentService._normalize_date(dob_val)
            if dob:
                mapped_fields["dob"] = dob.isoformat()

        # Education - transform to frontend-compatible format
        education_data = autofill.get("education") or structured_data.get("education") or []
        if isinstance(education_data, list):
            # Transform HF keys (degree, university, year) to frontend keys (level, institution, graduation_year)
            transformed_education = []
            for edu in education_data:
                if isinstance(edu, dict):
                    # Scrub "None" strings
                    def scrub_edu(val):
                        if val is None or val == "None" or str(val).strip() in ["", "None", "null"]:
                            return ""
                        return str(val).strip()
                    
                    degree = scrub_edu(edu.get("degree") or edu.get("level"))
                    institution = scrub_edu(edu.get("university") or edu.get("institution") or edu.get("school"))
                    year = scrub_edu(edu.get("year") or edu.get("graduation_year"))
                    
                    # Only add if at least one field has content
                    if degree or institution or year:
                        transformed_education.append({
                            "level": degree,
                            "institution": institution,
                            "graduation_year": year
                        })
            mapped_fields["education"] = transformed_education
            
            if transformed_education:
                latest = transformed_education[0]
                mapped_fields["education_level"] = latest.get("level") or ""
                mapped_fields["university"] = latest.get("institution") or ""
                mapped_fields["graduation_year"] = latest.get("graduation_year") or ""
        elif isinstance(education_data, str):
            mapped_fields["education"] = [{"level": education_data, "institution": "", "graduation_year": ""}]

        # Work experience - transform to frontend-compatible format
        experience_data = autofill.get("experience") or structured_data.get("work_experience") or structured_data.get("experience") or []
        if isinstance(experience_data, list):
            # Transform HF keys (title) to frontend keys (position)
            transformed_experience = []
            for exp in experience_data:
                if isinstance(exp, dict):
                    # Data scrubber: convert "None" strings to empty
                    def scrub_exp(val):
                        if val is None or val == "None" or str(val).strip() in ["", "None", "null"]:
                            return ""
                        return str(val).strip()
                    
                    # Extract and scrub all fields
                    pos = scrub_exp(exp.get("title") or exp.get("position"))
                    com = scrub_exp(exp.get("company"))
                    desc = scrub_exp(exp.get("description"))
                    
                    # Build period string
                    start_date = scrub_exp(exp.get("start_date"))
                    end_date = scrub_exp(exp.get("end_date")) or "Present"
                    period = exp.get("period") or ""
                    if not period and (start_date or end_date):
                        period = f"{start_date} - {end_date}".strip(" -")
                    period = scrub_exp(period)
                    
                    # Only add if there's real content (not just "None" strings)
                    if pos or com or desc:
                        transformed_experience.append({
                            "position": pos,
                            "company": com,
                            "description": desc,
                            "period": period
                        })
            mapped_fields["work_experience"] = transformed_experience
            
            companies = [e.get("company") for e in transformed_experience if e.get("company")]
            positions = [e.get("position") for e in transformed_experience if e.get("position")]
            if companies:
                mapped_fields["previous_companies"] = ", ".join(dict.fromkeys(companies))
            if positions:
                mapped_fields["position"] = positions[0]
            
            if transformed_experience:
                exp_strings = []
                for e in transformed_experience:
                    # Data scrubber: convert "None" strings to empty
                    def scrub(val):
                        if val is None or val == "None" or str(val).strip() in ["", "None", "null"]:
                            return ""
                        return str(val).strip()
                    
                    pos = scrub(e.get('position'))
                    com = scrub(e.get('company'))
                    
                    # Build display string: "Position at Company" or just "Position" or "Company"
                    if pos and com:
                        pos_com = f"{pos} at {com}"
                    elif pos:
                        pos_com = pos
                    elif com:
                        pos_com = com
                    else:
                        pos_com = ""
                    
                    period_str = scrub(e.get('period'))
                    desc_str = scrub(e.get('description'))
                    
                    # Only include non-empty parts
                    parts = [p for p in [pos_com, period_str, desc_str] if p]
                    if parts:  # Only add entry if there's actual content
                        exp_strings.append("\n".join(parts))
                
                mapped_fields["experience_summary"] = "\n\n".join(exp_strings) if exp_strings else ""

        # ------------------------------------
        # Enrollment state
        # ------------------------------------
        if not user.enrollment_completed:
            user.enrollment_completed = True
        extracted_skills = autofill.get("skills") or structured_data.get("skills", [])
        matched_skills = (match_analysis.get("matched_skills") if isinstance(match_analysis.get("matched_skills"), list) else [])
        merged_skills = EnrollmentService._dedupe_skills(extracted_skills, matched_skills)
        if merged_skills:
            mapped_fields["skills"] = merged_skills

        # Certifications / languages
        certs = autofill.get("certifications") or structured_data.get("certifications") or []
        if isinstance(certs, list):
            mapped_fields["certifications"] = certs
        elif isinstance(certs, str):
            mapped_fields["certifications"] = [s.strip() for s in certs.split(",") if s.strip()]

        langs = autofill.get("languages") or structured_data.get("languages") or []
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
        Uses HF CV-analyser as single source of extraction (Option A).
        """
        from app.services.analysis_service_client import AnalysisServiceClient

        try:
            user = db.session.get(User, user_id)
            if not user:
                return {"error": "User not found"}, 404

            candidate = EnrollmentService._get_or_create_candidate(user.id)

            if cv_file:
                try:
                    # Single source of truth: Upload file to HF
                    import os
                    filename = os.path.basename(cv_file)
                    with open(cv_file, 'rb') as f:
                        file_content = f.read()

                    job_desc = payload.get("job_description") or "Enrollment program application"
                    
                    submit = AnalysisServiceClient.submit_cv_file(
                        file_content,
                        filename,
                        job_description=job_desc
                    )
                    
                    external_id = (submit or {}).get("analysis_id")
                    if external_id:
                        # Wait for result
                        result = AnalysisServiceClient.wait_for_result(external_id)
                        if result:
                            # Map result to form fields
                            hf_mapped = EnrollmentService.map_cv_analysis_to_form_fields(result)
                            # Manual input takes precedence
                            payload = {**hf_mapped, **payload}

                            # Persist analysis record
                            cv_analysis = CVAnalysis(
                                candidate_id=candidate.id,
                                job_description=job_desc,
                                cv_text=result.get("cv_text", ""),
                                result=result,
                                status="completed",
                                external_analysis_id=external_id,
                                started_at=datetime.utcnow(),
                                finished_at=datetime.utcnow(),
                            )
                            db.session.add(cv_analysis)
                    
                except Exception as e:
                    print(f"Option A CV processing failed: {e}")
                    # Fallback to local AI parser ONLY if HF fails and user explicitly wants a fallback
                    # For now, let's keep it simple and just log error.

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
