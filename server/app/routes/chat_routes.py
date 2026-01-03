# routes/chat_routes.py
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from datetime import datetime
from app.services.chat_service import ChatService
from app.models import db, ChatThread

chat_bp = Blueprint('chat', __name__)

@chat_bp.route('/threads', methods=['GET'])
@jwt_required()
def get_threads():
    """Get all chat threads for current user"""
    try:
        user_id = get_jwt_identity()
        entity_type = request.args.get('entity_type')
        entity_id = request.args.get('entity_id')
        
        threads = ChatService.get_user_threads(user_id, entity_type, entity_id)
        return jsonify({
            'success': True,
            'threads': threads,
            'count': len(threads)
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@chat_bp.route('/threads', methods=['POST'])
@jwt_required()
def create_thread():
    """Create a new chat thread"""
    try:
        user_id = get_jwt_identity()
        data = request.get_json()
        
        if not data or 'title' not in data or 'participant_ids' not in data:
            return jsonify({'success': False, 'error': 'Missing required fields'}), 400
        
        # Ensure participant_ids is a list
        participant_ids = data['participant_ids']
        if not isinstance(participant_ids, list):
            participant_ids = [participant_ids]
        
        thread = ChatService.create_thread(
            title=data['title'],
            created_by=user_id,
            participant_ids=participant_ids,
            entity_type=data.get('entity_type', 'general'),
            entity_id=data.get('entity_id')
        )
        
        return jsonify({
            'success': True,
            'message': 'Thread created successfully',
            'thread': thread.to_dict_detailed()
        }), 201
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@chat_bp.route('/threads/<int:thread_id>', methods=['GET'])
@jwt_required()
def get_thread(thread_id):
    """Get specific thread details"""
    try:
        user_id = get_jwt_identity()
        
        thread = ChatThread.query.get_or_404(thread_id)
        
        # Verify user has access
        if not any(p.id == user_id for p in thread.participants):
            return jsonify({'success': False, 'error': 'Access denied'}), 403
        
        thread_data = thread.to_dict_detailed()
        
        return jsonify({
            'success': True,
            'thread': thread_data
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@chat_bp.route('/threads/<int:thread_id>/messages', methods=['GET'])
@jwt_required()
def get_messages(thread_id):
    """Get message history for a thread"""
    try:
        user_id = get_jwt_identity()
        
        limit = min(int(request.args.get('limit', 50)), 100)
        before = request.args.get('before')
        
        if before:
            try:
                before_dt = datetime.fromisoformat(before.replace('Z', '+00:00'))
            except ValueError:
                before_dt = None
        else:
            before_dt = None
        
        messages = ChatService.get_thread_messages(
            thread_id=thread_id,
            user_id=user_id,
            limit=limit,
            before=before_dt
        )
        
        return jsonify({
            'success': True,
            'messages': messages,
            'count': len(messages)
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@chat_bp.route('/threads/<int:thread_id>/messages', methods=['POST'])
@jwt_required()
def send_message(thread_id):
    """Send a new message"""
    try:
        user_id = get_jwt_identity()
        data = request.get_json()
        
        if not data or 'content' not in data:
            return jsonify({'success': False, 'error': 'Content is required'}), 400
        
        message = ChatService.send_message(
            thread_id=thread_id,
            sender_id=user_id,
            content=data['content'],
            message_type=data.get('message_type', 'text'),
            metadata=data.get('metadata')
        )
        
        return jsonify({
            'success': True,
            'message': 'Message sent successfully',
            'message_data': message.to_dict()
        }), 201
    except ValueError as e:
        return jsonify({'success': False, 'error': str(e)}), 403
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@chat_bp.route('/threads/<int:thread_id>/mark-read', methods=['POST'])
@jwt_required()
def mark_as_read(thread_id):
    """Mark messages as read"""
    try:
        user_id = get_jwt_identity()
        
        # Verify user has access to thread
        thread = ChatThread.query.get_or_404(thread_id)
        if not any(p.id == user_id for p in thread.participants):
            return jsonify({'success': False, 'error': 'Access denied'}), 403
        
        # Get last message in thread
        last_message = thread.messages.first()
        if last_message:
            from app.models import MessageReadStatus
            existing = MessageReadStatus.query.filter_by(
                message_id=last_message.id, 
                user_id=user_id
            ).first()
            
            if not existing:
                read_status = MessageReadStatus(
                    message_id=last_message.id,
                    user_id=user_id
                )
                db.session.add(read_status)
                db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Messages marked as read'
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@chat_bp.route('/search', methods=['GET'])
@jwt_required()
def search_messages():
    """Search messages across all chats"""
    try:
        user_id = get_jwt_identity()
        query = request.args.get('q', '').strip()
        thread_id = request.args.get('thread_id')
        
        if not query or len(query) < 2:
            return jsonify({'success': True, 'messages': []})
        
        messages = ChatService.search_messages(
            user_id=user_id,
            query=query,
            thread_id=int(thread_id) if thread_id else None
        )
        
        return jsonify({
            'success': True,
            'messages': messages,
            'count': len(messages)
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@chat_bp.route('/presence', methods=['POST'])
@jwt_required()
def update_presence():
    """Update user presence status"""
    try:
        user_id = get_jwt_identity()
        data = request.get_json()
        
        if not data or 'status' not in data:
            return jsonify({'success': False, 'error': 'Status is required'}), 400
        
        presence = ChatService.update_presence(
            user_id=user_id,
            status=data['status'],
            socket_id=data.get('socket_id')
        )
        
        return jsonify({
            'success': True,
            'presence': presence.to_dict()
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@chat_bp.route('/entity/<entity_type>/<entity_id>', methods=['GET'])
@jwt_required()
def get_entity_chat(entity_type, entity_id):
    """Get or create entity-specific chat thread"""
    try:
        user_id = get_jwt_identity()
        
        thread = ChatService.get_or_create_entity_thread(
            entity_type=entity_type,
            entity_id=entity_id,
            user_id=user_id
        )
        
        thread_data = thread.to_dict_detailed()
        
        return jsonify({
            'success': True,
            'thread': thread_data
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500