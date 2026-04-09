"""
Celery tasks for Recruitee webhook processing.
Allows async processing of webhook events to avoid blocking responses.
"""
from __future__ import annotations

import logging
from celery import shared_task
from app import db
from app.models import RecruiteeWebhookLog
from app.services.recruitee_webhook_processor import RecruiteeWebhookProcessor

logger = logging.getLogger(__name__)


@shared_task(bind=True, max_retries=3)
def process_recruitee_webhook(self, event_type: str, data: dict, event_id: str, log_id: int = None):
    """Process Recruitee webhook asynchronously
    
    Args:
        event_type: Recruitee event type (candidate.created, candidate.updated, etc.)
        data: Event payload data
        event_id: Unique Recruitee event ID for idempotency
        log_id: Optional webhook log ID to update
        
    Returns:
        Dict with processing result
    """
    logger.info(f"Processing Recruitee webhook task: {event_type} (event_id: {event_id})")
    
    # Get webhook log record if provided
    webhook_log = None
    if log_id:
        webhook_log = RecruiteeWebhookLog.query.get(log_id)
    
    try:
        # Process the event
        processor = RecruiteeWebhookProcessor()
        result = processor.handle_event(event_type, data, event_id)
        
        # Update webhook log if exists
        if webhook_log:
            status = 'success' if result.get('success') else 'failed'
            error = result.get('error') if not result.get('success') else None
            webhook_log.mark_processed(status=status, error=error)
        
        logger.info(f"Webhook processed successfully: {event_type}")
        return result
        
    except Exception as e:
        logger.exception(f"Error processing webhook {event_type}: {e}")
        
        # Update webhook log with error
        if webhook_log:
            webhook_log.mark_processed(status='failed', error=str(e))
        
        # Retry with exponential backoff
        if self.request.retries < self.max_retries:
            raise self.retry(countdown=60 * (2 ** self.request.retries))
        
        return {
            'success': False,
            'error': str(e),
            'event_type': event_type,
            'event_id': event_id
        }


@shared_task
def cleanup_old_webhook_logs(days_old: int = 30):
    """Clean up old webhook logs to prevent database bloat
    
    Args:
        days_old: Delete logs older than this many days
    """
    from datetime import datetime, timedelta
    
    cutoff_date = datetime.utcnow() - timedelta(days=days_old)
    
    try:
        deleted = RecruiteeWebhookLog.query.filter(
            RecruiteeWebhookLog.created_at < cutoff_date
        ).delete()
        
        db.session.commit()
        logger.info(f"Cleaned up {deleted} old webhook logs (older than {days_old} days)")
        
        return {'deleted': deleted, 'days_old': days_old}
        
    except Exception as e:
        db.session.rollback()
        logger.error(f"Failed to cleanup webhook logs: {e}")
        return {'error': str(e)}


@shared_task
def retry_failed_webhooks():
    """Retry webhooks that failed to process
    
    This task should be scheduled periodically (e.g., every 5 minutes)
    """
    try:
        # Find failed webhooks that haven't been retried too many times
        failed_logs = RecruiteeWebhookLog.query.filter(
            RecruiteeWebhookLog.processing_status == 'failed',
            RecruiteeWebhookLog.processed == True
        ).limit(10).all()
        
        retried_count = 0
        
        for log in failed_logs:
            # Extract event info from raw payload
            event_type = log.event_type
            data = log.raw_payload
            event_id = log.event_id
            
            # Reset for retry
            log.processed = False
            log.processing_status = 'pending'
            log.error_message = None
            log.processed_at = None
            
            # Queue for processing
            process_recruitee_webhook.delay(event_type, data, event_id, log.id)
            retried_count += 1
        
        db.session.commit()
        
        logger.info(f"Retrying {retried_count} failed webhooks")
        
        return {'retried': retried_count}
        
    except Exception as e:
        db.session.rollback()
        logger.error(f"Failed to retry failed webhooks: {e}")
        return {'error': str(e)}
