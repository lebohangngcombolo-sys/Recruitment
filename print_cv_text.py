
import sys
import os

# Paths
BACKEND_PATH = r"c:/Users/User/CascadeProjects/cv-analyser-backend/cv-analyser"
WSL_BACKEND_PATH = "/mnt/c/Users/User/CascadeProjects/cv-analyser-backend/cv-analyser"

if os.path.exists(WSL_BACKEND_PATH):
    sys.path.append(WSL_BACKEND_PATH)
    sys.path.append(os.path.join(WSL_BACKEND_PATH, "app"))
else:
    sys.path.append(BACKEND_PATH)
    sys.path.append(os.path.join(BACKEND_PATH, "app"))

try:
    from app.services.ocr_service import OCRService
except ImportError as e:
    print(f"❌ Could not import OCRService: {e}")
    sys.exit(1)

def print_text(pdf_path):
    ocr = OCRService()
    text, meta = ocr.extract_text(pdf_path, ".pdf")
    print("-" * 40)
    print("EXTRACTED TEXT:")
    print("-" * 40)
    print(text)
    print("-" * 40)
    print("METADATA:", meta)

if __name__ == "__main__":
    cv_path = "/mnt/c/Users/User/Recruitment/Bob Mabena CV.pdf"
    if not os.path.exists(cv_path):
        cv_path = r"c:\Users\User\Recruitment\Bob Mabena CV.pdf"
        
    if os.path.exists(cv_path):
        print_text(cv_path)
    else:
        print(f"File not found: {cv_path}")
