import requests
from flask import current_app
import logging
from datetime import datetime, timedelta
from app import db
from app.models import CVAnalysis
from app.services.data_merger import DataMerger

logger = logging.getLogger(__name__)

class AnalysisServiceClient:
    """Client for communicating with the external FastAPI CV analysis service."""

    @staticmethod
    def _base_url() -> str:
        return (current_app.config.get("ANALYSIS_SERVICE_URL") or "").rstrip("/")

    @staticmethod
    def _auth_headers() -> dict:
        api_key = current_app.config.get("ANALYSIS_SERVICE_API_KEY")
        if api_key:
            return {"Authorization": f"Bearer {api_key}"}
        return {}

    @staticmethod
    def _join(base: str, path: str) -> str:
        base = (base or "").rstrip("/")
        path = (path or "").lstrip("/")
        return f"{base}/{path}" if base else f"/{path}"
    
    @staticmethod
    def submit_cv_text(cv_text: str, job_description: str | None = None):
        """Submit extracted CV text to external analysis service.

        Contract (new decoupled analyser):
        POST /analyze (JSON)
          {"cv_text": "...", "job_description": "..."}

        Returns JSON like: {"analysis_id": "...", "status": "pending"}
        """
        url = AnalysisServiceClient._join(AnalysisServiceClient._base_url(), "analyze")
        headers = {**AnalysisServiceClient._auth_headers()}
        payload = {"cv_text": cv_text or ""}
        if job_description:
            payload["job_description"] = job_description

        try:
            response = requests.post(url, headers=headers, json=payload, timeout=30)
            if response.status_code != 202:
                logger.error(
                    "Unexpected analysis service response: status=%s body=%s",
                    response.status_code,
                    response.text,
                )
                response.raise_for_status()
            return response.json() if response.content else {}
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to submit CV text to analysis service: {e}")
            raise
    
    @staticmethod
    def get_analysis_status(external_analysis_id: str):
        """Get analysis status from external service."""
        url = AnalysisServiceClient._join(
            AnalysisServiceClient._base_url(),
            f"analyses/{external_analysis_id}/status",
        )
        headers = {**AnalysisServiceClient._auth_headers()}
        
        try:
            response = requests.get(url, headers=headers, timeout=10)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to get analysis status for {external_analysis_id}: {e}")
            raise
    
    @staticmethod
    def get_analysis_result(external_analysis_id: str):
        """Get analysis result from external service."""
        url = AnalysisServiceClient._join(
            AnalysisServiceClient._base_url(),
            f"analyses/{external_analysis_id}/result",
        )
        headers = {**AnalysisServiceClient._auth_headers()}
        
        try:
            response = requests.get(url, headers=headers, timeout=30)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to get analysis result for {external_analysis_id}: {e}")
            raise

    @staticmethod
    def refresh_if_needed(cv_analysis: CVAnalysis, max_age_seconds: int = 15):
        """Refresh analysis status/result from external service if needed (lazy polling).

        Args:
            cv_analysis: CVAnalysis record
            max_age_seconds: minimum age before we re-check (avoid too frequent checks)

        Returns:
            True if we attempted a refresh (regardless of success), False if skipped.
        """
        if not cv_analysis.external_analysis_id:
            return False
        if cv_analysis.status in ('completed', 'failed'):
            return False
        # Rate limit: only re-check if last update was > max_age_seconds ago
        if cv_analysis.updated_at and (datetime.utcnow() - cv_analysis.updated_at) < timedelta(seconds=max_age_seconds):
            return False

        try:
            status_result = AnalysisServiceClient.get_analysis_status(cv_analysis.external_analysis_id)
            external_status = status_result.get('status')
            if external_status == 'completed':
                result = AnalysisServiceClient.get_analysis_result(cv_analysis.external_analysis_id)
                DataMerger.update_local_database(cv_analysis.id, result)
                logger.info(f"Lazy refresh completed CV analysis {cv_analysis.id}")
            elif external_status == 'failed':
                cv_analysis.status = 'failed'
                cv_analysis.result = {"error": status_result.get('error', 'External analysis failed')}
                cv_analysis.finished_at = datetime.utcnow()
                db.session.add(cv_analysis)
                db.session.commit()
                logger.warning(f"Lazy refresh marked CV analysis {cv_analysis.id} as failed")
            elif external_status in ('submitted', 'processing'):
                # Update timestamp to avoid rapid rechecks
                cv_analysis.updated_at = datetime.utcnow()
                db.session.add(cv_analysis)
                db.session.commit()
            return True
        except Exception as exc:
            logger.error(f"Lazy refresh failed for CV analysis {cv_analysis.id}: {str(exc)}")
            # Do not raise; allow caller to continue with stale data
            return False
