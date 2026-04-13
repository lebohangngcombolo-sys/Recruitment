"""
Recruitee Webhook Processor - Handles incoming webhook events and integrates with CV pipeline.
"""
from __future__ import annotations

import logging
from typing import Any, Dict, Optional
from datetime import datetime

from flask import current_app
from app.extensions import db
from app.models import RecruiteeWebhookLog, Candidate, Requisition, Application
from app.services.recruitee_mapper import recruitee_candidate_to_local, map_recruitee_status_to_application
from app.services.cv_promotion_service import CVPromotionService

logger = logging.getLogger(__name__)


class RecruiteeWebhookProcessor:
    """Process Recruitee webhook events and integrate with CV pipeline"""
    
    def __init__(self):
        self.cv_promotion_service = CVPromotionService()
    
    def handle_event(self, event_type: str, data: Dict[str, Any], event_id: str) -> Dict[str, Any]:
        """Route event to appropriate handler
        
        Args:
            event_type: Recruitee event type (candidate.created, candidate.updated, etc.)
            data: Event payload data
            event_id: Unique Recruitee event ID for idempotency
            
        Returns:
            Dict with processing result
        """
        logger.info(f"Processing Recruitee webhook event: {event_type} (event_id: {event_id})")
        
        handlers = {
            'candidate.created': self.handle_candidate_created,
            'candidate.updated': self.handle_candidate_updated,
            'candidate.moved': self.handle_candidate_moved,
            'offer.created': self.handle_offer_created,
            'offer.updated': self.handle_offer_updated,
            'placement.created': self.handle_placement_created,
        }
        
        handler = handlers.get(event_type)
        if not handler:
            logger.warning(f"Unhandled event type: {event_type}")
            return {
                'success': True,
                'skipped': True,
                'reason': f'Unhandled event type: {event_type}'
            }
        
        try:
            result = handler(data, event_id)
            return result
        except Exception as e:
            logger.exception(f"Error processing event {event_type}: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def handle_candidate_created(self, data: Dict[str, Any], event_id: str) -> Dict[str, Any]:
        """Handle candidate.created event - trigger CV analysis pipeline
        
        Args:
            data: Recruitee candidate data
            event_id: Unique event ID
            
        Returns:
            Processing result
        """
        # Extract candidate data
        candidate_data = data.get('candidate', data)
        recruitee_candidate_id = str(candidate_data.get('id', ''))
        email = candidate_data.get('email', '')
        
        logger.info(f"Processing candidate.created for email: {email}, recruitee_id: {recruitee_candidate_id}")
        
        # Check if candidate already exists by email
        existing = Candidate.query.filter_by(email=email).first()
        
        if existing:
            # Link existing candidate to Recruitee
            if not existing.recruitee_id:
                existing.recruitee_id = recruitee_candidate_id
                existing.last_synced_source = 'recruitee'
                existing.last_synced_at = datetime.utcnow()
                db.session.commit()
                logger.info(f"Linked existing candidate {existing.id} to Recruitee {recruitee_candidate_id}")
            else:
                logger.info(f"Candidate {existing.id} already linked to Recruitee {existing.recruitee_id}")
            
            return {
                'success': True,
                'action': 'linked',
                'candidate_id': existing.id,
                'recruitee_id': recruitee_candidate_id
            }
        
        # Create new candidate from Recruitee data
        new_candidate = recruitee_candidate_to_local(candidate_data)
        new_candidate.recruitee_id = recruitee_candidate_id
        new_candidate.last_synced_source = 'recruitee'
        new_candidate.last_synced_at = datetime.utcnow()
        new_candidate.sync_to_recruitee = True  # Enable future sync
        
        db.session.add(new_candidate)
        db.session.commit()
        
        logger.info(f"Created new candidate {new_candidate.id} from Recruitee {recruitee_candidate_id}")
        
        # Trigger CV analysis if CV file is available
        cv_file = candidate_data.get('cv_file')
        if cv_file and cv_file.get('url'):
            self._trigger_cv_analysis(new_candidate, cv_file.get('url'))
        
        return {
            'success': True,
            'action': 'created',
            'candidate_id': new_candidate.id,
            'recruitee_id': recruitee_candidate_id,
            'cv_analysis_triggered': bool(cv_file and cv_file.get('url'))
        }
    
    def handle_candidate_updated(self, data: Dict[str, Any], event_id: str) -> Dict[str, Any]:
        """Handle candidate.updated event - sync profile updates
        
        Args:
            data: Recruitee candidate data
            event_id: Unique event ID
            
        Returns:
            Processing result
        """
        candidate_data = data.get('candidate', data)
        candidate_id = str(candidate_data.get('id', ''))
        email = candidate_data.get('email', '')
        
        logger.info(f"Processing candidate.updated for email: {email}, recruitee_id: {candidate_id}")
        
        # Find candidate by recruitee_id or fallback to email
        candidate = Candidate.query.filter_by(recruitee_id=str(candidate_id)).first()
        
        if not candidate and email:
            candidate = Candidate.query.filter_by(email=email).first()
            if candidate:
                logger.info(f"Matched Recruitee candidate {candidate_id} to existing local candidate by email: {email}")
                candidate.recruitee_id = str(candidate_id)
        
        if not candidate:
            logger.info(f"Candidate {candidate_id} ({email}) not found locally, creating new record")
            candidate = recruitee_candidate_to_local(candidate_data)
            candidate.last_synced_source = 'recruitee'
            db.session.add(candidate)
        
        # Update candidate info
        updated_candidate = recruitee_candidate_to_local(candidate_data, existing=candidate)
        updated_candidate.last_synced_source = 'recruitee'
        updated_candidate.last_synced_at = datetime.utcnow()
        
        db.session.commit()
        
        logger.info(f"Updated candidate {candidate.id} from Recruitee")
        
        return {
            'success': True,
            'action': 'updated',
            'candidate_id': candidate.id,
            'recruitee_id': candidate_id
        }
    
    def handle_candidate_moved(self, data: Dict[str, Any], event_id: str) -> Dict[str, Any]:
        """Handle candidate.moved event - update application/pipeline status
        
        Args:
            data: Recruitee placement/candidate move data
            event_id: Unique event ID
            
        Returns:
            Processing result
        """
        placement_data = data.get('placement', data)
        candidate_id = str(placement_data.get('candidate_id', ''))
        offer_id = str(placement_data.get('offer_id', ''))
        stage = placement_data.get('stage', '')
        
        logger.info(f"Processing candidate.moved: candidate_id={candidate_id}, offer_id={offer_id}, stage={stage}")
        
        # Find local candidate by Recruitee ID or email
        candidate = Candidate.query.filter_by(recruitee_id=candidate_id).first()
        
        # In moved events, candidate email is nested sometimes, but Recruitee gives 'candidate' object
        cad_info = data.get('candidate', {})
        email = cad_info.get('email')
        
        if not candidate and email:
            candidate = Candidate.query.filter_by(email=email).first()
            if candidate:
                logger.info(f"Matched moved Recruitee candidate {candidate_id} via email: {email}")
                candidate.recruitee_id = candidate_id
        
        if not candidate:
            logger.warning(f"Candidate not found for move: {candidate_id}")
            # Optional: We could create them here, but 'move' events usually follow 'created' events
            return {
                'success': False,
                'error': 'Candidate not found',
                'recruitee_candidate_id': candidate_id
            }
        
        # Find local requisition by Recruitee ID
        requisition = Requisition.query.filter_by(recruitee_id=offer_id).first()
        if not requisition:
            logger.warning(f"Requisition not found for move: {offer_id}")
            return {
                'success': False,
                'error': 'Requisition not found',
                'recruitee_offer_id': offer_id
            }
        
        # Find or create application
        application = Application.query.filter_by(
            candidate_id=candidate.id,
            requisition_id=requisition.id
        ).first()
        
        if not application:
            application = Application(
                candidate_id=candidate.id,
                requisition_id=requisition.id,
                status='applied'
            )
            db.session.add(application)
            logger.info(f"Created application for candidate {candidate.id} to requisition {requisition.id}")
        
        # Map Recruitee stage to local status
        local_status = map_recruitee_status_to_application(stage)
        application.status = local_status
        application.updated_at = datetime.utcnow()
        
        db.session.commit()
        
        logger.info(f"Updated application {application.id} status to {local_status}")
        
        return {
            'success': True,
            'action': 'moved',
            'application_id': application.id,
            'candidate_id': candidate.id,
            'requisition_id': requisition.id,
            'new_status': local_status
        }
    
    def handle_offer_created(self, data: Dict[str, Any], event_id: str) -> Dict[str, Any]:
        """Handle offer.created event - sync job posting
        
        Args:
            data: Recruitee offer/job data
            event_id: Unique event ID
            
        Returns:
            Processing result
        """
        offer_data = data.get('offer', data)
        recruitee_offer_id = str(offer_data.get('id', ''))
        title = offer_data.get('title', '')
        
        logger.info(f"Processing offer.created: {title} (recruitee_id: {recruitee_offer_id})")
        
        # Check if requisition already exists by Recruitee ID
        existing = Requisition.query.filter_by(recruitee_id=recruitee_offer_id).first()
        
        if existing:
            logger.info(f"Requisition {existing.id} already exists for Recruitee offer {recruitee_offer_id}")
            return {
                'success': True,
                'action': 'exists',
                'requisition_id': existing.id,
                'recruitee_id': recruitee_offer_id
            }
        
        # Create local requisition from Recruitee offer data
        try:
            from app.models import Requisition
            from app import db
            
            # Map employment type
            emp_type_map = {
                'full': 'full_time',
                'full-time': 'full_time',
                'full_time': 'full_time',
                'fulltime_permanent': 'full_time',
                'part': 'part_time',
                'part-time': 'part_time',
                'part_time': 'part_time',
                'contract': 'contract',
                'internship': 'internship',
                'temporary': 'temporary',
                'freelance': 'freelance'
            }
            
            # Create new requisition
            req = Requisition(
                title=offer_data.get('title', 'Untitled Job'),
                description=offer_data.get('description', ''),
                location=offer_data.get('location', ''),
                category=offer_data.get('department', 'General'),
                employment_type=emp_type_map.get(offer_data.get('employment_type'), 'full_time'),
                is_active=offer_data.get('status') == 'published',
                recruitee_id=recruitee_offer_id,
                recruitee_sync_enabled=True,
                approval_status='approved',  # Auto-approve jobs from Recruitee
                sync_to_recruitee=True,
                last_synced_source='recruitee',
                recruitee_synced_at=datetime.utcnow()
            )
            
            # Map salary if present
            salary_data = offer_data.get('salary')
            if salary_data and isinstance(salary_data, dict):
                req.salary_min = salary_data.get('min')
                req.salary_max = salary_data.get('max')
                req.salary_currency = salary_data.get('currency', 'ZAR')
            
            db.session.add(req)
            db.session.commit()
            
            logger.info(f"Created requisition {req.id} from Recruitee offer {recruitee_offer_id}")
            
            return {
                'success': True,
                'action': 'created',
                'requisition_id': req.id,
                'recruitee_id': recruitee_offer_id
            }
            
        except Exception as e:
            db.session.rollback()
            logger.error(f"Failed to create requisition from Recruitee offer: {e}")
            return {
                'success': False,
                'error': str(e),
                'recruitee_offer_id': recruitee_offer_id
            }
    
    def handle_offer_updated(self, data: Dict[str, Any], event_id: str) -> Dict[str, Any]:
        """Handle offer.updated event - sync job updates
        
        Args:
            data: Recruitee offer/job data
            event_id: Unique event ID
            
        Returns:
            Processing result
        """
        offer_data = data.get('offer', data)
        recruitee_offer_id = str(offer_data.get('id', ''))
        
        logger.info(f"Processing offer.updated: recruitee_id={recruitee_offer_id}")
        
        # Find local requisition by Recruitee ID
        requisition = Requisition.query.filter_by(recruitee_id=recruitee_offer_id).first()
        
        if not requisition:
            logger.warning(f"Requisition not found for update: {recruitee_offer_id}")
            return {
                'success': False,
                'error': 'Requisition not found',
                'recruitee_offer_id': recruitee_offer_id
            }
        
        # Get offer data from webhook payload
        offer_data = data.get('offer', {})
        if not offer_data:
            logger.warning(f"No offer data in webhook payload for {recruitee_offer_id}")
            return {
                'success': False,
                'error': 'No offer data in payload',
                'recruitee_offer_id': recruitee_offer_id
            }
        
        # Check if this change came from our system (loop prevention)
        last_source = getattr(requisition, 'last_synced_source', None)
        if last_source == 'manual':
            logger.info(f"Offer {recruitee_offer_id} was recently synced from local - skipping webhook update to prevent loop")
            return {
                'success': True,
                'action': 'skipped',
                'reason': 'Loop prevention - recent manual sync',
                'requisition_id': requisition.id
            }
        
        # Update local requisition from Recruitee data
        try:
            # Map basic fields
            if offer_data.get('title'):
                requisition.title = offer_data['title']
            if offer_data.get('description'):
                requisition.description = offer_data['description']
            if offer_data.get('location'):
                requisition.location = offer_data['location']
            if offer_data.get('department'):
                requisition.category = offer_data['department']
            
            # Map employment type (Recruitee uses "full", "part" etc.)
            if offer_data.get('employment_type'):
                emp_map = {
                    'full': 'full_time',
                    'full-time': 'full_time',
                    'full_time': 'full_time',
                    'fulltime_permanent': 'full_time',
                    'part': 'part_time',
                    'part-time': 'part_time',
                    'part_time': 'part_time',
                    'contract': 'contract',
                    'internship': 'internship',
                    'temporary': 'temporary',
                    'freelance': 'freelance'
                }
                requisition.employment_type = emp_map.get(offer_data['employment_type'], 'full_time')
            
            # Map status (Recruitee: published/closed/draft -> Our: active/inactive)
            if offer_data.get('status'):
                requisition.is_active = offer_data['status'] == 'published'
            
            # Map salary if present
            salary_data = offer_data.get('salary')
            if salary_data and isinstance(salary_data, dict):
                requisition.salary_min = salary_data.get('min')
                requisition.salary_max = salary_data.get('max')
                requisition.salary_currency = salary_data.get('currency', 'ZAR')
            
            # Mark as synced from Recruitee to prevent outbound sync loop
            requisition.last_synced_source = 'recruitee'
            requisition.recruitee_synced_at = datetime.utcnow()
            
            db.session.commit()
            
            logger.info(f"Updated requisition {requisition.id} from Recruitee offer {recruitee_offer_id}")
            
            return {
                'success': True,
                'action': 'updated',
                'requisition_id': requisition.id,
                'changes': list(offer_data.keys())
            }
            
        except Exception as e:
            db.session.rollback()
            logger.error(f"Failed to update requisition from Recruitee: {e}")
            return {
                'success': False,
                'error': str(e),
                'recruitee_offer_id': recruitee_offer_id
            }
    
    def handle_placement_created(self, data: Dict[str, Any], event_id: str) -> Dict[str, Any]:
        """Handle placement.created event - new application to a job
        
        Args:
            data: Recruitee placement/application data
            event_id: Unique event ID
            
        Returns:
            Processing result
        """
        # Similar to candidate.moved - this is a new application
        return self.handle_candidate_moved(data, event_id)
    
    def _trigger_cv_analysis(self, candidate: Candidate, cv_url: str) -> None:
        """Trigger CV analysis pipeline for candidate
        
        Args:
            candidate: Candidate model instance
            cv_url: URL to CV file
        """
        try:
            # Store CV URL
            candidate.cv_url = cv_url
            candidate.cv_analysis_status = 'pending'
            db.session.commit()
            
            logger.info(f"CV analysis triggered for candidate {candidate.id} with CV URL: {cv_url}")
            
            # Note: Actual CV analysis would be triggered via the CV promotion service
            # This would typically call the external CV analyser service
            # For now, we just mark as pending
            
        except Exception as e:
            logger.error(f"Failed to trigger CV analysis for candidate {candidate.id}: {e}")
