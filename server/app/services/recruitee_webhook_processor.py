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
        recruitee_candidate_id = str(candidate_data.get('id', ''))
        email = candidate_data.get('email', '')
        
        logger.info(f"Processing candidate.updated for email: {email}, recruitee_id: {recruitee_candidate_id}")
        
        # Find candidate by Recruitee ID or email
        candidate = Candidate.query.filter_by(recruitee_id=recruitee_candidate_id).first()
        if not candidate:
            candidate = Candidate.query.filter_by(email=email).first()
        
        if not candidate:
            logger.warning(f"Candidate not found for update: {email}")
            return {
                'success': False,
                'error': 'Candidate not found',
                'email': email
            }
        
        # Update candidate data
        updated_candidate = recruitee_candidate_to_local(candidate_data, existing=candidate)
        updated_candidate.recruitee_id = recruitee_candidate_id
        updated_candidate.last_synced_source = 'recruitee'
        updated_candidate.last_synced_at = datetime.utcnow()
        
        db.session.commit()
        
        logger.info(f"Updated candidate {candidate.id} from Recruitee")
        
        return {
            'success': True,
            'action': 'updated',
            'candidate_id': candidate.id,
            'recruitee_id': recruitee_candidate_id
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
        
        # Find local candidate by Recruitee ID
        candidate = Candidate.query.filter_by(recruitee_id=candidate_id).first()
        if not candidate:
            logger.warning(f"Candidate not found for move: {candidate_id}")
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
        
        # For now, just log - full bi-directional sync would create requisition here
        logger.info(f"Offer created in Recruitee: {title} - skipping local creation (one-way sync)")
        
        return {
            'success': True,
            'action': 'skipped',
            'reason': 'One-way sync (Recruitee → App) not enabled',
            'recruitee_id': recruitee_offer_id
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
        
        # For now, just log - full bi-directional sync would update requisition here
        logger.info(f"Offer updated in Recruitee - skipping local update (one-way sync)")
        
        return {
            'success': True,
            'action': 'skipped',
            'reason': 'One-way sync (Recruitee → App) not enabled',
            'requisition_id': requisition.id
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
