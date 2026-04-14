import sys
sys.path.append('/mnt/c/Users/User/CascadeProjects/cv-analyser-backend/cv-analyser')
from app.services.ocr_service import OCRService

ocr = OCRService()
text, _ = ocr.extract_text('../Bob Mabena CV.pdf', '.pdf')
lines = text.strip().split('\n')
print("--- FIRST 10 LINES ---")
for i, line in enumerate(lines[:10]):
    print(f"{i}: [{line}]")
print("----------------------")
