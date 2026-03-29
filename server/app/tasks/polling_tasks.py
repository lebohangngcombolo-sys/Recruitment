from celery_worker import celery
from app import create_app, db
from app.models import CVAnalysis, Candidate
from app.services.analysis_service_client import AnalysisServiceClient
from app.services.data_merger import DataMerger
from app.services.cv_promotion_service import CVPromotionService
from app.services.cv_cleanup_service import CVCleanupService
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)


@celery.task(bind=True, max_retries=3, default_retry_delay=60)
def poll_cv_analysis_results(self):
    """
    Enhanced polling task for pending CV analysis results.
    
    This task:
    1. Checks pending analyses from external service
    2. Updates CVAnalysis status
    3. Auto-promotes completed results to candidate profile
    4. Syncs candidate.cv_analysis_status
    """
    app = create_app()
    with app.app_context():
        # Get pending analyses with external IDs
        pending_analyses = CVAnalysis.query.filter(
            CVAnalysis.status.in_(['submitted', 'processing']),
            CVAnalysis.external_analysis_id.isnot(None)
        ).limit(50).all()
        
        promoted_count = 0
        failed_count = 0
        updated_count = 0
        
        for cv_analysis in pending_analyses:
            try:
                # Check status
                status_result = AnalysisServiceClient.get_analysis_status(cv_analysis.external_analysis_id)
                external_status = status_result.get('status')
                
                if external_status == 'completed':
                    # Fetch full result
                    result = AnalysisServiceClient.get_analysis_result(cv_analysis.external_analysis_id)
                    
                    # Update local database via DataMerger
                    DataMerger.update_local_database(cv_analysis.id, result)
                    
                    # Auto-promote to candidate profile
                    promotion_result = CVPromotionService.promote_analysis_to_candidate(
                        cv_analysis.candidate_id, cv_analysis.id
                    )
                    
                    if promotion_result['success']:
                        promoted_count += 1
                        logger.info(
                            f"Auto-promoted CV analysis {cv_analysis.id} "
                            f"to candidate {cv_analysis.candidate_id}"
                        )
                    else:
                        logger.warning(
                            f"Auto-promotion failed for analysis {cv_analysis.id}: "
                            f"{promotion_result.get('error')}"
                        )
                    
                    updated_count += 1
                    
                elif external_status == 'failed':
                    cv_analysis.status = 'failed'
                    cv_analysis.result = {"error": status_result.get('error', 'External analysis failed')}
                    cv_analysis.finished_at = datetime.utcnow()
                    
                    # Update candidate status as well
                    candidate = Candidate.query.get(cv_analysis.candidate_id)
                    if candidate:
                        candidate.cv_analysis_status = 'failed'
                        db.session.add(candidate)
                    
                    db.session.add(cv_analysis)
                    db.session.commit()
                    
                    failed_count += 1
                    logger.warning(f"External analysis failed for CV analysis {cv_analysis.id}")
                    
                elif external_status in ['submitted', 'processing']:
                    cv_analysis.status = external_status
                    cv_analysis.updated_at = datetime.utcnow()
                    
                    # Update candidate status
                    candidate = Candidate.query.get(cv_analysis.candidate_id)
                    if candidate and candidate.cv_analysis_status != external_status:
                        candidate.cv_analysis_status = external_status
                        db.session.add(candidate)
                    
                    db.session.add(cv_analysis)
                    db.session.commit()
                    updated_count += 1
                    
            except Exception as exc:
                logger.error(f"Error polling CV analysis {cv_analysis.id}: {str(exc)}")
                # Continue with next analysis
                
        logger.info(
            f"Poll completed: {len(pending_analyses)} pending, "
            f"{promoted_count} promoted, {failed_count} failed, {updated_count} updated"
        )
        
        return {
            "polled": len(pending_analyses),
            "promoted": promoted_count,
            "failed": failed_count,
            "updated": updated_count
        }


@celery.task
def cleanup_old_cv_analyses():
    """
    Daily cleanup task for old promoted CV analyses.
    
    Removes old external analysis records after successful promotion.
    Runs during low-traffic hours.
    """
    app = create_app()
    with app.app_context():
        try:
            logger.info("Starting CV analysis cleanup task")
            
            stats = CVCleanupService.cleanup_promoted_analyses(
                older_than_days=CVCleanupService.DEFAULT_CLEANUP_DAYS
            )
            
            logger.info(
                f"Cleanup completed: {stats['external_deleted']} external analyses deleted, "
                f"{stats['errors']} errors"
            )
            
            return stats
            
        except Exception as e:
            logger.exception("Cleanup task failed")
            return {"error": str(e)}


@celery.task
def sync_candidate_analysis_statuses():
    """
    Batch sync task to update candidate analysis statuses.
    
    Ensures all candidates have accurate cv_analysis_status based on
    their latest CVAnalysis record.
    """
    app = create_app()
    with app.app_context():
        try:
            logger.info("Starting candidate analysis status sync")
            
            # Find candidates with outdated status
            candidates = Candidate.query.filter(
                Candidate.last_cv_analysis_id.isnot(None),
                Candidate.cv_analysis_status.in_(['pending', 'processing', 'submitted'])
            ).limit(100).all()
            
            synced_count = 0
            
            for candidate in candidates:
                try:
                    # Check if analysis is actually completed
                    analysis = CVAnalysis.query.get(candidate.last_cv_analysis_id)
                    if analysis and analysis.status == 'completed':
                        # Sync status
                        updated = CVPromotionService.sync_analysis_status(candidate.id)
                        if updated:
                            synced_count += 1
                except Exception as e:
                    logger.error(f"Failed to sync candidate {candidate.id}: {e}")
                    continue
            
            logger.info(f"Status sync completed: {synced_count} candidates updated")
            return {"synced": synced_count}
            
        except Exception as e:
            logger.exception("Status sync task failed")
            return {"error": str(e)}


@celery.task
def get_cv_cleanup_statistics():
    """
    Get cleanup statistics for monitoring.
    
    Returns statistics about cleanup status for admin dashboards.
    """
    app = create_app()
    with app.app_context():
        try:
            stats = CVCleanupService.get_cleanup_statistics()
            return stats
        except Exception as e:
            logger.error(f"Failed to get cleanup stats: {e}")
            return {"error": str(e)}
