# app/services/advanced_ocr_service.py
"""
Minimal OCR/text extraction service for CV files.
Provides extract_text_with_metadata() used by ai_cv_parser and candidate_routes.
Uses pdfplumber and python-docx for PDF/DOCX; plain text for .txt.
"""
import os
import logging
import pdfplumber
import docx

logger = logging.getLogger(__name__)

# Extensions we can extract text from (no heavy OCR by default)
SUPPORTED_EXTENSIONS = {"pdf", "docx", "doc", "txt"}


class AdvancedOCRService:
    """Extract text from CV files (PDF, DOCX, TXT). Returns dict with 'text' and optional metadata."""

    SUPPORTED_EXTENSIONS = SUPPORTED_EXTENSIONS

    def extract_text_with_metadata(self, path: str, ext: str) -> dict:
        """
        Extract text from file at path. ext is the extension without dot (e.g. 'pdf', 'docx').
        Returns dict with at least 'text'; may include extraction_method, confidence, pages, has_scanned_content.
        """
        ext = (ext or "").lower().lstrip(".")
        if ext not in SUPPORTED_EXTENSIONS:
            return {"text": "", "extraction_method": "unsupported", "confidence": 0}

        text = ""
        try:
            if ext == "pdf":
                with pdfplumber.open(path) as pdf:
                    pages = getattr(pdf, "pages", [])
                    text = "\n".join((p.extract_text() or "") for p in pages)
                    num_pages = len(pages)
                return {
                    "text": text,
                    "extraction_method": "pdfplumber",
                    "confidence": 0.9,
                    "pages": num_pages,
                    "has_scanned_content": False,
                }
            if ext in ("docx", "doc"):
                doc = docx.Document(path)
                text = "\n".join(p.text for p in doc.paragraphs)
                return {
                    "text": text,
                    "extraction_method": "python-docx",
                    "confidence": 0.9,
                    "pages": None,
                    "has_scanned_content": False,
                }
            if ext == "txt":
                with open(path, "r", encoding="utf-8", errors="ignore") as f:
                    text = f.read()
                return {
                    "text": text,
                    "extraction_method": "plain_text",
                    "confidence": 1.0,
                    "pages": None,
                    "has_scanned_content": False,
                }
        except Exception as e:
            logger.warning("AdvancedOCRService extract failed for %s: %s", path, e)
            return {"text": "", "extraction_method": "error", "confidence": 0}

        return {"text": "", "extraction_method": "unknown", "confidence": 0}
