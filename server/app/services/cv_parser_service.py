import os
import re
import logging
import json
from dotenv import load_dotenv
from openai import OpenAI
from app.models import Requisition
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

        prompt = f"""Resume:
{resume_content}

Job Description:
{job_description}

Task:
- Analyze the resume against the job description.
- Give a match score out of 100.
- Highlight missing skills or experiences.
- Suggest improvements.

Return valid JSON only with keys: match_score (int), missing_skills (list), suggestions (list), recommendation (string), raw_text (string).
"""
        try:
            response = self.openai_client.chat.completions.create(
                model=os.getenv("OPENROUTER_MODEL", "openrouter/auto"),
                messages=[
                    {"role": "system", "content": "You are an AI recruitment assistant. Always return results in valid JSON format only."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.0,
                max_tokens=int(os.getenv("OPENROUTER_MAX_TOKENS", "1024")),
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
        """Fallback parser for legacy OpenRouter text outputs."""
        score_match = re.search(r"(\d{1,3})(?:/100|%)", text)
        match_score = int(score_match.group(1)) if score_match else 0

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
    # Lightweight Offline Analysis (Keyword-only)
    # ----------------------------
    def analyse_offline_keywords(self, resume_content, job_description):
        """Simple keyword-only offline NLP analysis as a low-cost fallback."""
        resume_lower = (resume_content or "").lower()
        job_lower = (job_description or "").lower()

        resume_words = set(re.findall(r'\b[a-z]{3,}\b', resume_lower))
        job_words = set(re.findall(r'\b[a-z]{3,}\b', job_lower))

        missing_skills = list(job_words - resume_words)
        total_skills = len(job_words)
        matched_skills = total_skills - len(missing_skills)
        match_score = int((matched_skills / total_skills) * 100) if total_skills else 0

        suggestions = ["Consider highlighting missing skills in your resume."] if missing_skills else []

        return {
            "match_score": match_score,
            "missing_skills": missing_skills,
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

        job_description = job.description or ""

        # Try online first
        if self.openai_client:
            result = self.analyse_online(resume_content, job_description)
            if result and "Error during online analysis" not in result.get("raw_text", ""):
                return result

        # Fallback to lightweight keyword-only analysis
        return self.analyse_offline_keywords(resume_content, job_description)

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
