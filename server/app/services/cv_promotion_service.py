# app/services/cv_promotion_service.py
"""
CV Promotion Service - Formalized "Process & Promote" pattern implementation.

This service handles the synchronization between the external CV Analyser service
and the local Recruitment App database, implementing the cross-database
synchronization strategy.

Process: CV is analyzed by external CV Analyser service
Promote: Results are fetched and promoted to Recruitment App Database
"""

import logging
from datetime import datetime, timedelta
from typing import Dict, Optional, Any
from app import db
from app.models import Candidate, CVAnalysis
from app.services.analysis_service_client import AnalysisServiceClient
from app.services.data_merger import DataMerger

logger = logging.getLogger(__name__)


class CVPromotionService:
    """
    Formalized "Process & Promote" pattern implementation.
    
    Handles the promotion of CV analysis results from the external
    CV Analyser service to the local Recruitment App database.
    """
    
    # Status constants
    STATUS_PENDING = 'pending'
    STATUS_PROCESSING = 'processing'
    STATUS_COMPLETED = 'completed'
    STATUS_FAILED = 'failed'
    
    @staticmethod
    def promote_analysis_to_candidate(candidate_id: int, analysis_id: int) -> Dict[str, Any]:
        """
        Promote CV analysis results to candidate profile.
        
        This is the core "Promote" step of the Process & Promote pattern.
        Fetches results from external analyser and updates candidate profile.
        
        Args:
            candidate_id: Local candidate ID
            analysis_id: Local CVAnalysis ID
            
        Returns:
            dict: Promotion result with status and promoted fields
            {
                'success': bool,
                'candidate_id': int,
                'analysis_id': int,
                'status': str,
                'promoted_fields': list,
                'error': str (if failed)
            }
        """
        try:
            # Get candidate and analysis records
            candidate = Candidate.query.get(candidate_id)
            cv_analysis = CVAnalysis.query.get(analysis_id)
            
            if not candidate:
                return {
                    'success': False,
                    'candidate_id': candidate_id,
                    'analysis_id': analysis_id,
                    'status': CVPromotionService.STATUS_FAILED,
                    'error': f'Candidate {candidate_id} not found',
                    'promoted_fields': []
                }
            
            if not cv_analysis:
                return {
                    'success': False,
                    'candidate_id': candidate_id,
                    'analysis_id': analysis_id,
                    'status': CVPromotionService.STATUS_FAILED,
                    'error': f'CVAnalysis {analysis_id} not found',
                    'promoted_fields': []
                }
            
            # Check if external analysis exists
            if not cv_analysis.external_analysis_id:
                return {
                    'success': False,
                    'candidate_id': candidate_id,
                    'analysis_id': analysis_id,
                    'status': CVPromotionService.STATUS_FAILED,
                    'error': 'No external analysis ID associated',
                    'promoted_fields': []
                }
            
            # Fetch result from external service if not already completed
            if cv_analysis.status != CVPromotionService.STATUS_COMPLETED:
                try:
                    result = AnalysisServiceClient.get_analysis_result(
                        cv_analysis.external_analysis_id
                    )
                    
                    # Merge result into local database
                    DataMerger.update_local_database(analysis_id, result)
                    
                except Exception as e:
                    logger.error(f"Failed to fetch/merge external result: {e}")
                    return {
                        'success': False,
                        'candidate_id': candidate_id,
                        'analysis_id': analysis_id,
                        'status': CVPromotionService.STATUS_FAILED,
                        'error': f'Failed to fetch external result: {str(e)}',
                        'promoted_fields': []
                    }
            
            # Update candidate with sync fields
            candidate.analyser_id = cv_analysis.external_analysis_id
            candidate.cv_analysis_status = CVPromotionService.STATUS_COMPLETED
            candidate.cv_analysis_promoted_at = datetime.utcnow()
            candidate.last_cv_analysis_id = analysis_id
            
            # Commit changes
            db.session.add(candidate)
            db.session.commit()
            
            # Get promoted fields from the analysis result
            promoted_fields = CVPromotionService._extract_promoted_fields(cv_analysis)
            
            logger.info(
                f"Successfully promoted CV analysis {analysis_id} "
                f"to candidate {candidate_id}. Fields: {promoted_fields}"
            )
            
            return {
                'success': True,
                'candidate_id': candidate_id,
                'analysis_id': analysis_id,
                'status': CVPromotionService.STATUS_COMPLETED,
                'promoted_fields': promoted_fields,
                'promoted_at': candidate.cv_analysis_promoted_at.isoformat()
            }
            
        except Exception as e:
            db.session.rollback()
            logger.exception(f"Failed to promote analysis {analysis_id} to candidate {candidate_id}")
            return {
                'success': False,
                'candidate_id': candidate_id,
                'analysis_id': analysis_id,
                'status': CVPromotionService.STATUS_FAILED,
                'error': str(e),
                'promoted_fields': []
            }
    
    @staticmethod
    def _extract_promoted_fields(cv_analysis: CVAnalysis) -> list:
        """Extract list of fields that were promoted from analysis result."""
        promoted = []
        result = cv_analysis.result or {}
        
        # Check personal details
        personal = result.get('personal_details', {})
        if personal.get('full_name'):
            promoted.append('full_name')
        if personal.get('email'):
            promoted.append('email')
        if personal.get('phone'):
            promoted.append('phone')
        if personal.get('address'):
            promoted.append('address')
        if personal.get('linkedin'):
            promoted.append('linkedin')
        if personal.get('github'):
            promoted.append('github')
        if personal.get('portfolio'):
            promoted.append('portfolio')
        
        # Check structured data
        if result.get('education'):
            promoted.append('education')
        if result.get('skills'):
            promoted.append('skills')
        if result.get('work_experience'):
            promoted.append('work_experience')
        if result.get('certifications'):
            promoted.append('certifications')
        if result.get('languages'):
            promoted.append('languages')
        if result.get('professional_summary'):
            promoted.append('bio')
        
        return promoted
    
    @staticmethod
    def get_candidate_analysis_status(candidate_id: int) -> Optional[str]:
        """
        Get the current CV analysis status for a candidate.
        
        Args:
            candidate_id: Local candidate ID
            
        Returns:
            str: 'pending', 'processing', 'completed', 'failed', or None
        """
        candidate = Candidate.query.get(candidate_id)
        if not candidate:
            return None
        
        # Return cached status from candidate record
        if candidate.cv_analysis_status:
            return candidate.cv_analysis_status
        
        # Fallback: check latest analysis
        latest_analysis = CVAnalysis.query.filter_by(
            candidate_id=candidate_id
        ).order_by(CVAnalysis.created_at.desc()).first()
        
        if latest_analysis:
            return latest_analysis.status
        
        return None
    
    @staticmethod
    def sync_analysis_status(candidate_id: int, force_refresh: bool = False) -> bool:
        """
        Sync status from external analyser to local candidate record.
        
        Polls external service if needed and updates candidate status.
        
        Args:
            candidate_id: Local candidate ID
            force_refresh: Force refresh even if recently updated
            
        Returns:
            bool: True if status was updated, False otherwise
        """
        try:
            candidate = Candidate.query.get(candidate_id)
            if not candidate:
                logger.warning(f"Candidate {candidate_id} not found for status sync")
                return False
            
            # Get latest analysis
            latest_analysis = CVAnalysis.query.filter_by(
                candidate_id=candidate_id
            ).order_by(CVAnalysis.created_at.desc()).first()
            
            if not latest_analysis:
                logger.debug(f"No CV analysis found for candidate {candidate_id}")
                return False
            
            # Skip if no external ID
            if not latest_analysis.external_analysis_id:
                return False
            
            # Rate limiting: only re-check if last update was > 15 seconds ago
            if not force_refresh and latest_analysis.updated_at:
                time_since_update = datetime.utcnow() - latest_analysis.updated_at
                if time_since_update < timedelta(seconds=15):
                    return False
            
            # Check external status
            status_result = AnalysisServiceClient.get_analysis_status(
                latest_analysis.external_analysis_id
            )
            external_status = status_result.get('status')
            
            # Update candidate status
            candidate.cv_analysis_status = external_status
            latest_analysis.status = external_status
            latest_analysis.updated_at = datetime.utcnow()
            
            # If completed, trigger promotion
            if external_status == CVPromotionService.STATUS_COMPLETED:
                db.session.add(candidate)
                db.session.add(latest_analysis)
                db.session.commit()
                
                # Auto-promote if completed
                CVPromotionService.promote_analysis_to_candidate(
                    candidate_id, latest_analysis.id
                )
                return True
            
            elif external_status == CVPromotionService.STATUS_FAILED:
                candidate.cv_analysis_status = CVPromotionService.STATUS_FAILED
                db.session.add(candidate)
                db.session.add(latest_analysis)
                db.session.commit()
                return True
            
            else:
                # Just update status
                db.session.add(candidate)
                db.session.add(latest_analysis)
                db.session.commit()
                return True
                
        except Exception as e:
            logger.error(f"Failed to sync analysis status for candidate {candidate_id}: {e}")
            return False
    
    @staticmethod
    def initialize_analysis_submission(
        candidate_id: int,
        external_analysis_id: str,
        cv_text: str,
        job_description: str = None,
        application_id: int = None,
        requisition_id: int = None
    ) -> CVAnalysis:
        """
        Initialize a new CV analysis submission.
        
        Creates local CVAnalysis record and links it to candidate.
        
        Args:
            candidate_id: Local candidate ID
            external_analysis_id: External analyser ID
            cv_text: Extracted CV text
            job_description: Optional job description
            application_id: Optional application ID
            requisition_id: Optional requisition ID
            
        Returns:
            CVAnalysis: Created analysis record
        """
        try:
            # Create CVAnalysis record
            cv_analysis = CVAnalysis(
                candidate_id=candidate_id,
                application_id=application_id,
                requisition_id=requisition_id,
                job_description=job_description or "",
                cv_text=cv_text or "",
                external_analysis_id=external_analysis_id,
                status='submitted',
                started_at=datetime.utcnow()
            )
            
            db.session.add(cv_analysis)
            db.session.commit()
            
            # Update candidate status
            candidate = Candidate.query.get(candidate_id)
            if candidate:
                candidate.analyser_id = external_analysis_id
                candidate.cv_analysis_status = 'submitted'
                candidate.last_cv_analysis_id = cv_analysis.id
                db.session.add(candidate)
                db.session.commit()
            
            logger.info(
                f"Initialized analysis submission for candidate {candidate_id} "
                f"with external ID {external_analysis_id}"
            )
            
            return cv_analysis
            
        except Exception as e:
            db.session.rollback()
            logger.error(f"Failed to initialize analysis submission: {e}")
            raise
    
    @staticmethod
    def get_promotion_summary(candidate_id: int) -> Dict[str, Any]:
        """
        Get a summary of the candidate's CV analysis and promotion status.
        
        Args:
            candidate_id: Local candidate ID
            
        Returns:
            dict: Summary with status, analyser_id, promoted fields, etc.
        """
        candidate = Candidate.query.get(candidate_id)
        if not candidate:
            return {'error': 'Candidate not found'}
        
        summary = {
            'candidate_id': candidate_id,
            'analyser_id': candidate.analyser_id,
            'status': candidate.cv_analysis_status,
            'promoted_at': candidate.cv_analysis_promoted_at.isoformat() if candidate.cv_analysis_promoted_at else None,
            'last_analysis_id': candidate.last_cv_analysis_id,
            'is_promoted': candidate.cv_analysis_status == CVPromotionService.STATUS_COMPLETED and candidate.cv_analysis_promoted_at is not None
        }
        
        # Get latest analysis details
        if candidate.last_cv_analysis_id:
            analysis = CVAnalysis.query.get(candidate.last_cv_analysis_id)
            if analysis:
                summary['analysis'] = {
                    'id': analysis.id,
                    'external_id': analysis.external_analysis_id,
                    'status': analysis.status,
                    'created_at': analysis.created_at.isoformat() if analysis.created_at else None,
                    'finished_at': analysis.finished_at.isoformat() if analysis.finished_at else None,
                    'has_result': bool(analysis.result)
                }
        
        return summary


# Convenience function for enrollment service
def promote_cv_analysis(candidate_id: int, analysis_id: int) -> Dict[str, Any]:
    """Convenience wrapper for CVPromotionService.promote_analysis_to_candidate."""
    return CVPromotionService.promote_analysis_to_candidate(candidate_id, analysis_id)
