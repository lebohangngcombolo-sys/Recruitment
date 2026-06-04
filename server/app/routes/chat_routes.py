# routes/chat_routes.py
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from datetime import datetime, timedelta
from app.services.chat_service import ChatService
from app.models import db, ChatThread, Meeting, User
from app.services.notification_service import create_notification

chat_bp = Blueprint('chat', __name__)

def _get_user_id():
    user_id = get_jwt_identity()
    try:
        return int(user_id)
    except (TypeError, ValueError):
        return None

@chat_bp.route('/threads', methods=['GET'])
@jwt_required()
def get_threads():
    """Get all chat threads for current user"""
    try:
        user_id = _get_user_id()
        if user_id is None:
            return jsonify({'success': False, 'error': 'Invalid user identity'}), 401
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
        user_id = _get_user_id()
        if user_id is None:
            return jsonify({'success': False, 'error': 'Invalid user identity'}), 401
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
        user_id = _get_user_id()
        if user_id is None:
            return jsonify({'success': False, 'error': 'Invalid user identity'}), 401
        
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
        user_id = _get_user_id()
        if user_id is None:
            return jsonify({'success': False, 'error': 'Invalid user identity'}), 401
        
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
        user_id = _get_user_id()
        if user_id is None:
            return jsonify({'success': False, 'error': 'Invalid user identity'}), 401
        data = request.get_json()
        
        if not data or 'content' not in data:
            return jsonify({'success': False, 'error': 'Content is required'}), 400
        
        parent_message_id = data.get('parent_message_id')
        if parent_message_id is not None:
            try:
                parent_message_id = int(parent_message_id)
            except (ValueError, TypeError):
                return jsonify({'success': False, 'error': 'Invalid parent message ID format'}), 400

        message = ChatService.send_message(
            thread_id=thread_id,
            sender_id=user_id,
            content=data['content'],
            message_type=data.get('message_type', 'text'),
            metadata=data.get('metadata'),
            parent_message_id=parent_message_id
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
        user_id = _get_user_id()
        if user_id is None:
            return jsonify({'success': False, 'error': 'Invalid user identity'}), 401
        
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
        user_id = _get_user_id()
        if user_id is None:
            return jsonify({'success': False, 'error': 'Invalid user identity'}), 401
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
        user_id = _get_user_id()
        if user_id is None:
            return jsonify({'success': False, 'error': 'Invalid user identity'}), 401
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
        user_id = _get_user_id()
        if user_id is None:
            return jsonify({'success': False, 'error': 'Invalid user identity'}), 401
        
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


# ------------------- MEETING ENDPOINTS -------------------

@chat_bp.route('/meetings', methods=['POST'])
@jwt_required()
def create_meeting():
    """Create a new meeting"""
    try:
        user_id = _get_user_id()
        if user_id is None:
            return jsonify({'success': False, 'error': 'Invalid user identity'}), 401
        
        data = request.get_json()
        if not data:
            return jsonify({'success': False, 'error': 'No data provided'}), 400
        
        title = data.get('title')
        scheduled_at_str = data.get('scheduled_at')
        participant_ids = data.get('participant_ids', [])
        
        if not title or not scheduled_at_str:
            return jsonify({'success': False, 'error': 'Title and scheduled_at are required'}), 400
        
        try:
            scheduled_at = datetime.fromisoformat(scheduled_at_str.replace('Z', '+00:00'))
        except ValueError:
            return jsonify({'success': False, 'error': 'Invalid scheduled_at format'}), 400
        
        if scheduled_at < datetime.utcnow():
            return jsonify({'success': False, 'error': 'Meeting cannot be scheduled in the past'}), 400
        
        # Create meeting
        meeting = Meeting(
            title=title,
            description=data.get('description'),
            scheduled_at=scheduled_at,
            duration_minutes=data.get('duration_minutes', 60),
            location=data.get('location'),
            created_by=user_id,
            thread_id=data.get('thread_id')
        )
        
        db.session.add(meeting)
        db.session.flush()
        
        # Add participants (including creator)
        all_participant_ids = list(set(participant_ids + [user_id]))
        
        # Add participants to association table
        for pid in all_participant_ids:
            db.session.execute(
                db.text("INSERT INTO meeting_participants (meeting_id, user_id, status, notified_at) VALUES (:meeting_id, :user_id, :status, :notified_at)"),
                {
                    'meeting_id': meeting.id,
                    'user_id': pid,
                    'status': 'accepted' if pid == user_id else 'pending',
                    'notified_at': datetime.utcnow() if pid != user_id else None
                }
            )
        
        db.session.commit()
        
        # Notify participants (except creator)
        creator = User.query.get(user_id)
        for pid in participant_ids:
            if pid != user_id:
                create_notification(
                    user_id=pid,
                    message=f'{creator.full_name or creator.email} invited you to "{title}"'
                )
                
                # Send real-time meeting invite
                from app.extensions import socketio
                socketio.emit('meeting_invite', {
                    'type': 'meeting_invite',
                    'meeting': meeting.to_dict()
                }, room=f'user_{pid}')
        
        # Emit dashboard event for meeting creation
        from app.websocket_handler import emit_meeting_created
        emit_meeting_created({
            'id': meeting.id,
            'title': meeting.title,
            'start_time': meeting.scheduled_at.isoformat() if meeting.scheduled_at else None,
            'end_time': meeting.scheduled_at.isoformat() if meeting.scheduled_at else None,
            'organizer_id': meeting.created_by,
            'participants': participant_ids,
            'created_at': meeting.created_at.isoformat() if meeting.created_at else None
        }, user_id=str(meeting.created_by))

        return jsonify({
            'success': True,
            'message': 'Meeting created successfully',
            'meeting': meeting.to_dict()
        }), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'error': str(e)}), 500


