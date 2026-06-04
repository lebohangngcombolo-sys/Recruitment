import pdfplumber
from docx import Document

def extract_text_from_file(file):
    """
    Extract text from a CV file.
    Supports: PDF, DOCX, TXT
    """
    filename = file.filename.lower()

    if filename.endswith(".pdf"):
        return extract_pdf(file)

    if filename.endswith(".docx"):
        return extract_docx(file)

    if filename.endswith(".txt"):
        return file.read().decode("utf-8", errors="ignore")

    raise ValueError("Unsupported CV format")


def extract_pdf(file):
    """
    Extract text from a PDF using pdfplumber.
    """
    text = ""
    try:
        with pdfplumber.open(file) as pdf:
            for page in pdf.pages:
                page_text = page.extract_text()
                if page_text:
                    text += page_text + "\n"
        return text.strip()
    except Exception as e:
        raise Exception(f"Failed to extract PDF text: {e}")


def extract_docx(file):
    """
    Extract text from a DOCX file using python-docx.
    """
    try:
        doc = Document(file)
        return "\n".join([p.text for p in doc.paragraphs]).strip()
    except Exception as e:
        raise Exception(f"Failed to extract DOCX text: {e}")
