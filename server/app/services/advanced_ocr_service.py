# app/services/advanced_ocr_service.py
"""
Text extraction from CV files (PDF, DOCX, TXT).
Can be extended later with real OCR (e.g. Tesseract) for image PDFs.
"""
import logging
from typing import Any, Dict

import docx  # type: ignore[reportMissingImports]
import pdfplumber  # type: ignore[reportMissingImports]

logger = logging.getLogger(__name__)


class AdvancedOCRService:
    """Extract text from CV files. Uses pdfplumber/docx for native text; extend for OCR if needed."""

    SUPPORTED_EXTENSIONS = frozenset({"pdf", "docx", "doc", "txt", "text"})

    def extract_text_with_metadata(self, path: str, ext: str) -> Dict[str, Any]:
        """
        Extract text from a file at path. ext is the extension without dot (e.g. 'pdf', 'docx').
        Returns a dict with at least 'text'; may include 'metadata' or 'pages' later.
        """
        ext = (ext or "").lower().lstrip(".")
        text = ""
        try:
            if ext == "pdf" or path.lower().endswith(".pdf"):
                with pdfplumber.open(path) as pdf:
                    text = "\n".join(
                        (page.extract_text() or "") for page in pdf.pages
                    )
            elif ext in ("docx", "doc") or path.lower().endswith((".docx", ".doc")):
                doc = docx.Document(path)
                text = "\n".join(p.text for p in doc.paragraphs)
            else:
                with open(path, "r", encoding="utf-8", errors="ignore") as f:
                    text = f.read()
        except Exception as e:
            logger.warning("advanced_ocr_service extract failed for %s: %s", path, e)
        return {"text": text.strip(), "metadata": {}}
