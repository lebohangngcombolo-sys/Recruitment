# app/services/advanced_ocr_service.py
"""
Minimal OCR/text extraction service for CV files.
Provides extract_text_with_metadata() used by ai_cv_parser and candidate_routes.
Uses pdfplumber and python-docx for PDF/DOCX; plain text for .txt.
When PDF yields very little text (scanned/image PDF), tries Tesseract OCR if available.
"""
import os
import logging
import tempfile
import pdfplumber
import docx

logger = logging.getLogger(__name__)

# Minimum characters from pdfplumber below which we consider the PDF scanned and try OCR
PDF_LOW_TEXT_THRESHOLD = 80

# Extensions we can extract text from (no heavy OCR by default)
SUPPORTED_EXTENSIONS = {"pdf", "docx", "doc", "txt"}


def _run_tesseract_ocr_on_pdf(path: str):
    """
    Try to extract text from PDF using Tesseract OCR (optional dependency).
    Renders PDF pages to images then runs Tesseract. Returns (text, num_pages).
    """
    try:
        import fitz  # PyMuPDF
    except ImportError:
        logger.debug("PyMuPDF (fitz) not available for OCR fallback")
        return "", 0
    try:
        import pytesseract
    except ImportError:
        logger.debug("pytesseract not installed; OCR fallback skipped")
        return "", 0
    try:
        doc = fitz.open(path)
        num_pages = len(doc)
        texts = []
        for i in range(num_pages):
            page = doc.load_page(i)
            pix = page.get_pixmap(dpi=150, alpha=False)
            with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
                pix.save(tmp.name)
                try:
                    t = pytesseract.image_to_string(tmp.name)
                    if t and t.strip():
                        texts.append(t.strip())
                except Exception as e:
                    logger.warning("Tesseract failed on page %s: %s", i + 1, e)
                finally:
                    try:
                        os.unlink(tmp.name)
                    except OSError:
                        pass
        doc.close()
        return "\n\n".join(texts), num_pages
    except Exception as e:
        logger.warning("OCR fallback failed for %s: %s", path, e)
        return "", 0


class AdvancedOCRService:
    """Extract text from CV files (PDF, DOCX, TXT). Returns dict with 'text' and optional metadata."""

    SUPPORTED_EXTENSIONS = SUPPORTED_EXTENSIONS

    def extract_text_with_metadata(self, path: str, ext: str) -> dict:
        """
        Extract text from file at path. ext is the extension without dot (e.g. 'pdf', 'docx').
        Returns dict with at least 'text'; may include extraction_method, confidence, pages, has_scanned_content.
        For PDFs that yield very little text, tries Tesseract OCR and sets has_scanned_content=True.
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
                has_scanned = len((text or "").strip()) < PDF_LOW_TEXT_THRESHOLD
                if has_scanned:
                    ocr_text, ocr_pages = _run_tesseract_ocr_on_pdf(path)
                    if ocr_text and ocr_text.strip():
                        text = ocr_text
                        return {
                            "text": text,
                            "extraction_method": "tesseract_ocr",
                            "confidence": 0.75,
                            "pages": ocr_pages,
                            "has_scanned_content": True,
                        }
                    return {
                        "text": text,
                        "extraction_method": "pdfplumber",
                        "confidence": 0.5,
                        "pages": num_pages,
                        "has_scanned_content": True,
                    }
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
