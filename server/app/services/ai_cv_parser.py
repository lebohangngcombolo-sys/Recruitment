# app/services/ai_cv_parser.py
import logging
import re
from typing import Dict, Any
import pdfplumber
import docx

from app.services.advanced_ocr_service import AdvancedOCRService
from app.services.cv_pattern_matcher import CVPatternMatcher

logger = logging.getLogger(__name__)

_analyzer = None


def _merge_autofill_overlay_non_empty(base: Dict[str, Any], overlay: Dict[str, Any]) -> Dict[str, Any]:
    """
    Keep rich regex/offline fields; overlay keys from AI only when overlay has a
    non-empty value. Prevents parsed_data from wiping phone/skills/education with
    "" or [] when AI returns a partial schema.
    """
    out = dict(base) if isinstance(base, dict) else {}
    if not isinstance(overlay, dict):
        return out
    for k, v in overlay.items():
        if v is None:
            continue
        if isinstance(v, str):
            if v.strip():
                out[k] = v
        elif isinstance(v, list):
            if len(v) > 0:
                out[k] = v
        elif isinstance(v, dict):
            if len(v) > 0:
                out[k] = v
        else:
            out[k] = v
    return out

def _get_analyzer():
    """Lazy-load HybridResumeAnalyzer so app starts without loading spaCy/SentenceTransformer."""
    global _analyzer
    if _analyzer is None:
        from .cv_parser_service import HybridResumeAnalyzer
        _analyzer = HybridResumeAnalyzer()
    return _analyzer


class _AnalyzerProxy:
    """Lazy proxy that loads the analyzer on first use."""

    def __getattr__(self, name):
        return getattr(_get_analyzer(), name)


# Public singleton proxy used by Celery tasks
analyzer = _AnalyzerProxy()

class AIParser:

    @staticmethod
    def extract_cv_data_from_bytes(
        file_content: bytes, filename: str, job_id: int = 0
    ) -> Dict[str, Any]:
        """
        Parse CV from raw bytes. Use this after ``request.files['cv'].read()`` so local
        extraction always sees the full file.
        """
        from io import BytesIO
        from werkzeug.datastructures import FileStorage

        if not file_content:
            logger.warning("extract_cv_data_from_bytes: empty upload")
            return {"cv_text": "", "error": "Empty file"}

        stream = BytesIO(file_content)
        fs = FileStorage(
            stream=stream,
            filename=(filename or "cv.pdf").strip() or "cv.pdf",
        )
        return AIParser.extract_cv_data(fs, job_id=job_id)

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

            # Step 3: Merge AI results with fallback (AI overlays only non-empty values)
            merged = (
                _merge_autofill_overlay_non_empty(fallback_data, parsed_data)
                if parsed_data
                else fallback_data
            )
            merged["cv_text"] = cv_text

            # Ensure all expected keys exist
            keys = [
                "full_name", "email", "phone", "address", "dob", "linkedin", "github",
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
            fn = getattr(cv_file, "filename", str(cv_file))
            return {"cv_text": fn, "error": str(e)}

    @staticmethod
    def offline_extract(cv_text: str) -> Dict[str, Any]:
        """
        Basic regex-based extraction to ensure minimal auto-fill.
        """
        try:
            matcher = CVPatternMatcher()
            extracted = matcher.extract_all(cv_text)
        except Exception:
            extracted = {}

        # Maintain backward-compatible keys
        extracted.setdefault("dob", "")
        extracted.setdefault("previous_companies", [])
        extracted.setdefault("bio", "")
        extracted.setdefault("match_score", 0)
        extracted.setdefault("missing_skills", [])
        extracted.setdefault("suggestions", [])
        extracted.setdefault("certifications", [])
        extracted.setdefault("languages", [])
        extracted.setdefault("education", [])
        extracted.setdefault("skills", [])
        extracted.setdefault("experience", "")
        extracted.setdefault("position", "")
        extracted.setdefault("address", "")
        extracted.setdefault("linkedin", "")
        extracted.setdefault("github", "")
        extracted.setdefault("portfolio", "")
        extracted.setdefault("email", "")
        extracted.setdefault("phone", "")
        extracted.setdefault("full_name", "")

        return extracted

    @staticmethod
    def read_cv_file(cv_file) -> str:
        import os
        import tempfile

        filename = (getattr(cv_file, "filename", None) or "cv").strip()
        _, ext = os.path.splitext(filename)
        ext = (ext or "").lower().lstrip(".")

        with tempfile.NamedTemporaryFile(delete=False, suffix=f".{ext}" if ext else "") as tmp:
            temp_path = tmp.name
        
        try:
            # Important: Reset stream pointer before saving
            if hasattr(cv_file, "seek"):
                cv_file.seek(0)
            cv_file.save(temp_path)

            # Ensure data was actually written
            if os.path.exists(temp_path) and os.path.getsize(temp_path) == 0:
                 logger.warning(f"File saved to {temp_path} is empty. Was the stream already consumed?")
            
            # First try hybrid OCR/text extraction.
            try:
                svc = AdvancedOCRService()
                result = svc.extract_text_with_metadata(temp_path, ext)
                text = (result.get("text") or "")
                if text.strip():
                    return text
            except Exception:
                pass

            # Fallback to legacy parsing.
            text = ""
            if filename.lower().endswith(".pdf"):
                with pdfplumber.open(temp_path) as pdf:
                    text = "\n".join(page.extract_text() or "" for page in pdf.pages)
            elif filename.lower().endswith(".docx"):
                doc = docx.Document(temp_path)
                text = "\n".join(p.text for p in doc.paragraphs)
            else:
                with open(temp_path, "r", encoding="utf-8", errors="ignore") as f:
                    text = f.read()
            return text
        finally:
            try:
                os.remove(temp_path)
            except Exception:
                pass
