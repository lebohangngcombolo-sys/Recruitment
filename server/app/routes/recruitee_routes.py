"""
Recruitee Integration Routes - Admin API for ATS sync
"""
from __future__ import annotations

from flask import Blueprint, jsonify, request, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity
from datetime import datetime

from app.extensions import db
from app.models import Requisition, Candidate, Application, User, RecruiteeWebhookLog
from app.services.recruitee_client import RecruiteeClient, RecruiteeAPIError
from app.services.recruitee_service import RecruiteeService
from app.services.recruitee_mapper import requisition_to_offer, candidate_to_recruitee
from app.tasks.recruitee_webhook_tasks import process_recruitee_webhook

recruitee_bp = Blueprint('recruitee', __name__)


def _check_admin_access():
    """Verify the current user is an admin"""
    user_id = get_jwt_identity()
    user = User.query.get(user_id)
    if not user or user.role != 'admin':
        return False, "Admin access required"
    return True, user


# ==================== CONNECTION MANAGEMENT ====================

@recruitee_bp.route('/api/admin/integrations/recruitee/status', methods=['GET'])
@jwt_required()
def get_recruitee_status():
    """Get Recruitee integration status and test connection"""
    is_admin, result = _check_admin_access()
    if not is_admin:
        return jsonify({'error': result}), 403
    
    enabled = current_app.config.get('RECRUITEE_ENABLED', False)
    company_id = current_app.config.get('RECRUITEE_COMPANY_ID', '')
    has_token = bool(current_app.config.get('RECRUITEE_API_TOKEN', ''))
    
    status = {
        'enabled': enabled,
        'configured': bool(company_id and has_token),
        'company_id': company_id if company_id else None,
        'connected': False,
        'error': None
    }
    
    if not enabled:
        status['error'] = 'Recruitee integration is disabled'
        return jsonify(status), 200
    
    if not status['configured']:
        status['error'] = 'Recruitee not configured. Set RECRUITEE_COMPANY_ID and RECRUITEE_API_TOKEN'
        return jsonify(status), 200
    
    # Test connection
    try:
        service = RecruiteeService()
        connected, error = service.test_connection()
        status['connected'] = connected
        if error:
            status['error'] = error
    except Exception as e:
        status['error'] = str(e)
    
    return jsonify(status), 200


@recruitee_bp.route('/api/admin/integrations/recruitee/test', methods=['POST'])
@jwt_required()
def test_recruitee_connection():
    """Test Recruitee connection with provided credentials"""
    is_admin, result = _check_admin_access()
    if not is_admin:
        return jsonify({'error': result}), 403
    
    data = request.get_json() or {}
    company_id = data.get('company_id') or current_app.config.get('RECRUITEE_COMPANY_ID')
    api_token = data.get('api_token') or current_app.config.get('RECRUITEE_API_TOKEN')
    
    if not company_id or not api_token:
        return jsonify({'error': 'company_id and api_token required'}), 400
    
    try:
        client = RecruiteeClient(company_id=company_id, api_token=api_token)
        offers = client.get_offers(limit=1)
        return jsonify({
            'success': True,
            'message': f'Connection successful. Found {len(offers.get("offers", []))} offers.',
            'company_id': company_id
        }), 200
    except RecruiteeAPIError as e:
        return jsonify({
            'success': False,
            'error': e.message,
            'status_code': e.status_code
        }), 400
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


# ==================== JOB SYNC ====================

