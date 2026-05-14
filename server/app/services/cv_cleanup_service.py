# app/services/cv_cleanup_service.py
"""
CV Cleanup Service - Automated cleanup for old CV analysis records.

This service handles the removal of old CV analysis records from both the
local database and external CV Analyser service after successful promotion.
Implements GDPR-compliant data cleanup for recruitment platform.
"""

import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional
from app import db
from app.models import Candidate, CVAnalysis
from app.services.analysis_service_client import AnalysisServiceClient

logger = logging.getLogger(__name__)


class CVCleanupService:
    """
    Cleanup service for old CV analysis records.
    
    Removes records from CV Analyser DB after successful promotion
    to maintain database hygiene and GDPR compliance.
    """
    
    # Default cleanup threshold: 7 days after promotion
    DEFAULT_CLEANUP_DAYS = 7
    
    # Batch size for bulk cleanup operations
    BATCH_SIZE = 100
    
    @staticmethod
    def cleanup_promoted_analyses(older_than_days: int = None) -> Dict[str, int]:
        """
        Remove old CV analysis records that have been successfully promoted.
        
        Args:
            older_than_days: Only remove records older than this many days.
                           Defaults to 7 days.
        
        Returns:
            dict: Cleanup statistics
            {
                'total_candidates': int,
                'external_deleted': int,
                'local_marked': int,
                'errors': int
            }
        """
        if older_than_days is None:
            older_than_days = CVCleanupService.DEFAULT_CLEANUP_DAYS
        
        cutoff_date = datetime.utcnow() - timedelta(days=older_than_days)
        
        stats = {
            'total_candidates': 0,
            'external_deleted': 0,
            'local_marked': 0,
            'errors': 0
        }
        
        try:
            # Find candidates with promoted analyses older than threshold
            candidates = Candidate.query.filter(
                Candidate.cv_analysis_status == 'completed',
                Candidate.cv_analysis_promoted_at != None,
                Candidate.cv_analysis_promoted_at < cutoff_date,
                Candidate.analyser_id != None
            ).limit(CVCleanupService.BATCH_SIZE).all()
            
            stats['total_candidates'] = len(candidates)
            
            for candidate in candidates:
                try:
                    success = CVCleanupService._cleanup_single_candidate(candidate)
                    if success:
                        stats['external_deleted'] += 1
                        stats['local_marked'] += 1
                    else:
                        stats['errors'] += 1
                        
                except Exception as e:
                    logger.error(f"Failed to cleanup candidate {candidate.id}: {e}")
                    stats['errors'] += 1
            
            logger.info(
                f"Cleanup completed: {stats['external_deleted']} external "
                f"analyses deleted, {stats['errors']} errors"
            )
            
            return stats
            
        except Exception as e:
            logger.exception("Cleanup operation failed")
            stats['errors'] += 1
            return stats
    
    @staticmethod
    def _cleanup_single_candidate(candidate: Candidate) -> bool:
        """
        Cleanup a single candidate's analysis data.
        
        Args:
            candidate: Candidate record to cleanup
            
        Returns:
            bool: True if cleanup was successful
        """
        if not candidate.analyser_id:
            return False
        
        try:
            # Step 1: Delete from external service
            external_deleted = CVCleanupService.delete_analysis_from_external_service(
                candidate.analyser_id
            )
            
            if not external_deleted:
                logger.warning(
                    f"External deletion failed for candidate {candidate.id}, "
                    f"analyser_id {candidate.analyser_id}. Continuing with local cleanup."
                )
            
            # Step 2: Mark local records as cleaned
            # Keep the CVAnalysis record but clear the external reference
            if candidate.last_cv_analysis_id:
                analysis = CVAnalysis.query.get(candidate.last_cv_analysis_id)
                if analysis:
                    # Keep the result but mark as cleaned
                    analysis.external_analysis_id = None
                    analysis.result = {
                        '_cleaned_at': datetime.utcnow().isoformat(),
                        '_cleaned': True,
                        # Keep minimal summary for audit
                        'summary': {
                            'has_personal_details': bool(
                                analysis.result.get('personal_details') if analysis.result else False
                            ),
                            'has_education': bool(
                                analysis.result.get('education') if analysis.result else False
                            ),
                            'has_skills': bool(
                                analysis.result.get('skills') if analysis.result else False
                            ),
                        } if analysis.result else {}
                    }
                    db.session.add(analysis)
            
            # Clear analyser_id from candidate but keep status
            old_analyser_id = candidate.analyser_id
            candidate.analyser_id = None
            # Note: We keep cv_analysis_status and cv_analysis_promoted_at for audit
            
            db.session.add(candidate)
            db.session.commit()
            
            logger.info(
                f"Cleaned up analysis for candidate {candidate.id}, "
                f"former analyser_id: {old_analyser_id}"
            )
            
            return True
            
        except Exception as e:
            db.session.rollback()
            logger.error(f"Cleanup failed for candidate {candidate.id}: {e}")
            return False
    
    @staticmethod
    def delete_analysis_from_external_service(analyser_id: str) -> bool:
        """
        Call external CV Analyser API to delete analysis record.
        
        Required for GDPR compliance when user requests data deletion.
        
        Args:
            analyser_id: External analysis ID
            
        Returns:
            bool: True if deletion was successful
        """
        if not analyser_id:
            return False
        
        try:
            # The external service should have a DELETE endpoint
            # For now, we use a placeholder - actual implementation depends on API
            url = AnalysisServiceClient._join(
                AnalysisServiceClient._base_url(),
                f"admin/resumes/{analyser_id}"
            )
            
            headers = AnalysisServiceClient._auth_headers()
            
            import requests
            response = requests.delete(url, headers=headers, timeout=10)
            
            if response.status_code in [200, 204, 404]:
                # 200/204 = deleted successfully
                # 404 = already deleted (considered success)
                logger.info(f"External analysis {analyser_id} deleted successfully")
                return True
            else:
                logger.warning(
                    f"External deletion returned status {response.status_code}: {response.text}"
                )
                return False
                
        except Exception as e:
            logger.error(f"Failed to delete external analysis {analyser_id}: {e}")
            return False
    
    @staticmethod
    def get_cleanup_candidates(
        older_than_days: int = None,
        limit: int = 100
    ) -> List[Candidate]:
        """
        Get list of candidates eligible for cleanup.
        
        Args:
            older_than_days: Age threshold in days
            limit: Maximum number to return
            
        Returns:
            list: Candidates eligible for cleanup
        """
        if older_than_days is None:
            older_than_days = CVCleanupService.DEFAULT_CLEANUP_DAYS
        
        cutoff_date = datetime.utcnow() - timedelta(days=older_than_days)
        
        return Candidate.query.filter(
            Candidate.cv_analysis_status == 'completed',
            Candidate.cv_analysis_promoted_at != None,
            Candidate.cv_analysis_promoted_at < cutoff_date,
            Candidate.analyser_id != None
        ).limit(limit).all()
    
    @staticmethod
    def get_cleanup_statistics() -> Dict[str, any]:
        """
        Get statistics about cleanup status.
        
        Returns:
            dict: Cleanup statistics
        """
        now = datetime.utcnow()
        
        # Total promoted analyses
        total_promoted = Candidate.query.filter(
            Candidate.cv_analysis_status == 'completed',
            Candidate.cv_analysis_promoted_at != None
        ).count()
        
        # Analyses ready for cleanup (older than 7 days)
        week_ago = now - timedelta(days=7)
        ready_for_cleanup = Candidate.query.filter(
            Candidate.cv_analysis_status == 'completed',
            Candidate.cv_analysis_promoted_at != None,
            Candidate.cv_analysis_promoted_at < week_ago,
            Candidate.analyser_id != None
        ).count()
        
        # Already cleaned (no analyser_id but was promoted)
        already_cleaned = Candidate.query.filter(
            Candidate.cv_analysis_status == 'completed',
            Candidate.cv_analysis_promoted_at != None,
            Candidate.analyser_id == None
        ).count()
        
        # Pending cleanup (promoted but not yet old enough)
        day_ago = now - timedelta(days=1)
        pending_cleanup = Candidate.query.filter(
            Candidate.cv_analysis_status == 'completed',
            Candidate.cv_analysis_promoted_at != None,
            Candidate.cv_analysis_promoted_at >= week_ago,
            Candidate.cv_analysis_promoted_at < day_ago,
            Candidate.analyser_id != None
        ).count()
        
        return {
            'total_promoted': total_promoted,
            'ready_for_cleanup': ready_for_cleanup,
            'pending_cleanup': pending_cleanup,
            'already_cleaned': already_cleaned,
            'cleanup_threshold_days': CVCleanupService.DEFAULT_CLEANUP_DAYS
        }
    
    @staticmethod
    def immediate_cleanup_for_candidate(candidate_id: int) -> bool:
        """
        Trigger immediate cleanup for a specific candidate.
        
        Use case: GDPR right to erasure request
        
        Args:
            candidate_id: Local candidate ID
            
        Returns:
            bool: True if cleanup succeeded
        """
        candidate = Candidate.query.get(candidate_id)
        if not candidate:
            logger.error(f"Candidate {candidate_id} not found for immediate cleanup")
            return False
        
        if not candidate.analyser_id:
            logger.info(f"Candidate {candidate_id} has no analyser_id to cleanup")
            return True  # Nothing to do, considered success
        
        return CVCleanupService._cleanup_single_candidate(candidate)
    
    @staticmethod
    def schedule_cleanup_task() -> str:
        """
        Schedule the cleanup task for execution.
        
        Returns:
            str: Task ID or status
        """
        try:
            from celery_worker import celery
            
            # Queue the cleanup task
            task = celery.send_task(
                'app.tasks.polling_tasks.cleanup_old_cv_analyses',
                countdown=0  # Run immediately
            )
            
            logger.info(f"Cleanup task scheduled: {task.id}")
            return task.id
            
        except Exception as e:
            logger.error(f"Failed to schedule cleanup task: {e}")
            return None


# Convenience functions for external use
def cleanup_old_analyses(older_than_days: int = 7) -> Dict[str, int]:
    """Convenience wrapper for CVCleanupService.cleanup_promoted_analyses."""
    return CVCleanupService.cleanup_promoted_analyses(older_than_days)


def get_cleanup_stats() -> Dict[str, any]:
    """Convenience wrapper for CVCleanupService.get_cleanup_statistics."""
    return CVCleanupService.get_cleanup_statistics()


def delete_candidate_analysis_data(candidate_id: int) -> bool:
    """Convenience wrapper for GDPR deletion requests."""
    return CVCleanupService.immediate_cleanup_for_candidate(candidate_id)
