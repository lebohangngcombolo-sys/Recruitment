import os
import re
import logging
import json
from dotenv import load_dotenv
from openai import OpenAI
from app.models import Requisition
from app.services.job_service import JobService
from app.services.cv_analysis_utils import truncate_for_cv_prompt
from cloudinary.uploader import upload as cloudinary_upload
from jsonschema import validate, ValidationError

# ----------------------------
# Environment & Logging Setup
# ----------------------------
load_dotenv()
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ----------------------------
# LLM Output Schema
# ----------------------------
LLM_OUTPUT_SCHEMA = {
    "type": "object",
    "properties": {
        "match_score": {"type": "number", "minimum": 0, "maximum": 100},
        "missing_skills": {"type": "array", "items": {"type": "string"}},
        "suggestions": {"type": "array", "items": {"type": "string"}},
        "recommendation": {"type": "string"},
        "raw_text": {"type": "string"}
    },
    "required": ["match_score", "raw_text"]
}

# ----------------------------
# Hybrid Resume Analyzer (Online-first, lightweight fallback)
# ----------------------------
class HybridResumeAnalyzer:
    def __init__(self):
        # --- Online AI client ---
        api_key = os.getenv("OPENROUTER_API_KEY")
        self.openai_client = None
        if api_key:
            try:
                timeout_value = float(os.getenv("OPENROUTER_TIMEOUT", "30"))
                self.openai_client = OpenAI(
                    base_url="https://openrouter.ai/api/v1",
                    api_key=api_key,
                    default_headers={"HTTP-Referer": os.getenv("BACKEND_URL", "http://localhost:5000")},
                    timeout=timeout_value,
                )
                logger.info("OpenRouter client initialized.")
            except Exception as e:
                logger.error(f"Failed to initialize OpenRouter client: {e}")

    # ----------------------------
    # Online Analysis
    # ----------------------------
    def analyse_online(self, resume_content, job_description):
        """Analyse resume using OpenRouter API and validate JSON output."""
        if not self.openai_client:
            return None

        resume_content, job_description = truncate_for_cv_prompt(
            resume_content or "", job_description or ""
        )
        prompt = f"""Resume:
{resume_content}

Job spec (may include role, description, responsibilities, qualifications, required skills, minimum experience):
{job_description}

Task:
- Analyze the resume against the full job spec. Consider skills, qualifications, experience, and responsibilities.
- Give a match score out of 100.
- Highlight missing skills or experiences from the job spec.
- Suggest improvements.

Return valid JSON only with keys: match_score (int), missing_skills (list), suggestions (list), recommendation (string), raw_text (string).
"""
        requested = int(os.getenv("OPENROUTER_MAX_TOKENS", "1024"))
        cap = int(os.getenv("AI_MAX_OUTPUT_TOKENS", "600"))
        max_tokens = min(requested, cap)
        try:
            response = self.openai_client.chat.completions.create(
                model=os.getenv("OPENROUTER_MODEL", "openrouter/auto"),
                messages=[
                    {"role": "system", "content": "You are an AI recruitment assistant. Always return results in valid JSON format only."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.0,
                max_tokens=max_tokens,
            )
            text = getattr(response.choices[0].message, "content", "") or ""

            # Try to parse JSON from the response
            try:
                parsed = json.loads(text)
                # Validate against schema
                validate(parsed, LLM_OUTPUT_SCHEMA)
                parsed.setdefault("missing_skills", [])
                parsed.setdefault("suggestions", [])
                parsed.setdefault("recommendation", "")
                parsed["raw_text"] = text
                return parsed
            except (json.JSONDecodeError, ValidationError) as e:
                logger.warning(f"LLM returned invalid JSON, falling back to regex parse: {e}")
                return self._parse_openrouter_response(text)
        except Exception as e:
            logger.error(f"Online analysis failed: {e}")
            return {
                "match_score": 0,
                "missing_skills": [],
                "suggestions": [],
                "recommendation": "",
                "raw_text": f"Error during online analysis: {str(e)}"
            }

    def _parse_openrouter_response(self, text):
        """Fallback parser for legacy OpenRouter text outputs. match_score clamped to 0-100."""
        score_match = re.search(r"(\d{1,3})(?:/100|%)", text)
        match_score = int(score_match.group(1)) if score_match else 0
        match_score = max(0, min(100, match_score))

        missing_skills_match = re.search(r"Missing Skills:\s*(.*?)(?:Suggestions:|$)", text, re.DOTALL)
        missing_skills = []
        if missing_skills_match:
            skills_text = missing_skills_match.group(1)
            missing_skills = [line.strip("- ").strip() for line in skills_text.strip().splitlines() if line.strip()]

        suggestions_match = re.search(r"Suggestions:\s*(.*)", text, re.DOTALL)
        suggestions = []
        if suggestions_match:
            suggestions_text = suggestions_match.group(1)
            suggestions = [line.strip("- ").strip() for line in suggestions_text.strip().splitlines() if line.strip()]

        return {
            "match_score": match_score,
            "missing_skills": missing_skills,
            "suggestions": suggestions,
            "recommendation": "",
            "raw_text": text
        }

    # ----------------------------
    # Lightweight Offline Analysis (curated terms when job available, else keyword-only)
    # ----------------------------
    def analyse_offline_keywords(self, resume_content, job_description, job=None):
        """Offline analysis: compare against curated job terms (required_skills, qualifications, responsibilities) when job is provided; otherwise bag-of-words from job_description. match_score always 0-100."""
        resume_content, job_description = truncate_for_cv_prompt(resume_content or "", job_description or "")
        resume_lower = (resume_content or "").lower()
        resume_words = set(re.findall(r'\b[a-z0-9]{2,}\b', resume_lower))

        if job and (getattr(job, "required_skills", None) or getattr(job, "qualifications", None) or getattr(job, "responsibilities", None)):
            job_terms = set()
            for attr in ("required_skills", "qualifications", "responsibilities"):
                val = getattr(job, attr, None)
                if not val:
                    continue
                items = val if isinstance(val, list) else [val]
                for item in items:
                    s = (item if isinstance(item, str) else str(item)).lower()
                    tokens = re.findall(r'\b[a-z0-9]{2,}\b', s)
                    job_terms.update(tokens)
            if not job_terms:
                job_lower = (job_description or "").lower()
                job_terms = set(re.findall(r'\b[a-z0-9]{2,}\b', job_lower))
        else:
            job_lower = (job_description or "").lower()
            job_terms = set(re.findall(r'\b[a-z0-9]{2,}\b', job_lower))

        missing_skills = list(job_terms - resume_words)
        total_terms = len(job_terms)
        matched = total_terms - len(missing_skills)
        if total_terms:
            match_score = int((matched / total_terms) * 100)
            match_score = max(0, min(100, match_score))
        else:
            # No job spec to compare: use 30% baseline so a non-empty CV does not get 0
            resume_len = len((resume_content or "").strip())
            match_score = 30 if resume_len > 100 else (min(30, (resume_len // 3)) if resume_len else 0)
            match_score = max(0, min(100, match_score))

        suggestions = ["Consider highlighting missing skills in your resume."] if missing_skills else []

        return {
            "match_score": match_score,
            "missing_skills": missing_skills[:50],
            "suggestions": suggestions,
            "recommendation": "",
            "raw_text": "Offline keyword-only analysis performed"
        }

    # ----------------------------
    # Hybrid Wrapper (online -> keyword fallback)
    # ----------------------------
    def analyse(self, resume_content, job_id):
        job = Requisition.query.get(job_id)
        if not job:
            return {
                "match_score": 0,
                "missing_skills": [],
                "suggestions": [],
                "recommendation": "",
                "raw_text": "Job not found"
            }

        job_spec = JobService.build_job_spec_for_cv(job)

        # Try online first
        if self.openai_client:
            result = self.analyse_online(resume_content, job_spec)
            if result and "Error during online analysis" not in result.get("raw_text", ""):
                return result

        # Fallback to lightweight keyword-only analysis
        return self.analyse_offline_keywords(resume_content, job_spec, job=job)

    # ----------------------------
    # Cloudinary Upload (Candidate_CV folder for easy retrieval)
    # ----------------------------
    CLOUDINARY_CV_FOLDER = "Candidate_CV"

    @staticmethod
    def _sanitize_public_id(name):
        """Make a safe public_id: alphanumeric, dots, hyphens, underscores only."""
        if not name or not name.strip():
            return "cv"
        base = name.strip()
        if "/" in base or "\\" in base:
            base = base.replace("\\", "/").split("/")[-1]
        safe = "".join(c if c.isalnum() or c in "._-" else "_" for c in base)
        return safe[:200] or "cv"

    @staticmethod
    def upload_cv(file, filename=None):
        """Upload CV to Cloudinary (folder: Candidate_CV) and return secure URL.
        Accepts file path (str) or file-like object (e.g. Werkzeug FileStorage).
        Pass filename so the asset is stored with the correct name and format in Cloudinary.
        """
        try:
            if isinstance(file, str):
                path = file
                name = filename or path.split("/")[-1].split("\\")[-1] or "cv.pdf"
                public_id = HybridResumeAnalyzer._sanitize_public_id(name)
                with open(file, "rb") as f:
                    result = cloudinary_upload(
                        f,
                        resource_type="raw",
                        folder=HybridResumeAnalyzer.CLOUDINARY_CV_FOLDER,
                        public_id=public_id,
                    )
            else:
                stream = getattr(file, "stream", file)
                if hasattr(stream, "seek"):
                    stream.seek(0)
                name = filename or getattr(file, "filename", None) or "resume.pdf"
                public_id = HybridResumeAnalyzer._sanitize_public_id(name)
                result = cloudinary_upload(
                    file,
                    resource_type="raw",
                    folder=HybridResumeAnalyzer.CLOUDINARY_CV_FOLDER,
                    public_id=public_id,
                )
            return result.get("secure_url") if result else None
        except Exception as e:
            logger.error("Cloudinary upload failed: %s", e, exc_info=True)
            return None
