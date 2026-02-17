# app/services/cv_extraction_orchestrator.py
"""
Orchestrates CV text extraction into structured data for prepopulation and review.
Used by Celery CV analysis task to produce structured_data, confidence_scores, warnings, suggestions.
"""
import logging
from typing import Any, Dict, List

from app.services.cv_pattern_matcher import CVPatternMatcher

logger = logging.getLogger(__name__)


class ExtractionResult:
    """Result of CV extraction for use by cv_tasks."""

    __slots__ = ("structured_data", "confidence_scores", "warnings", "suggestions")

    def __init__(
        self,
        structured_data: Dict[str, Any],
        confidence_scores: Dict[str, float],
        warnings: List[str],
        suggestions: List[str],
    ):
        self.structured_data = structured_data or {}
        self.confidence_scores = confidence_scores or {}
        self.warnings = warnings or []
        self.suggestions = suggestions or []


class CVExtractionOrchestrator:
    """Extracts structured data from resume text for CV analysis and prepopulation."""

    def __init__(self):
        self.matcher = CVPatternMatcher()

    def extract(
        self,
        resume_text: str,
        extraction_metadata: Dict[str, Any] | None = None,
    ) -> ExtractionResult:
        """
        Extract structured data from resume text. Optionally merge with extraction_metadata
        (e.g. from upload-time extraction). Returns an ExtractionResult with structured_data,
        confidence_scores, warnings, and suggestions.
        """
        text = (resume_text or "").strip()
        extraction_metadata = extraction_metadata or {}

        try:
            flat = self.matcher.extract_all(text, metadata=extraction_metadata)
        except Exception as e:
            logger.warning("CVExtractionOrchestrator matcher failed: %s", e)
            flat = {}

        # Merge with any pre-existing extraction_metadata (e.g. from AI/upload)
        structured_data = {**flat, **extraction_metadata}

        # Simple confidence: presence of key fields
        confidence_scores = self._confidence_scores(structured_data)

        # Warnings and suggestions
        warnings = self._collect_warnings(structured_data, text)
        suggestions = self._collect_suggestions(structured_data, text)

        return ExtractionResult(
            structured_data=structured_data,
            confidence_scores=confidence_scores,
            warnings=warnings,
            suggestions=suggestions,
        )

    def _confidence_scores(self, data: Dict[str, Any]) -> Dict[str, float]:
        """Derive confidence scores from extracted fields."""
        scores = {}
        key_fields = [
            "full_name", "email", "phone", "skills", "experience",
            "education", "linkedin", "github",
        ]
        for k in key_fields:
            v = data.get(k)
            if v is None:
                scores[k] = 0.0
            elif isinstance(v, (list, dict)) and len(v) == 0:
                scores[k] = 0.0
            elif isinstance(v, str) and not v.strip():
                scores[k] = 0.0
            else:
                scores[k] = 1.0
        return scores

    def _collect_warnings(self, data: Dict[str, Any], text: str) -> List[str]:
        """Collect warnings (e.g. missing or weak sections)."""
        warnings = []
        if not (data.get("email") or "").strip():
            warnings.append("No email found.")
        if not (data.get("phone") or "").strip():
            warnings.append("No phone number found.")
        if not (data.get("skills") or (isinstance(data.get("skills"), list) and not data["skills"])):
            warnings.append("No skills section detected.")
        return warnings

    def _collect_suggestions(self, data: Dict[str, Any], text: str) -> List[str]:
        """Collect suggestions for improving the CV."""
        suggestions = []
        if not data.get("linkedin"):
            suggestions.append("Consider adding a LinkedIn profile URL.")
        if not data.get("experience") and not data.get("education"):
            suggestions.append("Add experience or education sections for better matching.")
        return suggestions
