"""
Recruitee Service Layer - Business logic for ATS integration.
Handles sync operations with loop prevention and logging.
"""
from __future__ import annotations

import logging
from typing import Any, Dict, List, Optional, Tuple
from datetime import datetime

from flask import current_app
from app.extensions import db
from app.services.recruitee_client import RecruiteeClient, RecruiteeAPIError
from app.services.recruitee_mapper import (
    requisition_to_offer,
    candidate_to_recruitee,
    offer_to_requisition,
    recruitee_candidate_to_local,
)

logger = logging.getLogger(__name__)


class RecruiteeService:
    """Service for Recruitee ATS integration operations"""
    
    def __init__(self, client: Optional[RecruiteeClient] = None):
        """Initialize with optional client (creates default if not provided)"""
        if not current_app.config.get('RECRUITEE_ENABLED'):
            raise ValueError("Recruitee integration is not enabled")
        
        self.client = client or RecruiteeClient()
    
    # ==================== CONNECTION TESTING ====================
    
    def test_connection(self) -> Tuple[bool, Optional[str]]:
        """Test API connection and return status
        
        Returns:
            Tuple of (success: bool, error_message: str or None)
        """
        try:
            # Try to fetch a single offer
            result = self.client.get_offers(limit=1)
            offer_count = len(result.get('offers', []))
            logger.info(f"Recruitee connection successful. Found {offer_count} offers.")
            return True, None
        except RecruiteeAPIError as e:
            error_msg = f"API Error: {e.message}"
            if e.status_code:
                error_msg += f" (Status: {e.status_code})"
            logger.error(error_msg)
            return False, error_msg
        except Exception as e:
            error_msg = f"Connection failed: {str(e)}"
            logger.error(error_msg)
            return False, error_msg
    
    # ==================== JOB / OFFER SYNC ====================
    
    def sync_job_to_recruitee(self, requisition: Any, 
                              force: bool = False,
                              synced_by: Optional[int] = None,
                              retry_record: Optional[Any] = None) -> Dict[str, Any]:
        """Sync a job requisition to Recruitee with history tracking
        
        Args:
            requisition: Requisition model instance
            force: If True, sync even if last_synced_source is 'recruitee'
            synced_by: User ID who triggered the sync (for audit)
            retry_record: Existing RecruiteeSyncHistory record if this is a retry
            
        Returns:
            Dict with sync result: {'success': bool, 'external_id': str, 'action': str}
        """
        from app.models import RecruiteeSyncHistory
        
        # Loop prevention: skip if we just got this from Recruitee
        if not force and getattr(requisition, 'last_synced_source', None) == 'recruitee':
            logger.info(f"Skipping job {requisition.id} - last synced from Recruitee")
            # Create history record for skipped sync
            history = RecruiteeSyncHistory(
                entity_type='job',
                entity_id=requisition.id,
                recruitee_id=requisition.recruitee_id,
                action='update' if requisition.recruitee_id else 'create',
                status='skipped',
                error_message='last_synced_source=recruitee',
                synced_by=synced_by
            )
            db.session.add(history)
            db.session.commit()
            
            return {
                'success': True,
                'skipped': True,
                'reason': 'last_synced_source=recruitee',
                'requisition_id': requisition.id
            }
        
        # Create or use existing history record
        if retry_record:
            history = retry_record
            history.action = 'retry'
        else:
            history = RecruiteeSyncHistory(
                entity_type='job',
                entity_id=requisition.id,
                recruitee_id=requisition.recruitee_id,
                action='update' if requisition.recruitee_id else 'create',
                status='pending',
                synced_by=synced_by
            )
            db.session.add(history)
            db.session.commit()
        
        try:
            # Prepare offer data
            offer_data = requisition_to_offer(requisition)
            history.request_data = offer_data
            
            # Execute API call first (before any DB changes)
            if requisition.recruitee_id:
                logger.info(f"Updating Recruitee offer {requisition.recruitee_id} for job {requisition.id}")
                result = self.client.update_offer(requisition.recruitee_id, offer_data)
                action = 'updated'
            else:
                logger.info(f"Creating new Recruitee offer for job {requisition.id}")
                result = self.client.create_offer(offer_data)
                action = 'created'
            
            # Only update DB after successful API call
            if action == 'created':
                offer_result = result.get('offer', {})
                requisition.recruitee_id = str(offer_result.get('id', ''))
                history.recruitee_id = requisition.recruitee_id
            
            requisition.last_synced_at = datetime.utcnow()
            requisition.last_synced_source = 'local'
            requisition.sync_to_recruitee = True
            
            # Update history record with success
            history.status = 'success'
            history.response_data = result
            history.completed_at = datetime.utcnow()
            db.session.commit()
            
            logger.info(f"Job {requisition.id} synced to Recruitee successfully (action={action})")
            
            return {
                'success': True,
                'requisition_id': requisition.id,
                'external_id': requisition.recruitee_id,
                'action': action,
                'history_id': history.id
            }
            
        except RecruiteeAPIError as e:
            logger.error(f"Failed to sync job {requisition.id}: {e.message}")
            
            # Update history record with failure and schedule retry
            history.status = 'failed'
            history.error_message = e.message
            history.response_data = {'status_code': e.status_code, 'body': e.response_body}
            
            # Schedule retry if eligible
            if history.should_retry():
                history.schedule_retry()
                logger.info(f"Scheduled retry for job {requisition.id} at {history.next_retry_at}")
            
            db.session.commit()
            
            return {
                'success': False,
                'requisition_id': requisition.id,
                'error': e.message,
                'status_code': e.status_code,
                'history_id': history.id,
                'retry_scheduled': history.should_retry()
            }
            
        except Exception as e:
            logger.exception(f"Unexpected error syncing job {requisition.id}")
            
            # Update history record with failure
            history.status = 'failed'
            history.error_message = str(e)
            
            # Schedule retry if eligible
            if history.should_retry():
                history.schedule_retry()
                logger.info(f"Scheduled retry for job {requisition.id} at {history.next_retry_at}")
            
            db.session.commit()
            
            return {
                'success': False,
                'requisition_id': requisition.id,
                'error': str(e),
                'history_id': history.id,
                'retry_scheduled': history.should_retry()
            }
    
    def sync_candidate_to_recruitee(self, candidate: Any,
                                    application: Optional[Any] = None,
                                    requisition: Optional[Any] = None,
                                    force: bool = False) -> Dict[str, Any]:
        """Sync a candidate to Recruitee
        
        Args:
            candidate: Candidate model instance
            application: Optional Application model (for job context)
            requisition: Optional Requisition model (for direct job placement)
            force: If True, sync even if last_synced_source is 'recruitee'
            
        Returns:
            Dict with sync result
        """
        # Loop prevention
        if not force and getattr(candidate, 'last_synced_source', None) == 'recruitee':
            logger.info(f"Skipping candidate {candidate.id} - last synced from Recruitee")
            return {
                'success': True,
                'skipped': True,
                'reason': 'last_synced_source=recruitee',
                'candidate_id': candidate.id
            }
        
        try:
            # Check if candidate already exists by email
            if not candidate.recruitee_id:
                existing = self._find_candidate_by_email(candidate.email)
                if existing:
                    candidate.recruitee_id = str(existing.get('id'))
                    logger.info(f"Found existing Recruitee candidate by email: {candidate.recruitee_id}")
            
            # Prepare candidate data
            candidate_data = candidate_to_recruitee(candidate, application, requisition)
            
            if candidate.recruitee_id:
                # Update existing candidate
                logger.info(f"Updating Recruitee candidate {candidate.recruitee_id}")
                result = self.client.update_candidate(candidate.recruitee_id, candidate_data)
                action = 'updated'
            else:
                # Create new candidate
                logger.info(f"Creating new Recruitee candidate for {candidate.email}")
                result = self.client.create_candidate(candidate_data)
                action = 'created'
                
                # Store Recruitee ID
                cand_result = result.get('candidate', {})
                candidate.recruitee_id = str(cand_result.get('id', ''))
            
            # Update sync tracking
            candidate.last_synced_at = datetime.utcnow()
            candidate.last_synced_source = 'local'
            candidate.sync_to_recruitee = True
            db.session.commit()
            
            logger.info(f"Candidate {candidate.id} synced to Recruitee successfully (action={action})")
            
            return {
                'success': True,
                'candidate_id': candidate.id,
                'external_id': candidate.recruitee_id,
                'action': action
            }
            
        except RecruiteeAPIError as e:
            logger.error(f"Failed to sync candidate {candidate.id}: {e.message}")
            return {
                'success': False,
                'candidate_id': candidate.id,
                'error': e.message,
                'status_code': e.status_code
            }
        except Exception as e:
            logger.exception(f"Unexpected error syncing candidate {candidate.id}")
            return {
                'success': False,
                'candidate_id': candidate.id,
                'error': str(e)
            }
    
    def _find_candidate_by_email(self, email: str) -> Optional[Dict]:
        """Search for candidate in Recruitee by email"""
        try:
            results = self.client.get_candidates(query=email, limit=10)
            candidates = results.get('candidates', [])
            
            for cand in candidates:
                if cand.get('email', '').lower() == email.lower():
                    return cand
            
            return None
        except Exception as e:
            logger.warning(f"Failed to search candidate by email: {e}")
            return None
    
    # ==================== BULK SYNC OPERATIONS ====================
    
    def sync_all_jobs(self, only_active: bool = True) -> List[Dict[str, Any]]:
        """Sync all pending jobs to Recruitee
        
        Args:
            only_active: If True, only sync active jobs
            
        Returns:
            List of sync results for each job
        """
        from app.models import Requisition
        
        query = Requisition.query.filter_by(sync_to_recruitee=True)
        if only_active:
            query = query.filter_by(is_active=True)
        
        jobs = query.all()
        results = []
        
        logger.info(f"Starting bulk sync of {len(jobs)} jobs to Recruitee")
        
        for job in jobs:
            result = self.sync_job_to_recruitee(job)
            results.append(result)
        
        success_count = sum(1 for r in results if r.get('success'))
        logger.info(f"Bulk job sync complete: {success_count}/{len(results)} successful")
        
        return results
    
    def sync_job_candidates(self, requisition: Any) -> List[Dict[str, Any]]:
        """Sync all candidates who applied to a specific job
        
        Args:
            requisition: Requisition model with applicants
            
        Returns:
            List of sync results
        """
        if not requisition.recruitee_id:
            logger.warning(f"Job {requisition.id} not synced to Recruitee yet")
            return []
        
        from app.models import Application
        
        applications = Application.query.filter_by(requisition_id=requisition.id).all()
        results = []
        
        logger.info(f"Syncing {len(applications)} candidates for job {requisition.id}")
        
        for app in applications:
            if app.candidate:
                result = self.sync_candidate_to_recruitee(
                    app.candidate, 
                    application=app,
                    requisition=requisition
                )
                results.append(result)
        
        return results
    
    # ==================== PULL OPERATIONS (for future bi-directional) ====================
    
    def pull_jobs_from_recruitee(self, since: Optional[datetime] = None) -> List[Dict[str, Any]]:
        """Fetch jobs from Recruitee and update local records
        
        This is for bi-directional sync - pulls changes from Recruitee.
        Currently stores recruitee_id mapping for future use.
        
        Args:
            since: Only fetch jobs updated since this timestamp
            
        Returns:
            List of processed jobs
        """
        from app.models import Requisition
        
        try:
            params = {}
            if since:
                params['updated_since'] = since.isoformat()
            
            result = self.client.get_offers(status='published', limit=100)
            offers = result.get('offers', [])
            
            processed = []
            
            for offer in offers:
                recruitee_id = str(offer.get('id'))
                external_id = offer.get('external_id')
                
                # Try to find existing by recruitee_id first
                req = Requisition.query.filter_by(recruitee_id=recruitee_id).first()
                
                # If not found, try by external_id (our internal ID)
                if not req and external_id:
                    try:
                        req_id = int(external_id)
                        req = Requisition.query.get(req_id)
                    except (ValueError, TypeError):
                        pass
                
                if req:
                    # Update tracking fields
                    req.recruitee_id = recruitee_id
                    req.last_synced_at = datetime.utcnow()
                    req.last_synced_source = 'recruitee'
                    processed.append({
                        'requisition_id': req.id,
                        'recruitee_id': recruitee_id,
                        'action': 'linked'
                    })
                else:
                    processed.append({
                        'recruitee_id': recruitee_id,
                        'title': offer.get('title'),
                        'action': 'skipped_no_match'
                    })
            
            db.session.commit()
            logger.info(f"Pulled {len(offers)} jobs from Recruitee, linked {len([p for p in processed if p.get('action') == 'linked'])}")
            
            return processed
            
        except Exception as e:
            logger.exception("Failed to pull jobs from Recruitee")
            return [{'error': str(e)}]
    
    # ==================== UTILITY ====================
    
    def get_recruitee_job_url(self, requisition: Any) -> Optional[str]:
        """Get the public Recruitee job URL for a requisition"""
        if not requisition.recruitee_id:
            return None
        
        company_id = current_app.config.get('RECRUITEE_COMPANY_ID')
        return f"https://{company_id}.recruitee.com/o/{requisition.recruitee_id}"
    
    def get_recruitee_candidate_url(self, candidate: Any) -> Optional[str]:
        """Get the Recruitee admin URL for a candidate"""
        if not candidate.recruitee_id:
            return None
        
        company_id = current_app.config.get('RECRUITEE_COMPANY_ID')
        return f"https://{company_id}.recruitee.com/dashboard/candidates/{candidate.recruitee_id}"
    
    # ==================== SYNC HISTORY & RETRY ====================
    
    def get_sync_history(self, entity_type: Optional[str] = None,
                         entity_id: Optional[int] = None,
                         status: Optional[str] = None,
                         limit: int = 50) -> List[Dict[str, Any]]:
        """Query sync history with optional filters"""
        from app.models import RecruiteeSyncHistory
        
        query = RecruiteeSyncHistory.query
        
        if entity_type:
            query = query.filter_by(entity_type=entity_type)
        if entity_id:
            query = query.filter_by(entity_id=entity_id)
        if status:
            query = query.filter_by(status=status)
        
        history = query.order_by(RecruiteeSyncHistory.created_at.desc()).limit(limit).all()
        return [h.to_dict() for h in history]
    
    def process_pending_retries(self) -> List[Dict[str, Any]]:
        """Process all sync attempts that are due for retry
        
        Returns:
            List of retry results
        """
        from app.models import RecruiteeSyncHistory, Requisition
        from datetime import datetime
        
        # Find pending retries that are due
        pending = RecruiteeSyncHistory.query.filter(
            RecruiteeSyncHistory.status == 'pending',
            RecruiteeSyncHistory.next_retry_at <= datetime.utcnow(),
            RecruiteeSyncHistory.retry_count < RecruiteeSyncHistory.max_retries
        ).all()
        
        results = []
        
        for history in pending:
            if history.entity_type == 'job':
                job = Requisition.query.get(history.entity_id)
                if job:
                    result = self.sync_job_to_recruitee(job, retry_record=history)
                    results.append(result)
                else:
                    # Job was deleted, mark as failed
                    history.status = 'failed'
                    history.error_message = 'Job no longer exists'
                    db.session.commit()
                    results.append({
                        'success': False,
                        'error': 'Job no longer exists',
                        'history_id': history.id
                    })
        
        return results
    
    def verify_webhook_signature(self, payload: bytes, signature: str, secret: str) -> bool:
        """Verify Recruitee webhook HMAC signature
        
        Args:
            payload: Raw request body bytes
            signature: Signature from X-Recruitee-Signature header
            secret: Webhook secret from config
            
        Returns:
            True if signature is valid
        """
        import hmac
        import hashlib
        
        if not signature or not secret:
            return False
        
        # Compute expected signature
        expected = hmac.new(
            secret.encode('utf-8'),
            payload,
            hashlib.sha256
        ).hexdigest()
        
        # Use constant-time comparison to prevent timing attacks
        return hmac.compare_digest(expected, signature)
