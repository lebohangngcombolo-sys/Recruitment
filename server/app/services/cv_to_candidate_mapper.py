# app/services/cv_to_candidate_mapper.py
"""
Maps CV extraction output (from CVPatternMatcher / CVExtractionOrchestrator / AIParser)
to Candidate and User schema so extracted information is stored in the right places.
Handles key renames (position -> title, experience -> work_experience) and type conversion.
"""
import logging
from typing import Any, Dict, List, Optional

logger = logging.getLogger(__name__)

# Candidate model scalar fields (from app.models.Candidate)
CANDIDATE_SIMPLE_FIELDS = {
    "full_name", "phone", "address", "dob", "gender", "bio", "title",
    "location", "nationality", "id_number", "linkedin", "github", "portfolio",
    "cover_letter", "cv_url", "cv_text",
}

# Candidate model JSON/list fields
CANDIDATE_JSON_FIELDS = {
    "education", "skills", "work_experience", "certifications", "languages", "documents", "profile",
}

# Keys that extraction may return (from CVPatternMatcher / orchestrator flat keys)
EXTRACTION_KEYS = {
    "full_name", "email", "phone", "address", "dob", "gender", "nationality", "id_number",
    "linkedin", "github", "portfolio", "education", "skills", "certifications", "languages",
    "experience", "position", "previous_companies", "bio",
}


def _ensure_list(value: Any, max_items: int = 50) -> List[Any]:
    """Normalize value to a list for JSON fields."""
    if value is None:
        return []
    if isinstance(value, list):
        return list(value)[:max_items]
    if isinstance(value, str) and value.strip():
        return [value.strip()]
    return []


def _experience_text_to_single_entry(
    raw_experience: str,
    position: str = "",
    previous_companies: Optional[List[str]] = None,
) -> List[Dict[str, Any]]:
    """
    Heuristic: turn raw experience string + position + companies into one or more
    work_experience entries. Caller can replace with AI-structured list if available.
    """
    work: List[Dict[str, Any]] = []
    raw = (raw_experience or "").strip()
    companies = _ensure_list(previous_companies, 10) if previous_companies else []

    if position or raw or companies:
        entry: Dict[str, Any] = {
            "title": (position or "").strip() or None,
            "company": companies[0] if companies else None,
            "companies": companies[:5],
            "duration": None,
            "description": raw[:2000] if raw else None,
        }
        # Prune None values for cleaner JSON
        entry = {k: v for k, v in entry.items() if v is not None}
        work.append(entry)
    return work


def map_extraction_to_candidate(
    extraction: Dict[str, Any],
    work_experience_structured: Optional[List[Dict[str, Any]]] = None,
) -> Dict[str, Any]:
    """
    Map extraction dict (flat keys from CVPatternMatcher / structured_data) to
    Candidate model field names and types. Use work_experience_structured when
    AI has already produced a list of work_experience entries; otherwise
    experience/position/previous_companies are converted heuristically.

    Returns a dict with only Candidate field names, ready for setattr(candidate, k, v).
    """
    if not extraction:
        return {}

    # Prefer nested groups if present (orchestrator output)
    flat = extraction
    if "personal_details" in extraction:
        flat = {**flat, **extraction["personal_details"]}
    if "professional_details" in extraction:
        flat = {**flat, **extraction["professional_details"]}
    if "education_details" in extraction:
        flat = {**flat, **extraction["education_details"]}

    out: Dict[str, Any] = {}

    # Scalar mappings with key renames
    if flat.get("full_name"):
        out["full_name"] = (flat["full_name"] if isinstance(flat["full_name"], str) else str(flat["full_name"])).strip()[:150]
    if flat.get("phone"):
        out["phone"] = (flat["phone"] if isinstance(flat["phone"], str) else str(flat["phone"])).strip()[:50]
    if flat.get("address"):
        out["address"] = (flat["address"] if isinstance(flat["address"], str) else str(flat["address"])).strip()[:250]
    if flat.get("dob"):
        out["dob"] = flat["dob"]  # Caller should parse to date if string
    if flat.get("gender"):
        out["gender"] = (flat["gender"] if isinstance(flat["gender"], str) else str(flat["gender"])).strip()[:50]
    if flat.get("bio"):
        out["bio"] = (flat["bio"] if isinstance(flat["bio"], str) else str(flat["bio"])).strip()[:5000]
    if flat.get("nationality"):
        out["nationality"] = (flat["nationality"] if isinstance(flat["nationality"], str) else str(flat["nationality"])).strip()[:100]
    if flat.get("id_number"):
        out["id_number"] = (flat["id_number"] if isinstance(flat["id_number"], str) else str(flat["id_number"])).strip()[:100]
    if flat.get("linkedin"):
        out["linkedin"] = (flat["linkedin"] if isinstance(flat["linkedin"], str) else str(flat["linkedin"])).strip()[:250]
    if flat.get("github"):
        out["github"] = (flat["github"] if isinstance(flat["github"], str) else str(flat["github"])).strip()[:250]
    if flat.get("portfolio"):
        out["portfolio"] = (flat["portfolio"] if isinstance(flat["portfolio"], str) else str(flat["portfolio"])).strip()[:500]

    # position -> title (Candidate uses title for job title)
    if flat.get("position"):
        out["title"] = (flat["position"] if isinstance(flat["position"], str) else str(flat["position"])).strip()[:100]
    elif flat.get("title"):
        out["title"] = (flat["title"] if isinstance(flat["title"], str) else str(flat["title"])).strip()[:100]

    # List fields (ensure list type)
    for key in ("education", "skills", "certifications", "languages"):
        if key in flat and flat[key] is not None:
            out[key] = _ensure_list(flat[key])

    # work_experience: use AI-structured list if provided, else heuristic from experience/position/previous_companies
    if work_experience_structured and isinstance(work_experience_structured, list):
        out["work_experience"] = work_experience_structured[:30]
    else:
        raw_exp = flat.get("experience") or ""
        pos = flat.get("position") or ""
        companies = flat.get("previous_companies")
        out["work_experience"] = _experience_text_to_single_entry(raw_exp, pos, companies)

    return out


def extraction_user_fields(extraction: Dict[str, Any]) -> Dict[str, Any]:
    """
    Extract fields that belong on User (e.g. email for display, full_name in profile).
    Returns dict with keys that the auth/user update logic expects (e.g. profile.full_name, email).
    """
    flat = extraction
    if "personal_details" in extraction:
        flat = {**flat, **extraction["personal_details"]}
    out: Dict[str, Any] = {}
    if flat.get("full_name"):
        name = (flat["full_name"] if isinstance(flat["full_name"], str) else str(flat["full_name"])).strip()
        if name:
            out["full_name"] = name
    if flat.get("email"):
        out["email"] = (flat["email"] if isinstance(flat["email"], str) else str(flat["email"])).strip()
    return out
