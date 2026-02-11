# app/services/ai_cv_parser.py
import logging
import re
from typing import Dict, Any
import pdfplumber
import docx

logger = logging.getLogger(__name__)

_analyzer = None

def _get_analyzer():
    """Lazy-load HybridResumeAnalyzer so app starts without loading spaCy/SentenceTransformer."""
    global _analyzer
    if _analyzer is None:
        from .cv_parser_service import HybridResumeAnalyzer
        _analyzer = HybridResumeAnalyzer()
    return _analyzer

class AIParser:

    @staticmethod
    def extract_cv_data(cv_file, job_id: int = 0) -> Dict[str, Any]:
        """
        Reads CV file (PDF, DOCX, TXT), extracts text, and returns structured candidate info.
        Uses HybridResumeAnalyzer (AI + offline fallback).
        Ensures minimal data is always returned for auto-population.
        """
        try:
            cv_text = AIParser.read_cv_file(cv_file)
            if not cv_text.strip():
                logger.warning("CV text empty after extraction.")
                cv_text = ""

            # Step 1: Try AI parsing
            try:
                parsed_data = _get_analyzer().analyse(resume_content=cv_text, job_id=job_id)
            except Exception as e:
                logger.warning(f"AI parsing failed: {e}")
                parsed_data = {}

            # Step 2: Offline fallback extraction
            fallback_data = AIParser.offline_extract(cv_text)

            # Step 3: Merge AI results with fallback (AI overrides fallback if present)
            merged = {**fallback_data, **parsed_data} if parsed_data else fallback_data
            merged["cv_text"] = cv_text

            # Ensure all expected keys exist
            keys = [
                "full_name", "email", "phone", "dob", "linkedin", "github",
                "portfolio", "education", "skills", "certifications",
                "languages", "experience", "position", "previous_companies",
                "bio", "match_score", "missing_skills", "suggestions"
            ]
            for k in keys:
                if k not in merged:
                    merged[k] = "" if isinstance(fallback_data.get(k, ""), str) else []

            return merged

        except Exception as e:
            logger.exception("AI CV parsing failed: %s", e)
            return {"cv_text": cv_file.filename, "error": str(e)}

    @staticmethod
    def offline_extract(cv_text: str) -> Dict[str, Any]:
        """
        Basic regex-based extraction to ensure minimal auto-fill.
        """
        # Extract email
        email_match = re.search(r'[\w\.-]+@[\w\.-]+', cv_text)
        email = email_match.group(0) if email_match else ""

        # Extract phone (simple international/local formats)
        phone_match = re.search(r'\+?\d[\d\s\-\(\)]{7,}', cv_text)
        phone = phone_match.group(0) if phone_match else ""

        # Extract name (very basic heuristic: first 2 capitalized words in CV)
        name_match = re.search(r'([A-Z][a-z]+(?:\s[A-Z][a-z]+)?)', cv_text)
        full_name = name_match.group(0) if name_match else ""

        # Extract skills (simple keyword matching)
        skill_keywords = ["Python", "Java", "Flutter", "Dart", "React", "SQL", "Node", "AWS"]
        skills = [skill for skill in skill_keywords if re.search(rf'\b{skill}\b', cv_text, re.I)]

        # Extract education (look for common degree keywords)
        education_keywords = ["BSc", "MSc", "Bachelor", "Master", "PhD", "Diploma"]
        education = [edu for edu in education_keywords if re.search(rf'\b{edu}\b', cv_text, re.I)]

        return {
            "full_name": full_name,
            "email": email,
            "phone": phone,
            "dob": "",  # Could implement date regex if needed
            "linkedin": "",
            "github": "",
            "portfolio": "",
            "education": education,
            "skills": skills,
            "certifications": [],
            "languages": [],
            "experience": "",
            "position": "",
            "previous_companies": [],
            "bio": "",
            "match_score": 0,
            "missing_skills": [],
            "suggestions": []
        }

    @staticmethod
    def read_cv_file(cv_file) -> str:
        import os, tempfile
        temp_path = os.path.join(tempfile.gettempdir(), cv_file.filename)
        cv_file.save(temp_path)
        text = ""
        if cv_file.filename.lower().endswith(".pdf"):
            with pdfplumber.open(temp_path) as pdf:
                text = "\n".join(page.extract_text() or "" for page in pdf.pages)
        elif cv_file.filename.lower().endswith(".docx"):
            doc = docx.Document(temp_path)
            text = "\n".join(p.text for p in doc.paragraphs)
        else:
            # fallback for TXT
            with open(temp_path, "r", encoding="utf-8", errors="ignore") as f:
                text = f.read()
        return text