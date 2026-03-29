# app/services/lightweight_perfect_ocr.py
"""
Lightweight Perfect OCR Service optimized for Render deployment
Focuses on essential improvements without heavy dependencies
"""

import os
import logging
import tempfile
import re
from typing import Dict, Optional
import pdfplumber
import docx

logger = logging.getLogger(__name__)

# Configuration
PDF_LOW_TEXT_THRESHOLD = 80
OCR_DPI = 300  # High DPI for better accuracy
SUPPORTED_EXTENSIONS = {"pdf", "docx", "doc", "txt"}

class LightweightPerfectOCR:
    """Lightweight OCR service optimized for Render deployment"""
    
    def __init__(self):
        self.tesseract_available = self._check_tesseract()
        if self.tesseract_available:
            logger.info("Lightweight Perfect OCR with Tesseract enabled")
        else:
            logger.warning("Tesseract not available, using native extraction only")
    
    def _check_tesseract(self) -> bool:
        """Check if Tesseract OCR is available"""
        try:
            import pytesseract
            pytesseract.get_tesseract_version()
            return True
        except (ImportError, Exception):
            return False
    
    def extract_text_with_metadata(self, path: str, ext: str) -> Dict:
        """
        Extract text with improved accuracy using optimized approach
        """
        ext = (ext or "").lower().lstrip(".")
        if ext not in SUPPORTED_EXTENSIONS:
            return {"text": "", "extraction_method": "unsupported", "confidence": 0}
        
        try:
            if ext == "pdf":
                return self._extract_from_pdf_optimized(path)
            elif ext in ("docx", "doc"):
                return self._extract_from_docx(path)
            elif ext == "txt":
                return self._extract_from_txt(path)
        except Exception as e:
            logger.error(f"Text extraction failed for {path}: {e}")
            return {"text": "", "extraction_method": "error", "confidence": 0}
        
        return {"text": "", "extraction_method": "unknown", "ki": 0}
    
    def _extract_from_pdf_optimized(self, path: str) -> Dict:
        """Optimized PDF extraction with smart OCR fallback"""
        # Step 1: Try native text extraction with enhanced settings
        try:
            with pdfplumber.open(path) as pdf:
                pages = getattr(pdf, "pages", [])
                native_text = ""
                
                # Enhanced extraction with layout consideration
                for page in pages:
                    # Try different extraction methods
                    page_text = page.extract_text() or ""
                    
                    # If basic extraction fails, try with settings
                    if not page_text.strip():
                        page_text = page.extract_text(x_tolerance=1, y_tolerance=1) or ""
                    
                    # If still fails, try word-based extraction
                    if not page_text.strip():
                        words = page.extract_words()
                        if words:
                            page_text = " ".join([word['text'] for word in words])
                    
                    native_text += page_text + "\n"
                
                num_pages = len(pages)
        except Exception as e:
            logger.warning(f"Enhanced pdfplumber failed: {e}")
            native_text = ""
            num_pages = 0
        
        # Step 2: Quality assessment with enhanced metrics
        text_quality = self._assess_text_quality(native_text)
        
        if text_quality['is_high_quality']:
            return {
                "text": native_text.strip(),
                "extraction_method": "pdfplumber_enhanced",
                "confidence": text_quality['confidence'],
                "pages": num_pages,
                "has_scanned_content": False,
                "quality_metrics": text_quality
            }
        
        # Step 3: Optimized OCR for scanned PDFs
        if self.tesseract_available:
            logger.info("PDF appears scanned, using optimized OCR")
            ocr_result = self._run_optimized_tesseract_ocr(path)
            
            if ocr_result["text"].strip():
                # Compare quality and choose best
                ocr_quality = self._assess_text_quality(ocr_result["text"])
                
                if ocr_quality['confidence'] > text_quality['confidence']:
                    return {
                        "text": ocr_result["text"],
                        "extraction_method": "tesseract_optimized",
                        "confidence": ocr_quality['confidence'],
                        "pages": ocr_result["pages"],
                        "has_scanned_content": True,
                        "quality_metrics": ocr_quality
                    }
        
        # Fallback to native text with low confidence
        return {
            "text": native_text.strip(),
            "extraction_method": "pdfplumber_fallback",
            "confidence": max(text_quality['confidence'], 0.3),
            "pages": num_pages,
            "has_scanned_content": True,
            "quality_metrics": text_quality
        }
    
    def _extract_from_docx(self, path: str) -> Dict:
        """Extract text from DOCX with quality assessment"""
        try:
            doc = docx.Document(path)
            text = "\n".join(p.text for p in doc.paragraphs)
            quality = self._assess_text_quality(text)
            
            return {
                "text": text,
                "extraction_method": "python-docx",
                "confidence": quality['confidence'],
                "pages": None,
                "has_scanned_content": False,
                "quality_metrics": quality
            }
        except Exception as e:
            logger.error(f"DOCX extraction failed: {e}")
            return {"text": "", "extraction_method": "error", "confidence": 0}
    
    def _extract_from_txt(self, path: str) -> Dict:
        """Extract text from TXT with quality assessment"""
        try:
            with open(path, "r", encoding="utf-8", errors="ignore") as f:
                text = f.read()
            quality = self._assess_text_quality(text)
            
            return {
                "text": text,
                "extraction_method": "plain_text",
                "confidence": quality['confidence'],
                "pages": None,
                "has_scanned_content": False,
                "quality_metrics": quality
            }
        except Exception as e:
            logger.error(f"TXT extraction failed: {e}")
            return {"text": "", "extraction_method": "error", "confidence": 0}
    
    def _run_optimized_tesseract_ocr(self, path: str) -> Dict:
        """Optimized Tesseract OCR for better accuracy"""
        try:
            import pytesseract
            from PIL import Image
            import fitz  # PyMuPDF
            
            doc = fitz.open(path)
            num_pages = len(doc)
            texts = []
            
            for i in range(num_pages):
                page = doc.load_page(i)
                
                # High DPI for better accuracy
                pix = page.get_pixmap(dpi=OCR_DPI, alpha=False)
                
                with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
                    pix.save(tmp.name)
                    
                    try:
                        # Optimized Tesseract configuration
                        custom_config = r'--oem 3 --psm 6 -c tessedit_char_whitelist=0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz@.-()[]{}:;/\#$%^&*!?,\'" '
                        
                        # Preprocess image with PIL for better OCR
                        img = Image.open(tmp.name)
                        
                        # Convert to grayscale
                        if img.mode != 'L':
                            img = img.convert('L')
                        
                        # Resize for better OCR (scale up if too small)
                        width, height = img.size
                        if width < 2000 or height < 2000:
                            scale = max(2000/width, 2000/height)
                            new_width = int(width * scale)
                            new_height = int(height * scale)
                            img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
                        
                        # Apply OCR
                        text = pytesseract.image_to_string(img, config=custom_config, lang='eng')
                        
                        if text and text.strip():
                            texts.append(text.strip())
                    
                    except Exception as e:
                        logger.warning(f"OCR failed on page {i+1}: {e}")
                    finally:
                        try:
                            os.unlink(tmp.name)
                        except OSError:
                            pass
            
            doc.close()
            return {
                "text": "\n\n".join(texts),
                "pages": num_pages
            }
            
        except ImportError:
            logger.warning("PyMuPDF or pytesseract not available")
            return {"text": "", "pages": 0}
        except Exception as e:
            logger.error(f"Optimized OCR failed: {e}")
            return {"text": "", "pages": 0}
    
    def _assess_text_quality(self, text: str) -> Dict:
        """Assess text quality with comprehensive metrics"""
        if not text or not text.strip():
            return {
                'confidence': 0.0,
                'is_high_quality': False,
                'text_length': 0,
                'pattern_score': 0,
                'readability_score': 0
            }
        
        text = text.strip()
        text_length = len(text)
        
        # Base confidence from text length
        if text_length > 1000:
            length_confidence = 0.8
        elif text_length > 500:
            length_confidence = 0.6
        elif text_length > 100:
            length_confidence = 0.4
        else:
            length_confidence = 0.2
        
        # Pattern recognition score
        pattern_score = 0
        
        # Email patterns
        emails = len(re.findall(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b', text))
        if emails > 0:
            pattern_score += 0.15
        
        # Phone patterns
        phones = len(re.findall(r'(\+\d{1,3}[-.]?)?\(?\d{3}\)?[-.]?\d{3}[-.]?\d{4}', text))
        if phones > 0:
            pattern_score += 0.15
        
        # URL patterns
        urls = len(re.findall(r'https?://[^\s]+', text))
        if urls > 0:
            pattern_score += 0.1
        
        # CV-specific keywords
        cv_keywords = [
            'experience', 'education', 'skills', 'project', 'university', 
            'college', 'degree', 'bachelor', 'master', 'phd', 'work',
            'employment', 'company', 'position', 'responsibilities'
        ]
        keyword_count = sum(1 for keyword in cv_keywords if keyword.lower() in text.lower())
        if keyword_count >= 3:
            pattern_score += 0.2
        elif keyword_count >= 1:
            pattern_score += 0.1
        
        # Readability score (ratio of meaningful characters)
        meaningful_chars = sum(1 for c in text if c.isalnum() or c.isspace() or c in '.-;')
        if len(text) > 0:
            readability = meaningful_chars / len(text)
            readability_score = readability * 0.3
        else:
            readability_score = 0
        
        # Overall confidence
        overall_confidence = (
            length_confidence * 0.3 +
            min(pattern_score, 0.6) * 0.4 +
            readability_score * 0.3
        )
        
        # Determine if high quality
        is_high_quality = (
            overall_confidence > 0.6 and
            text_length > 200 and
            pattern_score > 0.2
        )
        
        return {
            'confidence': min(overall_confidence, 1.0),
            'is_high_quality': is_high_quality,
            'text_length': text_length,
            'pattern_score': min(pattern_score, 1.0),
            'readability_score': readability_score
        }
