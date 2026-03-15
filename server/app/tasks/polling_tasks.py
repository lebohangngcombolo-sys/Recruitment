from celery_worker import celery
from app import create_app, db
from app.models import CVAnalysis
from app.services.analysis_service_client import AnalysisServiceClient
from app.services.data_merger import DataMerger
from datetime import datetime
import logging

logger = logging.getLogger(__name__)

@celery.task(bind=True, max_retries=3, default_retry_delay=60)
def poll_cv_analysis_results(self):
    """Poll for pending CV analysis results from external service."""
    app = create_app()
    with app.app_context():
        # Get pending analyses with external IDs
        pending_analyses = CVAnalysis.query.filter(
            CVAnalysis.status.in_(['submitted', 'processing']),
            CVAnalysis.external_analysis_id.isnot(None)
        ).limit(50).all()
        
        for cv_analysis in pending_analyses:
            try:
                # Check status
                status_result = AnalysisServiceClient.get_analysis_status(cv_analysis.external_analysis_id)
                external_status = status_result.get('status')
                
                if external_status == 'completed':
                    # Fetch full result
                    result = AnalysisServiceClient.get_analysis_result(cv_analysis.external_analysis_id)
                    DataMerger.update_local_database(cv_analysis.id, result)
                    logger.info(f"Updated CV analysis {cv_analysis.id} with external result")
                    
                elif external_status == 'failed':
                    cv_analysis.status = 'failed'
                    cv_analysis.result = {"error": status_result.get('error', 'External analysis failed')}
                    cv_analysis.finished_at = datetime.utcnow()
                    db.session.commit()
                    logger.warning(f"External analysis failed for CV analysis {cv_analysis.id}")
                    
                elif external_status in ['submitted', 'processing']:
                    cv_analysis.status = external_status
                    db.session.commit()
                    
            except Exception as exc:
                logger.error(f"Error polling CV analysis {cv_analysis.id}: {str(exc)}")
                # Continue with next analysis
                
        return f"Polled {len(pending_analyses)} analyses"
