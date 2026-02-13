
import jwt
from functools import wraps
from datetime import datetime
from typing import Dict, Any, Optional
from flask import request, current_app
from flask_socketio import emit, join_room, leave_room, disconnect
from app.extensions import socketio, db
from app.models import User
from app.services.chat_service import ChatService


def socket_auth_required(f):
    """
    Decorator for WebSocket authentication
    
    Validates JWT token and sets request.user_id as integer
    """
    @wraps(f)
    def decorated(*args, **kwargs):
        try:
            # Get token from query parameters
            token = request.args.get('token')
            if not token:
                current_app.logger.error("❌ WebSocket: No token provided")
                emit('error', {'message': 'Authentication required'})
                disconnect()
                return
            
            # Remove 'Bearer ' prefix if present
            if token.startswith('Bearer '):
                token = token[7:]
            
            current_app.logger.debug(f"🔐 WebSocket: Authenticating with token...")
            
            # Decode JWT token
            payload = jwt.decode(
                token,
                current_app.config['JWT_SECRET_KEY'],
                algorithms=['HS256']
            )
            
            # Get user ID from payload
            user_id_claim = payload.get('sub')
            if not user_id_claim:
                current_app.logger.error("❌ WebSocket: No user ID in token")
                emit('error', {'message': 'Invalid token: No user ID'})
                disconnect()
                return
            
            # Convert user_id to integer
            try:
                request.user_id = int(user_id_claim)
                current_app.logger.debug(
                    f"✅ WebSocket: User ID {user_id_claim} -> {request.user_id} (int)"
                )
            except (ValueError, TypeError) as e:
                current_app.logger.error(f"❌ WebSocket: Invalid user ID format: {user_id_claim}")
                emit('error', {'message': f'Invalid user ID format: {user_id_claim}'})
                disconnect()
                return
            
            # Verify user exists and is active
            user = User.query.get(request.user_id)
            if not user:
                current_app.logger.error(f"❌ WebSocket: User {request.user_id} not found")
                emit('error', {'message': 'User not found'})
                disconnect()
                return
            
            if not getattr(user, 'is_active', True):
                current_app.logger.error(f"❌ WebSocket: User {request.user_id} is inactive")
                emit('error', {'message': 'User account is inactive'})
                disconnect()
                return
            
            current_app.logger.info(f"✅ WebSocket: User {request.user_id} authenticated successfully")
            return f(*args, **kwargs)
            
        except jwt.ExpiredSignatureError:
            current_app.logger.error("❌ WebSocket: Token expired")
            emit('error', {'message': 'Token expired'})
            disconnect()
            return
        except jwt.InvalidTokenError as e:
            current_app.logger.error(f"❌ WebSocket: Invalid token: {e}")
            emit('error', {'message': f'Invalid token: {str(e)}'})
            disconnect()
            return
        except Exception as e:
            current_app.logger.error(f"❌ WebSocket: Authentication error: {e}")
            emit('error', {'message': 'Authentication failed'})
            disconnect()
            return
    return decorated


