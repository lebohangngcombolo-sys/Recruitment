import logging
from dataclasses import dataclass
from typing import Any, Dict, List, Optional

from app.services.cv_pattern_matcher import CVPatternMatcher

logger = logging.getLogger(__name__)


@dataclass
class OrchestratorOutput:
    structured_data: Dict[str, Any]
    confidence_scores: Dict[str, Any]
    warnings: List[str]
    suggestions: List[str]


class CVExtractionOrchestrator:
    def __init__(self):
        self.matcher = CVPatternMatcher()

    def extract(self, raw_text: str, extraction_metadata: Optional[Dict[str, Any]] = None) -> OrchestratorOutput:
        text = raw_text or ""
        extraction_metadata = extraction_metadata or {}

        structured = self._build_structured_data(text)
        confidence = self._calculate_confidence_scores(structured, extraction_metadata)
        warnings = self._generate_warnings(structured, confidence, extraction_metadata)
        suggestions = self._generate_suggestions(structured, confidence)

        return OrchestratorOutput(
            structured_data=structured,
            confidence_scores=confidence,
            warnings=warnings,
            suggestions=suggestions,
        )

    def _build_structured_data(self, text: str) -> Dict[str, Any]:
        flat = self.matcher.extract_all(text)

        # Keep BOTH:
        # - flat keys for backward compatibility / easy Flutter binding
        # - nested groups for review UI
        structured: Dict[str, Any] = {
            **flat,
            "personal_details": {
                "full_name": flat.get("full_name", ""),
                "email": flat.get("email", ""),
                "phone": flat.get("phone", ""),
                "address": flat.get("address", ""),
                "dob": flat.get("dob", ""),
                "linkedin": flat.get("linkedin", ""),
                "github": flat.get("github", ""),
                "portfolio": flat.get("portfolio", ""),
            },
            "education_details": {
                "education": flat.get("education", []),
                "certifications": flat.get("certifications", []),
                "languages": flat.get("languages", []),
            },
            "professional_details": {
                "skills": flat.get("skills", []),
                "experience": flat.get("experience", ""),
                "position": flat.get("position", ""),
                "previous_companies": flat.get("previous_companies", []),
                "bio": flat.get("bio", ""),
            },
        }
        return structured

    def _calculate_confidence_scores(self, structured: Dict[str, Any], extraction_metadata: Dict[str, Any]) -> Dict[str, Any]:
        # Basic heuristic confidence. This is meant for UX hints.
        def _score_str(v: Any) -> float:
            s = (v or "").strip() if isinstance(v, str) else ""
            if not s:
                return 0.0
            if len(s) > 30:
                return 0.9
            return 0.6

        def _score_list(v: Any) -> float:
            if not isinstance(v, list) or not v:
                return 0.0
            if len(v) >= 5:
                return 0.9
            return 0.6

        scores = {
            "full_name": _score_str(structured.get("full_name")),
            "email": _score_str(structured.get("email")),
            "phone": _score_str(structured.get("phone")),
            "linkedin": _score_str(structured.get("linkedin")),
            "github": _score_str(structured.get("github")),
            "education": _score_list(structured.get("education")),
            "skills": _score_list(structured.get("skills")),
            "certifications": _score_list(structured.get("certifications")),
            "languages": _score_list(structured.get("languages")),
            "experience": _score_str(structured.get("experience")),
        }

        # Surface OCR confidence if available
        ocr_conf = extraction_metadata.get("confidence")
        if ocr_conf is not None:
            scores["ocr_confidence"] = ocr_conf

        return scores

    def _generate_warnings(self, structured: Dict[str, Any], confidence: Dict[str, Any], extraction_metadata: Dict[str, Any]) -> List[str]:
        warnings: List[str] = []
        if not (structured.get("full_name") or "").strip():
            warnings.append("Missing full name")
        if not (structured.get("email") or "").strip():
            warnings.append("Missing email")
        if not structured.get("skills"):
            warnings.append("Skills not detected")
        if not (structured.get("experience") or "").strip():
            warnings.append("Work experience not detected")

        ocr_conf = extraction_metadata.get("confidence")
        if isinstance(ocr_conf, (int, float)) and ocr_conf < 60:
            warnings.append("Low OCR confidence; extracted text may be incomplete")

        return warnings

    def _generate_suggestions(self, structured: Dict[str, Any], confidence: Dict[str, Any]) -> List[str]:
        suggestions: List[str] = []
        if not (structured.get("linkedin") or "").strip():
            suggestions.append("Add a LinkedIn URL")
        if not (structured.get("portfolio") or "").strip() and not (structured.get("github") or "").strip():
            suggestions.append("Add a portfolio or GitHub link")
        if not structured.get("certifications"):
            suggestions.append("Add certifications (if applicable)")
        return suggestions
