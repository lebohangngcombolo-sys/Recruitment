"""
Data mapping between application models and Recruitee API format.
"""
from __future__ import annotations

from typing import Any, Dict, Optional
from datetime import datetime


def requisition_to_offer(requisition: Any, previous_data: Optional[Dict] = None) -> Dict[str, Any]:
    """Convert a Requisition model to Recruitee offer format
    
    Args:
        requisition: SQLAlchemy Requisition model instance
        previous_data: Optional dict of previously synced data. If provided,
                      only changed fields will be included (partial update).
        
    Returns:
        Dict formatted for Recruitee API
    """
    # Map status: active → published, inactive → closed
    status_map = {
        True: "published",
        False: "closed"
    }
    
    # Map employment type to Recruitee format
    # Valid values often vary but common ones are: full-time, part-time, contract, internship, freelance
    employment_map = {
        "full_time": "fulltime_permanent",
        "full-time": "fulltime_permanent",
        "full": "fulltime_permanent",
        "fulltime_permanent": "fulltime_permanent",
        "full time": "fulltime_permanent",
        "part_time": "part_time",
        "part-time": "part_time",
        "contract": "contract",
        "internship": "internship",
        "temporary": "temporary",
        "freelance": "freelance",
    }
    
    # Build current data
    current_data = {
        "title": requisition.title,
        "status": status_map.get(requisition.is_active, "published"),
        "external_id": str(requisition.id),
        "kind": "job",
    }
    
    # Add optional fields if they exist
    if requisition.description:
        current_data["description"] = requisition.description
    
    if requisition.location:
        current_data["location"] = requisition.location
    
    # Department mapping (based on account inspection)
    dept_map = {
        "engineering": 490849,
        "marketing": 490848,
        "sales": 490850,
        "human_resources": 490851,
        "hr": 490851,
    }
    
    if requisition.category:
        norm_cat = requisition.category.lower().replace(" ", "_")
        if norm_cat in dept_map:
            current_data["department_id"] = dept_map[norm_cat]
        else:
            current_data["department"] = requisition.category
    
    # NEW: Mandatory Location and Work Model fields for Job Sync
    # Using 'Amsterdam' (ID: 278139) as the default active location from inspection
    current_data["location_ids"] = [278139]
    
    # Work Model assignment (Defaulting to on-site for now)
    current_data["work_model"] = "on_site"
    current_data["remote"] = False
    current_data["hybrid"] = False
    current_data["on_site"] = True
    
    # Employment type mapping to Recruitee format
    # Valid values: "full", "part", "contract", "temporary", "internship", "freelance"
    if requisition.employment_type:
        normalized = requisition.employment_type.lower().replace(" ", "_").replace("-", "_")
        mapped_employment = employment_map.get(normalized, "fulltime_permanent")
        current_data["employment_type"] = mapped_employment
    
    # Salary as structured object (Recruitee API format)
    if requisition.salary_min or requisition.salary_max:
        current_data["salary"] = {
            "min": requisition.salary_min,
            "max": requisition.salary_max,
            "currency": requisition.salary_currency or "ZAR",
            "period": "month"  # singular "month" for Recruitee API
        }
    
    # Add qualifications/requirements to description
    
    # Add qualifications/requirements as HTML in description
    if requisition.qualifications:
        qual_html = "<br><br><strong>Qualifications:</strong><ul>" + "".join(
            f"<li>{q}</li>" for q in requisition.qualifications
        ) + "</ul>"
        current_data["description"] = (current_data.get("description") or "") + qual_html
    
    # Add required skills as HTML
    if requisition.required_skills:
        skills_html = "<br><br><strong>Required Skills:</strong><ul>" + "".join(
            f"<li>{s}</li>" for s in requisition.required_skills
        ) + "</ul>"
        current_data["description"] = (current_data.get("description") or "") + skills_html
    
    # If previous data provided, compute diff for partial update
    if previous_data:
        changed_fields = {}
        for key, value in current_data.items():
            if previous_data.get(key) != value:
                changed_fields[key] = value
        
        # Always include required fields even if unchanged
        required_fields = ['title', 'status', 'external_id']
        for field in required_fields:
            if field not in changed_fields and field in current_data:
                changed_fields[field] = current_data[field]
        
        # If no changes detected, return empty dict (skip update)
        if len(changed_fields) <= len(required_fields):
            return {}  # Signal that no update needed
        
        return changed_fields
    
    return current_data


