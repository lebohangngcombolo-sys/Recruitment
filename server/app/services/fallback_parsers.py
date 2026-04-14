import re
from typing import List, Dict
import logging

logger = logging.getLogger(__name__)


def _norm(s: object) -> str:
    return str(s or "").strip()


def _looks_like_location(s: str) -> bool:
    v = (s or "").strip().lower()
    if not v:
        return False
    # Common CV locations that should not become "company" values.
    locations = {
        "cape town",
        "johannesburg",
        "pretoria",
        "durban",
        "south africa",
        "gauteng",
        "western cape",
    }
    return v in locations


def _looks_like_section_header(s: str) -> bool:
    v = (s or "").strip().lower()
    if not v:
        return False
    return v in {
        "professional experience",
        "work experience",
        "experience",
        "education",
        "certifications",
        "skills",
        "core skills",
        "projects",
    }


def _looks_like_degree(s: str) -> bool:
    v = (s or "").strip().lower()
    if not v:
        return False
    # Accept either common abbreviations or degree keywords.
    if re.search(r"\b(b\.?sc\.?|b\.?a\.?|m\.?sc\.?|m\.?a\.?|ph\.?d\.?|mba)\b", v, re.I):
        return True
    return bool(re.search(r"\b(bachelor|master|doctorate|diploma|certificate|degree)\b", v, re.I))


def _looks_like_institution(s: str) -> bool:
    v = (s or "").strip().lower()
    if not v:
        return False
    return bool(re.search(r"\b(university|college|institute|school|academy)\b", v, re.I))

def validate_experience_entry(exp: Dict) -> bool:
    """Check if an experience entry has minimum required data."""
    if not isinstance(exp, dict):
        return False
    # Must have either title or company, and not be empty placeholders
    title = _norm(exp.get("title"))
    company = _norm(exp.get("company"))

    if len(title) <= 2 and len(company) <= 2:
        return False

    # Reject titles that are too long (likely a chunk of text misidentified)
    if len(title) > 60:
        return False

    # Reject obvious non-job "titles".
    if _looks_like_section_header(title):
        return False
    if re.search(r"\byears?\s+of\s+experience\b", title, re.I):
        return False
    if re.search(r"\b(summary|profile|professional background|curriculum vitae)\b", title, re.I):
        return False
    
    # NEW: Reject titles that look like certification levels
    cert_keywords = ["specialty", "associate", "professional", "foundational", "expert", "specialist", "certification"]
    is_cert_title = any(kw in title.lower() for kw in cert_keywords)
    
    # If it's a known cert title AND company has "Certified", reject.
    if is_cert_title and re.search(r"\b(certified|certification|certificate|aws|google|microsoft|cisco|azure)\b", company, re.I):
        # But wait, if company is ONLY "AWS", and title is "Architect", it might be a job.
        # So we only reject if "Certified" is present
        if re.search(r"\b(certified|certification|certificate)\b", company, re.I):
            return False

    # Reject obvious non-company values (locations, headings).
    if _looks_like_section_header(company) or _looks_like_location(company):
        return False

    # Filter out companies that are just years or noise
    if re.match(r"^\d{1,2}\s+years?$", company, re.I) or len(company) < 2:
        return False

    # HIGH CONFIDENCE PASS: If title contains a job keyword, it's likely a job.
    job_keywords = r"\b(analyst|engineer|developer|manager|specialist|consultant|director|lead|intern|worker|officer|architect|researcher|scientist|administrator|technician|coordinator|assistant|representative|associate|executive|principal|founder|owner|pilot|doctor|nurse|lecturer|professor|teacher)\b"
    if title and re.search(job_keywords, title, re.I):
        # EXCEPT if it contains "PROFESSIONAL" or "EXPERIENCE" in the title string (often header leakage)
        if re.search(r"\b(professional|experience|work|employment)\b", title, re.I) and len(title) > 20:
             return False
        # EXCEPT if it's explicitly a "Certified [Title]"
        if re.search(r"\b(certified|certification|certificate)\b", title, re.I):
            return False
        return True

    # If it's short and has no keywords, it's probably noise
    if len(title) < 4:
        return False

    return True

def validate_education_entry(edu: Dict) -> bool:
    """Check if an education entry has minimum required data."""
    if not isinstance(edu, dict):
        return False
    degree = _norm(edu.get("degree"))
    institution = _norm(edu.get("institution"))

    if len(degree) <= 2 and len(institution) <= 2:
        return False

    # Require both a plausible degree and institution for an entry to be considered "good".
    # BUT: Be slightly liberal with common degrees like BSc
    if not _looks_like_degree(degree) and len(degree) > 10:
        return False
    if not _looks_like_institution(institution) and len(institution) > 10:
        return False

    return True