def register_websocket_handlers(app):
    """Register all WebSocket event handlers"""
    
    @socketio.on('connect')
    @socket_auth_required
    def handle_connect(*args, **kwargs):
        """Handle WebSocket connection (accepts auth/args from Flask-SocketIO)"""
        try:
            user_id = request.user_id
            
            # Join user's personal room for private messages
            join_room(f'user_{user_id}')
            current_app.logger.info(f"✅ User {user_id} joined personal room")
            
            # Update user presence to online
            ChatService.update_presence(
                user_id=user_id,
                status='online',
                socket_id=request.sid
            )
            
            # Join all user's existing chat threads
            user = User.query.get(user_id)
            if user and hasattr(user, 'chat_threads'):
                for thread in user.chat_threads:
                    thread_id = thread.id
                    join_room(f'thread_{thread_id}')
                    current_app.logger.debug(
                        f"📨 User {user_id} auto-joined thread {thread_id}"
                    )
            
            # Send connection confirmation
            emit('connected', {
                'success': True,
                'user_id': user_id,
                'socket_id': request.sid,
                'timestamp': datetime.utcnow().isoformat(),
                'message': 'Successfully connected to chat server'
            })
            
            current_app.logger.info(
                f"✅ WebSocket connected: User {user_id}, SID {request.sid}"
            )
            
        except Exception as e:
            current_app.logger.error(f"❌ Connection error for user: {e}")
            emit('error', {
                'message': 'Connection failed',
                'error': str(e)
            })
            disconnect()
    
    @socketio.on('disconnect')
    def handle_disconnect():
        """Handle WebSocket disconnection"""
        try:
            # Note: We can't use @socket_auth_required here as token might not be available
            
            # Try to find user by socket ID from presence records
            from app.models import UserPresence
            presence = UserPresence.query.filter_by(socket_id=request.sid).first()
            
            if presence:
                user_id = presence.user_id
                
                # Update presence to offline
                ChatService.update_presence(
                    user_id=user_id,
                    status='offline'
                )
                
                current_app.logger.info(f"🔴 User {user_id} disconnected")
            else:
                current_app.logger.warning(f"🔴 Unknown client disconnected: {request.sid}")
                
        except Exception as e:
            current_app.logger.error(f"❌ Disconnect error: {e}")
    
    @socketio.on('join_thread')
    @socket_auth_required
    def handle_join_thread(data: Dict[str, Any]):
        """Join a specific chat thread room"""
        try:
            user_id = request.user_id
            thread_id_raw = data.get('thread_id')
            
            if not thread_id_raw:
                emit('error', {'message': 'Thread ID is required'})
                return
            
            # Convert thread_id to integer
            try:
                thread_id = int(thread_id_raw)
            except (ValueError, TypeError):
                emit('error', {'message': 'Invalid thread ID format'})
                return
            
            # Verify thread exists and user has access
            thread_data = ChatService.get_thread_details(thread_id, user_id)
            if not thread_data:
                emit('error', {'message': 'Thread not found or access denied'})
                return
            
            # Join the thread room
            join_room(f'thread_{thread_id}')
            
            # Send confirmation
            emit('joined_thread', {
                'success': True,
                'thread_id': thread_id,
                'user_id': user_id,
                'thread_title': thread_data.get('title', 'Unknown'),
                'timestamp': datetime.utcnow().isoformat(),
                'message': f'Successfully joined thread: {thread_data.get("title")}'
            })
            
            current_app.logger.info(f"📨 User {user_id} joined thread {thread_id}")
            
        except Exception as e:
            current_app.logger.error(f"❌ Error joining thread: {e}")
            emit('error', {'message': f'Failed to join thread: {str(e)}'})
    
    @socketio.on('leave_thread')
    @socket_auth_required
    def handle_leave_thread(data: Dict[str, Any]):
        """Leave a chat thread room"""
        try:
            user_id = request.user_id
            thread_id_raw = data.get('thread_id')
            
            if not thread_id_raw:
                emit('error', {'message': 'Thread ID is required'})
                return
            
            try:
                thread_id = int(thread_id_raw)
            except (ValueError, TypeError):
                emit('error', {'message': 'Invalid thread ID format'})
                return
            
            # Leave the thread room
            leave_room(f'thread_{thread_id}')
            
            emit('left_thread', {
                'thread_id': thread_id,
                'user_id': user_id,
                'timestamp': datetime.utcnow().isoformat()
            })
            
            current_app.logger.info(f"📤 User {user_id} left thread {thread_id}")
            
        except Exception as e:
            current_app.logger.error(f"❌ Error leaving thread: {e}")
            emit('error', {'message': f'Failed to leave thread: {str(e)}'})
    
    @socketio.on('typing')
    @socket_auth_required
    def handle_typing(data: Dict[str, Any]):
        """Handle typing indicator"""
        try:
            user_id = request.user_id
            thread_id_raw = data.get('thread_id')
            is_typing = data.get('is_typing', False)
            
            if not thread_id_raw:
                emit('error', {'message': 'Thread ID is required'})
                return
            
            try:
                thread_id = int(thread_id_raw)
            except (ValueError, TypeError):
                emit('error', {'message': 'Invalid thread ID format'})
                return
            
            # Update typing status
            ChatService.set_typing_status(user_id, thread_id, is_typing)
            
            # Prepare typing data
            typing_data = {
                'user_id': user_id,
                'thread_id': thread_id,
                'is_typing': bool(is_typing),
                'timestamp': datetime.utcnow().isoformat()
            }
            
            # Notify others in the thread (except sender)
            emit('user_typing', typing_data,
                room=f'thread_{thread_id}',
                include_self=False)
            
            current_app.logger.debug(
                f"⌨️ User {user_id} {'started' if is_typing else 'stopped'} "
                f"typing in thread {thread_id}"
            )
            
        except Exception as e:
            current_app.logger.error(f"❌ Error handling typing: {e}")
            emit('error', {'message': f'Failed to send typing indicator: {str(e)}'})
    
    @socketio.on('send_message')
    @socket_auth_required
    def handle_send_message(data: Dict[str, Any]):
        """Handle incoming message via WebSocket"""
        try:
            user_id = request.user_id
            thread_id_raw = data.get('thread_id')
            content = data.get('content', '').strip()
            message_type = data.get('message_type', 'text')
            metadata = data.get('metadata', {})
            parent_message_id_raw = data.get('parent_message_id')
            
            # Validate required fields
            if not thread_id_raw:
                emit('error', {'message': 'Thread ID is required'})
                return
            
            if not content:
                emit('error', {'message': 'Message content is required'})
                return
            
            # Convert IDs to integers
            try:
                thread_id = int(thread_id_raw)
            except (ValueError, TypeError):
                emit('error', {'message': 'Invalid thread ID format'})
                return
            
            parent_message_id = None
            if parent_message_id_raw:
                try:
                    parent_message_id = int(parent_message_id_raw)
                except (ValueError, TypeError):
                    emit('error', {'message': 'Invalid parent message ID format'})
                    return
            
            # Send message using ChatService
            message = ChatService.send_message(
                thread_id=thread_id,
                sender_id=user_id,
                content=content,
                message_type=message_type,
                metadata=metadata,
                parent_message_id=parent_message_id
            )
            
            # Send confirmation to sender
            emit('message_sent', {
                'success': True,
                'message_id': message.id,
                'thread_id': thread_id,
                'timestamp': message.created_at.isoformat() if message.created_at else None
            })
            
            current_app.logger.info(
                f"💬 User {user_id} sent message in thread {thread_id}"
            )
            
        except ValueError as e:
            current_app.logger.warning(f"⚠️ Message validation error: {e}")
            emit('error', {'message': str(e)})
        except Exception as e:
            current_app.logger.error(f"❌ Error sending message: {e}")
            emit('error', {'message': f'Failed to send message: {str(e)}'})
    
    @socketio.on('mark_read')
    @socket_auth_required
    def handle_mark_read(data: Dict[str, Any]):
        """Mark messages as read via WebSocket"""
        try:
            user_id = request.user_id
            thread_id_raw = data.get('thread_id')
            message_ids_raw = data.get('message_ids', [])
            
            if not thread_id_raw:
                emit('error', {'message': 'Thread ID is required'})
                return
            
            # Convert thread_id to integer
            try:
                thread_id = int(thread_id_raw)
            except (ValueError, TypeError):
                emit('error', {'message': 'Invalid thread ID format'})
                return
            
            # Convert message_ids to integers
            message_ids = []
            for i, msg_id in enumerate(message_ids_raw):
                try:
                    message_ids.append(int(msg_id))
                except (ValueError, TypeError):
                    current_app.logger.warning(
                        f"⚠️ Invalid message ID at index {i}: {msg_id}"
                    )
                    continue
            
            # Mark messages as read
            # This will be handled automatically when fetching messages
            # But we can still send an acknowledgment
            
            emit('messages_read', {
                'success': True,
                'thread_id': thread_id,
                'user_id': user_id,
                'message_ids': message_ids,
                'timestamp': datetime.utcnow().isoformat()
            })
            
            current_app.logger.debug(
                f"📖 User {user_id} marked messages as read in thread {thread_id}"
            )
            
        except Exception as e:
            current_app.logger.error(f"❌ Error marking messages as read: {e}")
            emit('error', {'message': f'Failed to mark messages as read: {str(e)}'})
    
    @socketio.on('get_presence')
    @socket_auth_required
    def handle_get_presence(data: Dict[str, Any]):
        """Get presence status of users"""
        try:
            user_id = request.user_id
            user_ids_raw = data.get('user_ids', [])
            
            if not user_ids_raw:
                emit('error', {'message': 'User IDs are required'})
                return
            
            # Convert user_ids to integers
            user_ids = []
            for i, uid in enumerate(user_ids_raw):
                try:
                    user_ids.append(int(uid))
                except (ValueError, TypeError):
                    current_app.logger.warning(
                        f"⚠️ Invalid user ID at index {i}: {uid}"
                    )
                    continue
            
            if not user_ids:
                emit('error', {'message': 'No valid user IDs provided'})
                return
            
            # Get presence data
            presences = ChatService.get_presence(user_ids)
            
            emit('presence_data', {
                'success': True,
                'requested_by': user_id,
                'presences': presences,
                'timestamp': datetime.utcnow().isoformat()
            })
            
            current_app.logger.debug(
                f"👤 User {user_id} requested presence for {len(user_ids)} users"
            )
            
        except Exception as e:
            current_app.logger.error(f"❌ Error getting presence: {e}")
            emit('error', {'message': f'Failed to get presence: {str(e)}'})
    
    @socketio.on('edit_message')
    @socket_auth_required
    def handle_edit_message(data: Dict[str, Any]):
        """Edit an existing message"""
        try:
            user_id = request.user_id
            message_id_raw = data.get('message_id')
            new_content = data.get('content', '').strip()
            
            if not message_id_raw:
                emit('error', {'message': 'Message ID is required'})
                return
            
            if not new_content:
                emit('error', {'message': 'New content is required'})
                return
            
            # Convert message_id to integer
            try:
                message_id = int(message_id_raw)
            except (ValueError, TypeError):
                emit('error', {'message': 'Invalid message ID format'})
                return
            
            # Edit message
            message = ChatService.edit_message(message_id, user_id, new_content)
            
            if message:
                emit('message_edited', {
                    'success': True,
                    'message_id': message_id,
                    'thread_id': message.thread_id,
                    'new_content': new_content,
                    'timestamp': datetime.utcnow().isoformat()
                })
            else:
                emit('error', {'message': 'Message not found or unauthorized'})
            
        except Exception as e:
            current_app.logger.error(f"❌ Error editing message: {e}")
            emit('error', {'message': f'Failed to edit message: {str(e)}'})
    
    @socketio.on('delete_message')
    @socket_auth_required
    def handle_delete_message(data: Dict[str, Any]):
        """Delete a message"""
        try:
            user_id = request.user_id
            message_id_raw = data.get('message_id')
            permanent = data.get('permanent', False)
            
            if not message_id_raw:
                emit('error', {'message': 'Message ID is required'})
                return
            
            # Convert message_id to integer
            try:
                message_id = int(message_id_raw)
            except (ValueError, TypeError):
                emit('error', {'message': 'Invalid message ID format'})
                return
            
            # Delete message
            success = ChatService.delete_message(message_id, user_id, permanent)
            
            if success:
                emit('message_deleted', {
                    'success': True,
                    'message_id': message_id,
                    'permanent': permanent,
                    'timestamp': datetime.utcnow().isoformat()
                })
            else:
                emit('error', {'message': 'Message not found or unauthorized'})
            
        except Exception as e:
            current_app.logger.error(f"❌ Error deleting message: {e}")
            emit('error', {'message': f'Failed to delete message: {str(e)}'})
    
    @socketio.on('get_threads')
    @socket_auth_required
    def handle_get_threads(data: Dict[str, Any]):
        """Get user's chat threads via WebSocket"""
        try:
            user_id = request.user_id
            entity_type = data.get('entity_type')
            entity_id_raw = data.get('entity_id')
            
            entity_id = None
            if entity_id_raw is not None:
                entity_id = str(entity_id_raw)
            
            # Get threads
            threads = ChatService.get_user_threads(
                user_id=user_id,
                entity_type=entity_type,
                entity_id=entity_id
            )
            
            emit('threads_data', {
                'success': True,
                'threads': threads,
                'count': len(threads),
                'timestamp': datetime.utcnow().isoformat()
            })
            
            current_app.logger.debug(
                f"📋 User {user_id} requested threads "
                f"(entity_type={entity_type}, entity_id={entity_id})"
            )
            
        except Exception as e:
            current_app.logger.error(f"❌ Error getting threads: {e}")
            emit('error', {'message': f'Failed to get threads: {str(e)}'})
    
    app.logger.info("✅ WebSocket handlers registered successfully")