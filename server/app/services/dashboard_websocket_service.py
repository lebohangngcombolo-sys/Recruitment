"""Dashboard WebSocket Service for real-time updates.

This module provides helper functions to emit dashboard-related WebSocket events
to connected clients when data changes occur.
"""

from app.extensions import socketio
from flask import current_app
from typing import Optional, Dict, Any, List


class DashboardWebSocketService:
    """Service for emitting dashboard WebSocket events."""

    @staticmethod
    def emit_interview_created(interview_data: Dict[str, Any], user_id: Optional[str] = None) -> None:
        """
        Emit interview_created event to dashboard subscribers.
        
        Args:
            interview_data: Dictionary containing interview details
            user_id: Optional specific user to notify (if None, broadcasts to all admin dashboards)
        """
        try:
            payload = {
                'id': interview_data.get('id'),
                'job_title': interview_data.get('job_title'),
                'candidate_name': interview_data.get('candidate_name'),
                'candidate_id': interview_data.get('candidate_id'),
                'scheduled_time': interview_data.get('scheduled_time'),
                'status': interview_data.get('status', 'scheduled'),
                'hiring_manager_id': interview_data.get('hiring_manager_id'),
                'created_at': interview_data.get('created_at'),
            }
            
            if user_id:
                room = f'dashboard_{user_id}'
                socketio.emit('interview_created', payload, room=room)
                current_app.logger.info(f"📊 WebSocket: Interview created event sent to room {room}")
            else:
                socketio.emit('interview_created', payload)
                current_app.logger.info("📊 WebSocket: Interview created event broadcasted")
        except Exception as e:
            current_app.logger.error(f"❌ WebSocket: Failed to emit interview_created: {e}")

    @staticmethod
    def emit_interview_updated(interview_data: Dict[str, Any], user_id: Optional[str] = None) -> None:
        """
        Emit interview_updated event to dashboard subscribers.
        
        Args:
            interview_data: Dictionary containing updated interview details
            user_id: Optional specific user to notify
        """
        try:
            payload = {
                'id': interview_data.get('id'),
                'job_title': interview_data.get('job_title'),
                'candidate_name': interview_data.get('candidate_name'),
                'scheduled_time': interview_data.get('scheduled_time'),
                'status': interview_data.get('status'),
                'old_status': interview_data.get('old_status'),
                'updated_at': interview_data.get('updated_at'),
            }
            
            if user_id:
                room = f'dashboard_{user_id}'
                socketio.emit('interview_updated', payload, room=room)
                current_app.logger.info(f"📊 WebSocket: Interview updated event sent to room {room}")
            else:
                socketio.emit('interview_updated', payload)
                current_app.logger.info("📊 WebSocket: Interview updated event broadcasted")
        except Exception as e:
            current_app.logger.error(f"❌ WebSocket: Failed to emit interview_updated: {e}")

    @staticmethod
    def emit_interview_deleted(interview_id: int, user_id: Optional[str] = None) -> None:
        """
        Emit interview_deleted event to dashboard subscribers.
        
        Args:
            interview_id: ID of the deleted interview
            user_id: Optional specific user to notify
        """
        try:
            payload = {'id': interview_id}
            
            if user_id:
                room = f'dashboard_{user_id}'
                socketio.emit('interview_deleted', payload, room=room)
                current_app.logger.info(f"📊 WebSocket: Interview deleted event sent to room {room}")
            else:
                socketio.emit('interview_deleted', payload)
                current_app.logger.info("📊 WebSocket: Interview deleted event broadcasted")
        except Exception as e:
            current_app.logger.error(f"❌ WebSocket: Failed to emit interview_deleted: {e}")

    @staticmethod
    def emit_meeting_created(meeting_data: Dict[str, Any], user_id: Optional[str] = None) -> None:
        """
        Emit meeting_created event to dashboard subscribers.
        
        Args:
            meeting_data: Dictionary containing meeting details
            user_id: Optional specific user to notify
        """
        try:
            payload = {
                'id': meeting_data.get('id'),
                'title': meeting_data.get('title'),
                'start_time': meeting_data.get('start_time'),
                'end_time': meeting_data.get('end_time'),
                'organizer_id': meeting_data.get('organizer_id'),
                'participants': meeting_data.get('participants', []),
                'created_at': meeting_data.get('created_at'),
            }
            
            if user_id:
                room = f'dashboard_{user_id}'
                socketio.emit('meeting_created', payload, room=room)
                current_app.logger.info(f"📊 WebSocket: Meeting created event sent to room {room}")
            else:
                socketio.emit('meeting_created', payload)
                current_app.logger.info("📊 WebSocket: Meeting created event broadcasted")
        except Exception as e:
            current_app.logger.error(f"❌ WebSocket: Failed to emit meeting_created: {e}")

    @staticmethod
    def emit_meeting_updated(meeting_data: Dict[str, Any], user_id: Optional[str] = None) -> None:
        """
        Emit meeting_updated event to dashboard subscribers.
        
        Args:
            meeting_data: Dictionary containing updated meeting details
            user_id: Optional specific user to notify
        """
        try:
            payload = {
                'id': meeting_data.get('id'),
                'title': meeting_data.get('title'),
                'start_time': meeting_data.get('start_time'),
                'end_time': meeting_data.get('end_time'),
                'status': meeting_data.get('status'),
                'updated_at': meeting_data.get('updated_at'),
            }
            
            if user_id:
                room = f'dashboard_{user_id}'
                socketio.emit('meeting_updated', payload, room=room)
                current_app.logger.info(f"📊 WebSocket: Meeting updated event sent to room {room}")
            else:
                socketio.emit('meeting_updated', payload)
                current_app.logger.info("📊 WebSocket: Meeting updated event broadcasted")
        except Exception as e:
            current_app.logger.error(f"❌ WebSocket: Failed to emit meeting_updated: {e}")

    @staticmethod
    def emit_job_status_changed(job_data: Dict[str, Any], user_id: Optional[str] = None) -> None:
        """
        Emit job_status_changed event to dashboard subscribers.
        
        Args:
            job_data: Dictionary containing job details and status change
            user_id: Optional specific user to notify
        """
        try:
            payload = {
                'id': job_data.get('id'),
                'title': job_data.get('title'),
                'department': job_data.get('department'),
                'status': job_data.get('status'),
                'old_status': job_data.get('old_status'),
                'updated_at': job_data.get('updated_at'),
            }
            
            if user_id:
                room = f'dashboard_{user_id}'
                socketio.emit('job_status_changed', payload, room=room)
                current_app.logger.info(f"📊 WebSocket: Job status changed event sent to room {room}")
            else:
                socketio.emit('job_status_changed', payload)
                current_app.logger.info("📊 WebSocket: Job status changed event broadcasted")
        except Exception as e:
            current_app.logger.error(f"❌ WebSocket: Failed to emit job_status_changed: {e}")

    @staticmethod
    def emit_cv_review_completed(review_data: Dict[str, Any], user_id: Optional[str] = None) -> None:
        """
        Emit cv_review_completed event to dashboard subscribers.
        
        Args:
            review_data: Dictionary containing CV review details
            user_id: Optional specific user to notify
        """
        try:
            payload = {
                'id': review_data.get('id'),
                'candidate_name': review_data.get('candidate_name'),
                'candidate_id': review_data.get('candidate_id'),
                'score': review_data.get('score'),
                'status': review_data.get('status'),
                'reviewed_at': review_data.get('reviewed_at'),
            }
            
            if user_id:
                room = f'dashboard_{user_id}'
                socketio.emit('cv_review_completed', payload, room=room)
                current_app.logger.info(f"📊 WebSocket: CV review completed event sent to room {room}")
            else:
                socketio.emit('cv_review_completed', payload)
                current_app.logger.info("📊 WebSocket: CV review completed event broadcasted")
        except Exception as e:
            current_app.logger.error(f"❌ WebSocket: Failed to emit cv_review_completed: {e}")

    @staticmethod
    def emit_candidate_applied(application_data: Dict[str, Any], user_id: Optional[str] = None) -> None:
        """
        Emit candidate_applied event to dashboard subscribers.
        
        Args:
            application_data: Dictionary containing application details
            user_id: Optional specific user to notify
        """
        try:
            payload = {
                'id': application_data.get('id'),
                'job_id': application_data.get('job_id'),
                'job_title': application_data.get('job_title'),
                'candidate_name': application_data.get('candidate_name'),
                'candidate_id': application_data.get('candidate_id'),
                'applied_at': application_data.get('applied_at'),
            }
            
            if user_id:
                room = f'dashboard_{user_id}'
                socketio.emit('candidate_applied', payload, room=room)
                current_app.logger.info(f"📊 WebSocket: Candidate applied event sent to room {room}")
            else:
                socketio.emit('candidate_applied', payload)
                current_app.logger.info("📊 WebSocket: Candidate applied event broadcasted")
        except Exception as e:
            current_app.logger.error(f"❌ WebSocket: Failed to emit candidate_applied: {e}")

    @staticmethod
    def emit_audit_created(audit_data: Dict[str, Any], user_id: Optional[str] = None) -> None:
        """
        Emit audit_created event to dashboard subscribers.
        
        Args:
            audit_data: Dictionary containing audit log details
            user_id: Optional specific user to notify
        """
        try:
            payload = {
                'id': audit_data.get('id'),
                'action': audit_data.get('action'),
                'user': audit_data.get('user'),
                'user_id': audit_data.get('user_id'),
                'target': audit_data.get('target'),
                'details': audit_data.get('details'),
                'timestamp': audit_data.get('timestamp'),
            }
            
            if user_id:
                room = f'dashboard_{user_id}'
                socketio.emit('audit_created', payload, room=room)
                current_app.logger.info(f"📊 WebSocket: Audit created event sent to room {room}")
            else:
                socketio.emit('audit_created', payload)
                current_app.logger.info("📊 WebSocket: Audit created event broadcasted")
        except Exception as e:
            current_app.logger.error(f"❌ WebSocket: Failed to emit audit_created: {e}")