def parse_experience_fallback(text: str, existing: List[Dict]) -> List[Dict]:
    """Extract experience using regex when structured extraction fails."""
    # Run fallback if existing data is sparse (e.g. only 1 entry found) or missing
    if existing and len([e for e in existing if validate_experience_entry(e)]) >= 3:
        return existing
    
    logger.info(f"Running regex fallback for experience (currently {len(existing or [])} entries)...")
    
    patterns = [
        # "Software Engineer at Google" pattern
        r'(?P<title>(?:Senior|Lead|Principal|Junior|Graduate)?\s*[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\s+(?:at|@|,)\s+(?P<company>[A-Z][a-zA-Z\s&\-\.]+?)(?=\s|\.|$|,|\n)',
        
        # "Company, Location — Title" pattern (handles CV format like "Amazon Web Services (AWS), Cape Town — Data Analyst")
        r'(?P<company>[A-Z][a-zA-Z\s&\-\.\(\)]+?)\s*,\s*[A-Z][a-zA-Z\s]+?\s+[-–—]\s+(?P<title>(?:Senior|Lead|Principal|Junior|Graduate)?\s*[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)',
        
        # "Company — Title" pattern (without location)
        r'(?P<company>[A-Z][a-zA-Z\s&\-\.]+?)\s+[-–—]\s+(?P<title>(?:Senior|Lead|Principal|Junior|Graduate)?\s*[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)',
        
        # "Software Engineer, Google (2020-2023)" pattern
        r'(?P<title>[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\s*,\s*(?P<company>[A-Z][a-zA-Z\s&\-\.]+?)\s*(?:\(|\[)',
        
        # Generic title + generic company separator
        r'(?P<title>[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\s+(?:at|@|,)\s+(?P<company>[A-Z][a-zA-Z\s&]+?)(?=\s|\.|$|,|\n)',
        # "Company – Title"
        r'(?P<company>[A-Z][a-zA-Z\s&]+?)\s+[–-]\s+(?P<title>[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)',
        # "Title, Company" with comma
        r'(?P<title>[A-Za-z\s]+?),\s+(?P<company>[A-Z][a-zA-Z\s&]+)',
    ]
    
    new_entries = []
    for pattern in patterns:
        for match in re.finditer(pattern, text, re.IGNORECASE):
            title = match.groupdict().get("title", "").strip()
            company = match.groupdict().get("company", "").strip()
            
            if title and company:
                # Validate entry quality and filter out certs/junk
                candidate = {"title": title, "company": company}
                if not validate_experience_entry(candidate):
                    continue
                    
                # Avoid duplicates
                if not any(e.get("title") == title and e.get("company") == company for e in new_entries + (existing or [])):
                    new_entries.append({
                        "title": title, 
                        "company": company, 
                        "start_date": None, 
                        "end_date": None,
                        "description": None,
                        "confidence": 0.9
                    })
    
    return (existing or []) + new_entries if new_entries else (existing or [])

def parse_education_fallback(text: str, existing: List[Dict]) -> List[Dict]:
    """Extract education using regex."""
    # Run fallback if existing data is sparse (e.g. only 1 entry found) or missing
    if existing and len([e for e in existing if validate_education_entry(e)]) >= 2:
        return existing
    
    logger.info(f"Running regex fallback for education (currently {len(existing or [])} entries)...")
    
    patterns = [
        # Improved degree-first: "Bachelor of Science in Data Science, University of Cape Town"
        # Split into (Degree) (Field) (Institution)
        r'(?P<degree>(?:Bachelor|Master|Doctorate|B\.?Sc\.?|B\.?A\.?|M\.?Sc\.?|M\.?A\.?|PhD|Diploma|Certificate)(?:\s+of\s+[A-Za-z]+)?)\s+(?:in|of)\s+(?P<field>[A-Za-z\s]+?)(?:\s+from\s+|\s*,\s*|\s+at\s+)(?P<institution>[A-Z][a-zA-Z\s&\-\.\']+?(?:University|College|Institute|School|Academy))',
        
        # Standard: "Bachelor of Science, University of Cape Town"
        r'(?P<degree>(?:Bachelor|Master|Doctorate|B\.?Sc\.?|B\.?A\.?|M\.?Sc\.?|M\.?A\.?|PhD|Diploma|Certificate)[^\n,]+?)(?:\s+from\s+|\s*,\s*|\s+at\s+)(?P<institution>[A-Z][a-zA-Z\s&\-\.\']+?(?:University|College|Institute|School|Academy))',
        
        # Institution-first: "University of Cape Town, Bachelor of Science"
        r'(?P<institution>[A-Z][a-zA-Z\s&\-\.\']+?(?:University|College|Institute|School|Academy))\s*[,:\n]\s*(?P<degree>(?:Bachelor|Master|Doctorate|B\.?Sc\.?|B\.?A\.?|M\.?Sc\.?|M\.?A\.?|PhD|Diploma|Certificate)[^\n]*)',
    ]
    
    new_entries = []
    for pattern in patterns:
        for match in re.finditer(pattern, text, re.IGNORECASE):
            degree = match.groupdict().get("degree", "").strip()
            institution = match.groupdict().get("institution", "").strip()
            field = match.groupdict().get("field", "").strip() or None
            
            if degree and institution:
                if not any(e.get("degree") == degree and e.get("institution") == institution for e in new_entries + (existing or [])):
                    new_entries.append({
                        "degree": degree, 
                        "institution": institution, 
                        "field": field,
                        "year": None,
                        "confidence": 0.9
                    })
    
    return (existing or []) + new_entries if new_entries else (existing or [])
