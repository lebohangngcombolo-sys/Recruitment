# app/services/cv_extraction_orchestrator.py
"""
Orchestrates CV text extraction into structured data for prepopulation/review UI.
Can be extended to use AI or pattern matching; currently passes through
extraction_metadata or returns empty structure.
"""
from typing import Any, Dict, List, Optional


class ExtractionResult:
    """Result of CV extraction with structured_data, confidence_scores, warnings, suggestions."""

    __slots__ = ("structured_data", "confidence_scores", "warnings", "suggestions")

    def __init__(
        self,
        structured_data: Optional[Dict[str, Any]] = None,
        confidence_scores: Optional[Dict[str, Any]] = None,
        warnings: Optional[List[str]] = None,
        suggestions: Optional[List[str]] = None,
    ):
        self.structured_data = structured_data or {}
        self.confidence_scores = confidence_scores or {}
        self.warnings = warnings or []
        self.suggestions = suggestions or []


class CVExtractionOrchestrator:
    """Builds structured extraction output from resume text and optional metadata."""

    def extract(
        self,
        resume_text: str,
        extraction_metadata: Optional[Dict[str, Any]] = None,
    ) -> ExtractionResult:
        extraction_metadata = extraction_metadata or {}
        return ExtractionResult(
            structured_data=extraction_metadata.get("structured_data") or {},
            confidence_scores=extraction_metadata.get("confidence_scores") or {},
            warnings=extraction_metadata.get("warnings") or [],
            suggestions=extraction_metadata.get("suggestions") or [],
        )