# Convenience function shortcuts for easy import
def emit_interview_created(interview_data: Dict[str, Any], user_id: Optional[str] = None) -> None:
    """Shortcut to emit interview_created event."""
    DashboardWebSocketService.emit_interview_created(interview_data, user_id)

def emit_interview_updated(interview_data: Dict[str, Any], user_id: Optional[str] = None) -> None:
    """Shortcut to emit interview_updated event."""
    DashboardWebSocketService.emit_interview_updated(interview_data, user_id)

def emit_interview_deleted(interview_id: int, user_id: Optional[str] = None) -> None:
    """Shortcut to emit interview_deleted event."""
    DashboardWebSocketService.emit_interview_deleted(interview_id, user_id)

def emit_meeting_created(meeting_data: Dict[str, Any], user_id: Optional[str] = None) -> None:
    """Shortcut to emit meeting_created event."""
    DashboardWebSocketService.emit_meeting_created(meeting_data, user_id)

def emit_meeting_updated(meeting_data: Dict[str, Any], user_id: Optional[str] = None) -> None:
    """Shortcut to emit meeting_updated event."""
    DashboardWebSocketService.emit_meeting_updated(meeting_data, user_id)

def emit_job_status_changed(job_data: Dict[str, Any], user_id: Optional[str] = None) -> None:
    """Shortcut to emit job_status_changed event."""
    DashboardWebSocketService.emit_job_status_changed(job_data, user_id)

def emit_cv_review_completed(review_data: Dict[str, Any], user_id: Optional[str] = None) -> None:
    """Shortcut to emit cv_review_completed event."""
    DashboardWebSocketService.emit_cv_review_completed(review_data, user_id)

def emit_candidate_applied(application_data: Dict[str, Any], user_id: Optional[str] = None) -> None:
    """Shortcut to emit candidate_applied event."""
    DashboardWebSocketService.emit_candidate_applied(application_data, user_id)

def emit_audit_created(audit_data: Dict[str, Any], user_id: Optional[str] = None) -> None:
    """Shortcut to emit audit_created event."""
    DashboardWebSocketService.emit_audit_created(audit_data, user_id)
