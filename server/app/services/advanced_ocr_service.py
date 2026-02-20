import logging
import os
import tempfile
from dataclasses import dataclass
from typing import Any, Dict, List, Optional

import fitz  # PyMuPDF
import pdfplumber  # type: ignore[reportMissingImports]
import pytesseract  # type: ignore[reportMissingImports]
from PIL import Image, ImageEnhance

logger = logging.getLogger(__name__)


@dataclass
class OCRPageData:
    page_number: int
    confidence: float


class AdvancedOCRService:
    def __init__(self, config: Optional[Dict[str, Any]] = None):
        self.config = config or {}
        self.ocr_dpi = int(self.config.get("ocr_dpi", 300))
        self.language = self.config.get("language", "eng")
        self.min_scanned_chars = int(self.config.get("min_scanned_chars", 500))
        self.max_pages_for_ocr = int(self.config.get("max_pages_for_ocr", 20))
        self.preprocess_images = bool(self.config.get("preprocess_images", True))

        self.SUPPORTED_EXTENSIONS = {
            "pdf",
            "docx",
            "txt",
            "rtf",
            "jpg",
            "jpeg",
            "png",
            "tiff",
            "tif",
            "bmp",
            "webp",
        }
        self.IMAGE_EXTENSIONS = {
            "jpg",
            "jpeg",
            "png",
            "tiff",
            "tif",
            "bmp",
            "webp",
        }

    def extract_text_with_metadata(self, file_path: str, ext: str = "") -> Dict[str, Any]:
        ext = (ext or os.path.splitext(file_path)[1].lstrip(".")).lower()
        if ext and ext not in self.SUPPORTED_EXTENSIONS:
            return {
                "success": False,
                "error": f"Unsupported file type: {ext}",
                "text": "",
                "extraction_method": "unsupported",
                "confidence": 0.0,
                "pages": 0,
                "has_scanned_content": False,
            }

        try:
            if ext in self.IMAGE_EXTENSIONS:
                text, conf = self._ocr_image(file_path)
                return {
                    "success": True,
                    "text": text,
                    "extraction_method": "image_ocr",
                    "confidence": conf,
                    "pages": 1,
                    "has_scanned_content": True,
                }

            if ext == "pdf":
                return self._extract_pdf(file_path)

            # For non-PDF non-image types, the caller already has legacy parsing.
            with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
                text = f.read()
            return {
                "success": True,
                "text": text,
                "extraction_method": "text_direct",
                "confidence": 90.0 if text.strip() else 0.0,
                "pages": 1,
                "has_scanned_content": False,
            }
        except Exception as e:
            logger.exception("AdvancedOCRService failed")
            return {
                "success": False,
                "error": str(e),
                "text": "",
                "extraction_method": "error",
                "confidence": 0.0,
                "pages": 0,
                "has_scanned_content": False,
            }

    def _extract_pdf(self, file_path: str) -> Dict[str, Any]:
        text = ""
        pages = 0
        try:
            with pdfplumber.open(file_path) as pdf:
                pages = len(pdf.pages)
                text = "\n".join((p.extract_text() or "") for p in pdf.pages)
        except Exception:
            text = ""

        if text.strip() and len(text.strip()) >= self.min_scanned_chars:
            return {
                "success": True,
                "text": text,
                "extraction_method": "pdf_direct",
                "confidence": self._estimate_confidence(text),
                "pages": pages,
                "has_scanned_content": False,
            }

        # OCR fallback
        try:
            ocr_text, ocr_conf, ocr_pages = self._ocr_pdf(file_path)
            return {
                "success": True,
                "text": ocr_text,
                "extraction_method": "pdf_ocr",
                "confidence": ocr_conf,
                "pages": ocr_pages,
                "has_scanned_content": True,
            }
        except Exception as e:
            logger.exception("PDF OCR fallback failed")
            return {
                "success": True,
                "text": text or "",
                "extraction_method": "pdf_direct" if text else "pdf_empty",
                "confidence": self._estimate_confidence(text),
                "pages": pages,
                "has_scanned_content": bool(not text.strip()),
                "ocr_error": str(e),
            }

    def _ocr_pdf(self, file_path: str) -> (str, float, int):
        doc = fitz.open(file_path)
        page_count = min(len(doc), self.max_pages_for_ocr)
        out_parts: List[str] = []
        confs: List[float] = []

        for i in range(page_count):
            page = doc.load_page(i)
            mat = fitz.Matrix(self.ocr_dpi / 72.0, self.ocr_dpi / 72.0)
            pix = page.get_pixmap(matrix=mat)
            with tempfile.NamedTemporaryFile(delete=False, suffix=".png") as tmp:
                tmp_path = tmp.name
                pix.save(tmp_path)
            try:
                txt, conf = self._ocr_image(tmp_path)
                if txt:
                    out_parts.append(txt)
                if conf:
                    confs.append(conf)
            finally:
                try:
                    os.remove(tmp_path)
                except Exception:
                    pass

        doc.close()
        final_text = "\n".join(out_parts).strip()
        final_conf = float(sum(confs) / len(confs)) if confs else self._estimate_confidence(final_text)
        return final_text, final_conf, len(doc) if len(doc) else page_count

    def _ocr_image(self, file_path: str) -> (str, float):
        img = Image.open(file_path)
        if self.preprocess_images:
            img = img.convert("L")
            img = ImageEnhance.Contrast(img).enhance(1.8)
        data = pytesseract.image_to_data(img, lang=self.language, output_type=pytesseract.Output.DICT)
        words = [w for w in (data.get("text") or []) if w and w.strip()]
        conf_vals = []
        for c in data.get("conf") or []:
            try:
                v = float(c)
                if v >= 0:
                    conf_vals.append(v)
            except Exception:
                pass
        text = " ".join(words).strip()
        conf = float(sum(conf_vals) / len(conf_vals)) if conf_vals else self._estimate_confidence(text)
        return text, conf

    def _estimate_confidence(self, text: str) -> float:
        t = (text or "").strip()
        if not t:
            return 0.0
        # crude heuristic: more text -> higher confidence
        n = len(t)
        if n > 5000:
            return 95.0
        if n > 2000:
            return 90.0
        if n > 500:
            return 85.0
        return 70.0