def offer_to_requisition(offer: Dict[str, Any], 
                         existing: Optional[Any] = None) -> Any:
    """Convert a Recruitee offer to Requisition model data
    
    Args:
        offer: Recruitee offer dict
        existing: Optional existing Requisition model to update
        
    Returns:
        Requisition model instance (new or updated)
    """
    # Import here to avoid circular dependencies
    from app.models import Requisition
    
    if existing:
        req = existing
    else:
        req = Requisition()
    
    offer_data = offer.get("offer", offer)
    
    req.title = offer_data.get("title", req.title if existing else "")
    req.description = offer_data.get("description", req.description if existing else "")
    req.location = offer_data.get("location", req.location if existing else "")
    req.category = offer_data.get("department", req.category if existing else "")
    req.recruitee_id = str(offer_data.get("id"))
    
    # Map status back
    status = offer_data.get("status", "published")
    req.is_active = status == "published"
    
    # Map employment type (Recruitee returns: full_time, part_time, etc.)
    emp_type = offer_data.get("employment_type", "fulltime_permanent")
    employment_map = {
        "full": "full_time",
        "full-time": "full_time",
        "full_time": "full_time",
        "fulltime_permanent": "full_time",
        "part": "part_time",
        "part-time": "part_time",
        "part_time": "part_time",
        "contract": "contract",
        "internship": "internship",
        "temporary": "temporary",
        "freelance": "freelance"
    }
    req.employment_type = employment_map.get(emp_type.lower(), "full_time")
    
    return req


def candidate_to_recruitee(candidate: Any, 
                           application: Optional[Any] = None,
                           requisition: Optional[Any] = None) -> Dict[str, Any]:
    """Convert a Candidate model to Recruitee candidate format
    
    Args:
        candidate: SQLAlchemy Candidate model instance
        application: Optional Application model (for job placement)
        requisition: Optional Requisition model (for job placement)
        
    Returns:
        Dict formatted for Recruitee API
    """
    candidate_data = {
        "name": candidate.full_name,
        "email": candidate.email,
        "external_id": str(candidate.id),
        "source": "khono_recruite",  # Track where candidate came from
    }
    
    # Add optional fields
    if candidate.phone:
        candidate_data["phone"] = candidate.phone
    
    if candidate.cv_url:
        candidate_data["cv_url"] = candidate.cv_url
    
    # Add placement to specific offer if provided
    if requisition and requisition.recruitee_id:
        candidate_data["placements"] = [
            {"offer_id": requisition.recruitee_id}
        ]
    elif application and hasattr(application, 'requisition') and application.requisition:
        if application.requisition.recruitee_id:
            candidate_data["placements"] = [
                {"offer_id": application.requisition.recruitee_id}
            ]
    
    # Add LinkedIn if available
    if candidate.linkedin:
        candidate_data["links"] = [{"url": candidate.linkedin}]
    
    # Add notes with additional info
    notes_parts = []
    if candidate.bio:
        notes_parts.append(f"Bio: {candidate.bio}")
    if candidate.nationality:
        notes_parts.append(f"Nationality: {candidate.nationality}")
    if candidate.title:
        notes_parts.append(f"Title: {candidate.title}")
    
    if notes_parts:
        candidate_data["notes"] = "\n".join(notes_parts)
    
    return candidate_data


def recruitee_candidate_to_local(candidate_data: Dict[str, Any],
                                 existing: Optional[Any] = None) -> Any:
    """Convert a Recruitee candidate to local Candidate model
    
    Args:
        candidate_data: Recruitee candidate dict
        existing: Optional existing Candidate model to update
        
    Returns:
        Candidate model instance (new or updated)
    """
    from app.models import Candidate
    
    if existing:
        cand = existing
    else:
        cand = Candidate()
    
    # Handle nested structure
    if "candidate" in candidate_data:
        candidate_data = candidate_data["candidate"]
    
    cand.full_name = candidate_data.get("name", cand.full_name if existing else "")
    cand.email = candidate_data.get("email", cand.email if existing else "")
    cand.phone = candidate_data.get("phone", cand.phone if existing else "")
    cand.recruitee_id = str(candidate_data.get("id", ""))
    
    # Extract CV URL if available
    cv_file = candidate_data.get("cv_file")
    if cv_file:
        cand.cv_url = cv_file.get("url", cand.cv_url if existing else "")
    
    # Extract LinkedIn from links
    links = candidate_data.get("links", [])
    for link in links:
        url = link.get("url", "")
        if "linkedin" in url.lower():
            cand.linkedin = url
            break
    
    # Parse notes for additional fields
    notes = candidate_data.get("notes", "")
    if notes and not existing:
        for line in notes.split("\n"):
            if line.startswith("Bio: "):
                cand.bio = line[5:]
            elif line.startswith("Nationality: "):
                cand.nationality = line[13:]
            elif line.startswith("Title: "):
                cand.title = line[7:]
    
    return cand


def map_application_status_to_recruitee(status: str) -> str:
    """Map internal application status to Recruitee placement status"""
    status_map = {
        "applied": "new",
        "screening": "in_review",
        "shortlisted": "qualified",
        "interview": "interview",
        "offer": "offer",
        "hired": "hired",
        "rejected": "disqualified",
        "withdrawn": "withdrawn",
    }
    return status_map.get(status.lower(), "new")


def map_recruitee_status_to_application(status: str) -> str:
    """Map Recruitee placement status to internal application status"""
    status_map = {
        "new": "applied",
        "in_review": "screening",
        "qualified": "shortlisted",
        "interview": "interview",
        "offer": "offer",
        "hired": "hired",
        "disqualified": "rejected",
        "withdrawn": "withdrawn",
    }
    return status_map.get(status.lower(), "applied")