@chat_bp.route('/meetings/<int:meeting_id>/respond', methods=['POST'])
@jwt_required()
def respond_to_meeting(meeting_id):
    """Respond to meeting invitation (accept/decline/maybe)"""
    try:
        user_id = _get_user_id()
        if user_id is None:
            return jsonify({'success': False, 'error': 'Invalid user identity'}), 401
        
        data = request.get_json()
        status = data.get('status')  # accepted, declined, maybe
        
        if status not in ['accepted', 'declined', 'maybe']:
            return jsonify({'success': False, 'error': 'Invalid status'}), 400
        
        # Update participant status
        result = db.session.execute(
            db.text("UPDATE meeting_participants SET status = :status WHERE meeting_id = :meeting_id AND user_id = :user_id"),
            {'status': status, 'meeting_id': meeting_id, 'user_id': user_id}
        )
        
        if result.rowcount == 0:
            return jsonify({'success': False, 'error': 'Not a participant'}), 403
        
        db.session.commit()
        
        # Notify meeting creator
        meeting = Meeting.query.get(meeting_id)
        if meeting and meeting.created_by != user_id:
            responder = User.query.get(user_id)
            create_notification(
                user_id=meeting.created_by,
                message=f'{responder.full_name or responder.email} {status} your meeting invitation for "{meeting.title}"'
            )
            
            # Send real-time response notification
            from app.extensions import socketio
            socketio.emit('meeting_response', {
                'type': 'meeting_response',
                'meeting_id': meeting_id,
                'user_id': user_id,
                'status': status,
                'user_name': responder.full_name or responder.email
            }, room=f'user_{meeting.created_by}')
            
            # Emit dashboard event for meeting update
            from app.websocket_handler import emit_meeting_updated
            emit_meeting_updated({
                'id': meeting.id,
                'title': meeting.title,
                'start_time': meeting.scheduled_at.isoformat() if meeting.scheduled_at else None,
                'end_time': meeting.scheduled_at.isoformat() if meeting.scheduled_at else None,
                'status': status,
                'updated_at': datetime.utcnow().isoformat()
            }, user_id=str(meeting.created_by))
        
        return jsonify({
            'success': True,
            'message': f'Meeting {status} successfully'
        })
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'error': str(e)}), 500


@chat_bp.route('/meetings', methods=['GET'])
@jwt_required()
def get_meetings():
    """Get meetings for current user"""
    try:
        user_id = _get_user_id()
        if user_id is None:
            return jsonify({'success': False, 'error': 'Invalid user identity'}), 401
        
        # Get meetings where user is a participant
        meetings = db.session.execute(
            db.text("""
                SELECT m.* FROM meetings m
                JOIN meeting_participants mp ON m.id = mp.meeting_id
                WHERE mp.user_id = :user_id
                ORDER BY m.scheduled_at ASC
            """),
            {'user_id': user_id}
        ).fetchall()
        
        meeting_list = []
        for row in meetings:
            meeting = Meeting.query.get(row.id)
            if meeting:
                meeting_dict = meeting.to_dict()
                # Add user's response status
                participant_status = db.session.execute(
                    db.text("SELECT status FROM meeting_participants WHERE meeting_id = :meeting_id AND user_id = :user_id"),
                    {'meeting_id': meeting.id, 'user_id': user_id}
                ).scalar()
                meeting_dict['user_status'] = participant_status
                meeting_list.append(meeting_dict)
        
        return jsonify({
            'success': True,
            'meetings': meeting_list
        })
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@chat_bp.route('/meetings/upcoming', methods=['GET'])
@jwt_required()
def get_upcoming_meetings():
    """Get upcoming meetings for current user (next 7 days)"""
    try:
        user_id = _get_user_id()
        if user_id is None:
            return jsonify({'success': False, 'error': 'Invalid user identity'}), 401
        
        start_time = datetime.utcnow()
        end_time = start_time + timedelta(days=7)
        
        # Get upcoming meetings where user is a participant
        meetings = db.session.execute(
            db.text("""
                SELECT m.* FROM meetings m
                JOIN meeting_participants mp ON m.id = mp.meeting_id
                WHERE mp.user_id = :user_id 
                AND m.scheduled_at BETWEEN :start_time AND :end_time
                AND mp.status != 'declined'
                ORDER BY m.scheduled_at ASC
            """),
            {'user_id': user_id, 'start_time': start_time, 'end_time': end_time}
        ).fetchall()
        
        meeting_list = []
        for row in meetings:
            meeting = Meeting.query.get(row.id)
            if meeting:
                meeting_dict = meeting.to_dict()
                # Add user's response status
                participant_status = db.session.execute(
                    db.text("SELECT status FROM meeting_participants WHERE meeting_id = :meeting_id AND user_id = :user_id"),
                    {'meeting_id': meeting.id, 'user_id': user_id}
                ).scalar()
                meeting_dict['user_status'] = participant_status
                meeting_list.append(meeting_dict)
        
        return jsonify({
            'success': True,
            'meetings': meeting_list
        })
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500