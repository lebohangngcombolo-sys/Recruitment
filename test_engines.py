import sys
sys.path.append('/mnt/c/Users/User/CascadeProjects/cv-analyser-backend/cv-analyser')
from app.services.ocr_service import OCRService

ocr = OCRService()
path = '../Bob Mabena CV.pdf'

print("--- TESTING ENGINES ---")
# 1. Native Multi
try:
    t, q, m = ocr._native_pdf_extraction_multi_engine(path)
    print(f"ENGINE: {m} (Quality: {q})")
    print(f"START: [{t[:200]}]")
except Exception as e:
    print(f"Native fail: {e}")

# 2. PyMuPDF directly
try:
    t = ocr._extract_with_pymupdf(path)
    print(f"ENGINE: pymupdf (raw)")
    print(f"START: [{t[:200]}]")
except Exception as e:
    print(f"PyMuPDF fail: {e}")

# 3. OCR (Tesseract)
try:
    t = ocr._ocr_pdf_extraction(path)
    print(f"ENGINE: tesseract")
    print(f"START: [{t[:200]}]")
except Exception as e:
    print(f"Tesseract fail: {e}")