@recruitee_bp.route('/api/admin/integrations/recruitee/sync/jobs', methods=['POST'])
@jwt_required()
def sync_jobs_to_recruitee():
    """Sync selected or all jobs to Recruitee"""
    is_admin, result = _check_admin_access()
    if not is_admin:
        return jsonify({'error': result}), 403
    
    if not current_app.config.get('RECRUITEE_ENABLED'):
        return jsonify({'error': 'Recruitee integration is disabled'}), 400
    
    data = request.get_json() or {}
    job_ids = data.get('job_ids')  # Optional: specific job IDs
    only_active = data.get('only_active', True)
    
    try:
        service = RecruiteeService()
        
        if job_ids:
            # Sync specific jobs (only approved ones)
            jobs = Requisition.query.filter(
                Requisition.id.in_(job_ids),
                Requisition.approval_status == 'approved'
            ).all()
        else:
            # Sync all approved jobs marked for sync
            query = Requisition.query.filter_by(
                sync_to_recruitee=True,
                approval_status='approved'
            )
            if only_active:
                query = query.filter_by(is_active=True)
            jobs = query.all()
        
        results = []
        for job in jobs:
            result = service.sync_job_to_recruitee(job)
            # Add job context to result
            result['job_title'] = job.title
            result['job_id'] = job.id
            results.append(result)
        
        success_count = sum(1 for r in results if r.get('success'))
        failed_count = len(results) - success_count
        
        # Aggregate errors for summary
        errors = [r for r in results if not r.get('success') and r.get('error')]
        
        return jsonify({
            'success': True,
            'total': len(results),
            'successful': success_count,
            'failed': failed_count,
            'errors': [{'job_id': e['job_id'], 'job_title': e['job_title'], 'error': e['error']} 
                      for e in errors[:5]],  # Limit to first 5 errors
            'results': results
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@recruitee_bp.route('/api/admin/integrations/recruitee/jobs/<int:job_id>/sync', methods=['POST'])
@jwt_required()
def sync_single_job(job_id: int):
    """Sync a single job to Recruitee"""
    is_admin, result = _check_admin_access()
    if not is_admin:
        return jsonify({'error': result}), 403
    
    if not current_app.config.get('RECRUITEE_ENABLED'):
        return jsonify({'error': 'Recruitee integration is disabled'}), 400
    
    job = Requisition.query.get_or_404(job_id)
    
    # Only allow syncing approved jobs
    if job.approval_status != 'approved':
        return jsonify({
            'success': False,
            'error': 'Only approved jobs can be synced to Recruitee',
            'job_id': job_id,
            'approval_status': job.approval_status
        }), 400
    
    try:
        service = RecruiteeService()
        result = service.sync_job_to_recruitee(job)
        
        if result.get('success'):
            return jsonify({
                'success': True,
                'job_id': job_id,
                'recruitee_id': result.get('external_id'),
                'action': result.get('action'),
                'recruitee_url': job.get_recruitee_url()
            }), 200
        else:
            return jsonify({
                'success': False,
                'error': result.get('error'),
                'job_id': job_id
            }), 400
            
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@recruitee_bp.route('/api/admin/integrations/recruitee/jobs/<int:job_id>/toggle-sync', methods=['POST'])
@jwt_required()
def toggle_job_sync(job_id: int):
    """Toggle sync_to_recruitee flag for a job"""
    is_admin, result = _check_admin_access()
    if not is_admin:
        return jsonify({'error': result}), 403
    
    job = Requisition.query.get_or_404(job_id)
    data = request.get_json() or {}
    
    # Toggle or set explicit value
    if 'sync' in data:
        job.sync_to_recruitee = bool(data['sync'])
    else:
        job.sync_to_recruitee = not job.sync_to_recruitee
    
    db.session.commit()
    
    return jsonify({
        'success': True,
        'job_id': job_id,
        'sync_to_recruitee': job.sync_to_recruitee
    }), 200


# ==================== CANDIDATE SYNC ====================

@recruitee_bp.route('/api/admin/integrations/recruitee/sync/candidates', methods=['POST'])
@jwt_required()
def sync_candidates_to_recruitee():
    """Sync candidates to Recruitee"""
    is_admin, result = _check_admin_access()
    if not is_admin:
        return jsonify({'error': result}), 403
    
    if not current_app.config.get('RECRUITEE_ENABLED'):
        return jsonify({'error': 'Recruitee integration is disabled'}), 400
    
    data = request.get_json() or {}
    candidate_ids = data.get('candidate_ids')
    job_id = data.get('job_id')  # Optional: only sync for specific job
    
    try:
        service = RecruiteeService()
        
        if job_id:
            # Sync all candidates who applied to this job
            job = Requisition.query.get_or_404(job_id)
            results = service.sync_job_candidates(job)
        elif candidate_ids:
            # Sync specific candidates
            candidates = Candidate.query.filter(Candidate.id.in_(candidate_ids)).all()
            results = []
            for candidate in candidates:
                result = service.sync_candidate_to_recruitee(candidate)
                results.append(result)
        else:
            return jsonify({'error': 'Provide candidate_ids or job_id'}), 400
        
        success_count = sum(1 for r in results if r.get('success'))
        
        return jsonify({
            'success': True,
            'total': len(results),
            'successful': success_count,
            'failed': len(results) - success_count,
            'results': results
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@recruitee_bp.route('/api/admin/integrations/recruitee/candidates/<int:candidate_id>/sync', methods=['POST'])
@jwt_required()
def sync_single_candidate(candidate_id: int):
    """Sync a single candidate to Recruitee"""
    is_admin, result = _check_admin_access()
    if not is_admin:
        return jsonify({'error': result}), 403
    
    if not current_app.config.get('RECRUITEE_ENABLED'):
        return jsonify({'error': 'Recruitee integration is disabled'}), 400
    
    candidate = Candidate.query.get_or_404(candidate_id)
    
    # Get optional application context
    data = request.get_json() or {}
    application_id = data.get('application_id')
    application = None
    if application_id:
        application = Application.query.get(application_id)
    
    try:
        service = RecruiteeService()
        result = service.sync_candidate_to_recruitee(candidate, application)
        
        if result.get('success'):
            return jsonify({
                'success': True,
                'candidate_id': candidate_id,
                'recruitee_id': result.get('external_id'),
                'action': result.get('action')
            }), 200
        else:
            return jsonify({
                'success': False,
                'error': result.get('error'),
                'candidate_id': candidate_id
            }), 400
            
    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ==================== PULL FROM RECRUITEE ====================

@recruitee_bp.route('/api/admin/integrations/recruitee/pull/jobs', methods=['POST'])
@jwt_required()
def pull_jobs_from_recruitee():
    """Pull jobs from Recruitee to link with local jobs"""
    is_admin, result = _check_admin_access()
    if not is_admin:
        return jsonify({'error': result}), 403
    
    if not current_app.config.get('RECRUITEE_ENABLED'):
        return jsonify({'error': 'Recruitee integration is disabled'}), 400
    
    try:
        service = RecruiteeService()
        results = service.pull_jobs_from_recruitee()
        
        linked = sum(1 for r in results if r.get('action') == 'linked')
        
        return jsonify({
            'success': True,
            'total': len(results),
            'linked': linked,
            'skipped': len(results) - linked,
            'results': results
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ==================== WEBHOOK HANDLER ====================

@recruitee_bp.route('/webhooks/recruitee', methods=['POST'])
def handle_recruitee_webhook():
    """Handle incoming webhooks from Recruitee - queue async processing"""
    webhook_secret = current_app.config.get('RECRUITEE_WEBHOOK_SECRET', '')
    
    # Verify signature if secret is configured
    if webhook_secret:
        signature = request.headers.get('X-Recruitee-Signature', '')
        
        service = RecruiteeService()
        raw_payload = request.get_data()
        
        if not service.verify_webhook_signature(raw_payload, signature, webhook_secret):
            current_app.logger.warning("Invalid webhook signature received")
            return jsonify({'error': 'Invalid webhook signature'}), 401
    
    payload = request.get_json() or {}
    event_type = payload.get('event') or payload.get('type') or payload.get('event_type') or 'unknown'
    data = payload.get('data', payload)
    
    # Use provided event ID, or generate a safe one for verification/unknown events
    event_id = payload.get('event_id') or payload.get('id') or f"evt_{datetime.utcnow().timestamp()}"
    
    current_app.logger.info(f"Recruitee webhook received: {event_type} (event_id: {event_id})")
    
    try:
        # Check idempotency - has this event already been processed?
        existing_log = RecruiteeWebhookLog.query.filter_by(event_id=event_id).first()
        if existing_log and existing_log.processed:
            current_app.logger.info(f"Event {event_id} already processed, skipping")
            return jsonify({'success': True, 'skipped': True, 'reason': 'already_processed'}), 200
        
        # Log the webhook for debugging and idempotency
        webhook_log = RecruiteeWebhookLog(
            event_id=event_id,
            event_type=event_type,
            raw_payload=payload,
            processing_status='pending'
        )
        db.session.add(webhook_log)
        db.session.commit()
        
        # Queue async processing or run immediately in eager mode
        if current_app.config.get('CELERY_TASK_ALWAYS_EAGER'):
            current_app.logger.info("Running webhook task synchronously (CELERY_TASK_ALWAYS_EAGER=true)")
            process_recruitee_webhook(event_type, data, event_id, webhook_log.id)
            task_id = f"local_{event_id}"
        else:
            task = process_recruitee_webhook.delay(event_type, data, event_id, webhook_log.id)
            task_id = task.id
            current_app.logger.info(f"Webhook queued for async processing: task_id={task_id}")
        
        # Return 200 OK immediately - Recruitee doesn't need to wait
        return jsonify({
            'success': True,
            'event': event_type,
            'queued': not current_app.config.get('CELERY_TASK_ALWAYS_EAGER'),
            'task_id': task_id
        }), 200
        
    except Exception as e:
        current_app.logger.error(f"Webhook processing error: {e}")
        return jsonify({'error': str(e)}), 500


# ==================== SYNC HISTORY & RETRY ====================

@recruitee_bp.route('/api/admin/integrations/recruitee/sync-history', methods=['GET'])
@jwt_required()
def get_sync_history():
    """Query sync history for audit and troubleshooting"""
    is_admin, result = _check_admin_access()
    if not is_admin:
        return jsonify({'error': result}), 403
    
    entity_type = request.args.get('entity_type')  # 'job' or 'candidate'
    entity_id = request.args.get('entity_id', type=int)
    status = request.args.get('status')  # 'success', 'failed', 'pending', 'skipped'
    limit = request.args.get('limit', 50, type=int)
    
    try:
        service = RecruiteeService()
        history = service.get_sync_history(
            entity_type=entity_type,
            entity_id=entity_id,
            status=status,
            limit=min(limit, 100)  # Cap at 100
        )
        
        return jsonify({
            'success': True,
            'count': len(history),
            'history': history
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@recruitee_bp.route('/api/admin/integrations/recruitee/process-retries', methods=['POST'])
@jwt_required()
def process_retries():
    """Manually trigger processing of pending retries"""
    is_admin, result = _check_admin_access()
    if not is_admin:
        return jsonify({'error': result}), 403
    
    try:
        service = RecruiteeService()
        results = service.process_pending_retries()
        
        return jsonify({
            'success': True,
            'processed': len(results),
            'results': results
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ==================== UTILITY ====================

@recruitee_bp.route('/api/admin/integrations/recruitee/offers', methods=['GET'])
@jwt_required()
def list_recruitee_offers():
    """List offers directly from Recruitee API"""
    is_admin, result = _check_admin_access()
    if not is_admin:
        return jsonify({'error': result}), 403
    
    if not current_app.config.get('RECRUITEE_ENABLED'):
        return jsonify({'error': 'Recruitee integration is disabled'}), 400
    
    status = request.args.get('status', 'published')
    
    try:
        client = RecruiteeClient()
        offers = client.get_offers(status=status)
        
        return jsonify({
            'success': True,
            'count': len(offers.get('offers', [])),
            'offers': offers.get('offers', [])
        }), 200
        
    except RecruiteeAPIError as e:
        return jsonify({'error': e.message}), 400
    except Exception as e:
        return jsonify({'error': str(e)}), 500
