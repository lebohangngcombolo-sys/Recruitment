# services/chat_service.py
from datetime import datetime
from app.models import db, ChatThread, ChatMessage, MessageReadStatus, UserPresence, User
from app.extensions import socketio
from typing import List, Optional

class ChatService:
    
    @staticmethod
    def get_user_threads(user_id: int, entity_type: str = None, entity_id: str = None):
        """Get all chat threads for a user"""
        query = ChatThread.query.filter(
            ChatThread.participants.any(id=user_id),
            ChatThread.is_active == True,
            ChatThread.is_archived == False
        )
        
        if entity_type:
            query = query.filter(ChatThread.entity_type == entity_type)
        if entity_id:
            query = query.filter(ChatThread.entity_id == entity_id)
        
        threads = query.order_by(
            db.desc(ChatThread.last_message_at) if ChatThread.last_message_at 
            else db.desc(ChatThread.updated_at)
        ).all()
        
        result = []
        for thread in threads:
            thread_dict = thread.to_dict_detailed()
            
            # Calculate unread count for this user
            last_message = thread.messages.first()
            if last_message:
                last_read = MessageReadStatus.query.filter_by(
                    user_id=user_id,
                    message_id=last_message.id
                ).first()
                
                if last_read:
                    unread_count = ChatMessage.query.filter(
                        ChatMessage.thread_id == thread.id,
                        ChatMessage.created_at > last_read.read_at,
                        ChatMessage.sender_id != user_id
                    ).count()
                else:
                    unread_count = ChatMessage.query.filter_by(
                        thread_id=thread.id
                    ).count()
                
                thread_dict['unread_count'] = unread_count
                
                # Add last message preview
                thread_dict['last_message'] = {
                    'content': last_message.content[:100] + '...' if len(last_message.content) > 100 else last_message.content,
                    'sender_id': last_message.sender_id,
                    'created_at': last_message.created_at.isoformat() if last_message.created_at else None
                }
            
            result.append(thread_dict)
        
        return result
    
    @staticmethod
    def create_thread(title: str, created_by: int, participant_ids: List[int], 
                     entity_type: str = 'general', entity_id: str = None):
        """Create a new chat thread"""
        # Ensure creator is included in participants
        all_participants = list(set([created_by] + participant_ids))
        
        # Check if similar thread exists (for entity-specific chats)
        if entity_type != 'general' and entity_id:
            existing_thread = ChatThread.query.filter_by(
                entity_type=entity_type,
                entity_id=entity_id
            ).first()
            
            if existing_thread:
                return existing_thread
        
        thread = ChatThread(
            title=title,
            entity_type=entity_type,
            entity_id=entity_id,
            created_by=created_by
        )
        
        db.session.add(thread)
        db.session.flush()
        
        # Add participants
        participants = User.query.filter(User.id.in_(all_participants)).all()
        thread.participants.extend(participants)
        
        db.session.commit()
        
        # Notify participants via WebSocket
        for participant in participants:
            if participant.id != created_by:
                socketio.emit('new_thread', thread.to_dict_detailed(), 
                            room=f'user_{participant.id}')
        
        return thread
    
    @staticmethod
    def get_thread_messages(thread_id: int, user_id: int, limit: int = 50, 
                           before: datetime = None):
        """Get messages for a thread with pagination"""
        # Verify user has access to thread
        thread = ChatThread.query.get_or_404(thread_id)
        if not any(p.id == user_id for p in thread.participants):
            return []
        
        query = ChatMessage.query.filter_by(thread_id=thread_id, is_deleted=False)
        
        if before:
            query = query.filter(ChatMessage.created_at < before)
        
        messages = query.order_by(db.desc(ChatMessage.created_at)).limit(limit).all()
        
        # Mark messages as read for this user
        unread_messages = [msg for msg in messages 
                          if msg.sender_id != user_id and 
                          not MessageReadStatus.query.filter_by(
                              message_id=msg.id, 
                              user_id=user_id
                          ).first()]
        
        for msg in unread_messages:
            read_status = MessageReadStatus(
                message_id=msg.id,
                user_id=user_id
            )
            db.session.add(read_status)
        
        db.session.commit()
        
        return [msg.to_dict() for msg in reversed(messages)]  # Return oldest first
    
    @staticmethod
    def send_message(thread_id: int, sender_id: int, content: str, 
                    message_type: str = 'text', metadata: dict = None,
                    parent_message_id: Optional[int] = None):
        """Send a new message"""
        try:
            sender_id = int(sender_id)
        except (ValueError, TypeError):
            raise ValueError("Invalid sender ID")

        thread = ChatThread.query.get_or_404(thread_id)
        
        # Verify sender is a participant
        if not any(p.id == sender_id for p in thread.participants):
            raise ValueError("User is not a participant in this thread")
        
        if parent_message_id is not None:
            parent_message = ChatMessage.query.get(parent_message_id)
            if not parent_message or parent_message.thread_id != thread_id:
                raise ValueError("Invalid parent message")

        message = ChatMessage(
            thread_id=thread_id,
            sender_id=sender_id,
            content=content,
            message_type=message_type,
            metadata=metadata or {},
            parent_message_id=parent_message_id
        )
        
        db.session.add(message)
        
        # Update thread's last message timestamp
        thread.last_message_at = datetime.utcnow()
        thread.updated_at = datetime.utcnow()
        
        db.session.commit()
        
        # Mark as read by sender
        read_status = MessageReadStatus(
            message_id=message.id,
            user_id=sender_id
        )
        db.session.add(read_status)
        db.session.commit()
        
        # Get complete message with sender info
        message_data = message.to_dict()
        message_data['thread_id'] = thread_id
        
        # Emit to all thread participants via WebSocket
        for participant in thread.participants:
            if participant.id != sender_id:
                socketio.emit('new_message', message_data, room=f'user_{participant.id}')
        
        return message

    @staticmethod
    def get_thread_details(thread_id: int, user_id: int) -> Optional[dict]:
        """Get thread details if user has access."""
        thread = ChatThread.query.get(thread_id)
        if not thread:
            return None
        if not any(p.id == user_id for p in thread.participants):
            return None
        return thread.to_dict_detailed()

    @staticmethod
    def set_typing_status(user_id: int, thread_id: int, is_typing: bool) -> bool:
        """Update typing status for a user in a thread."""
        thread = ChatThread.query.get(thread_id)
        if not thread or not any(p.id == user_id for p in thread.participants):
            return False

        presence = UserPresence.query.get(user_id)
        if not presence:
            presence = UserPresence(user_id=user_id)
            db.session.add(presence)

        presence.is_typing = bool(is_typing)
        presence.typing_in_thread = thread_id if is_typing else None
        presence.last_seen = datetime.utcnow()
        db.session.commit()
        return True
    
    @staticmethod
    def update_presence(user_id: int, status: str, socket_id: str = None):
        """Update user presence status"""
        presence = UserPresence.query.get(user_id)
        if not presence:
            presence = UserPresence(user_id=user_id)
            db.session.add(presence)
        
        presence.status = status
        presence.last_seen = datetime.utcnow()
        if socket_id:
            presence.socket_id = socket_id
        
        db.session.commit()
        
        # Broadcast presence update to all user's chat threads
        user = User.query.get(user_id)
        if user:
            user_threads = user.chat_threads.all()
            
            presence_data = {
                'user_id': user_id,
                'status': status,
                'last_seen': presence.last_seen.isoformat(),
                'user_name': user.profile.get('full_name') if user.profile else user.email
            }
            
            for thread in user_threads:
                for participant in thread.participants:
                    if participant.id != user_id:
                        socketio.emit('presence_update', presence_data, 
                                    room=f'user_{participant.id}')
        
        return presence
    
    @staticmethod
    def search_messages(user_id: int, query: str, thread_id: int = None, 
                       limit: int = 20):
        """Search messages across user's threads"""
        if not query or len(query.strip()) < 2:
            return []
        
        # Get all threads user has access to
        user_threads = ChatThread.query.filter(
            ChatThread.participants.any(id=user_id)
        ).with_entities(ChatThread.id).all()
        
        thread_ids = [t.id for t in user_threads]
        
        if not thread_ids:
            return []
        
        search_query = ChatMessage.query.filter(
            ChatMessage.thread_id.in_(thread_ids),
            ChatMessage.content.ilike(f'%{query}%'),
            ChatMessage.is_deleted == False
        )
        
        if thread_id:
            search_query = search_query.filter(ChatMessage.thread_id == thread_id)
        
        messages = search_query.order_by(db.desc(ChatMessage.created_at)).limit(limit).all()
        
        return [msg.to_dict() for msg in messages]
    
    @staticmethod
    def get_or_create_entity_thread(entity_type: str, entity_id: str, user_id: int):
        """
        Get or create a thread for a specific entity (candidate/requisition)
        This would include relevant team members automatically
        """
        # Check existing thread
        thread = ChatThread.query.filter_by(
            entity_type=entity_type,
            entity_id=str(entity_id)
        ).first()
        
        if thread:
            # Add user to thread if not already a participant
            if not any(p.id == user_id for p in thread.participants):
                user = User.query.get(user_id)
                if user:
                    thread.participants.append(user)
                    db.session.commit()
            return thread
        
        # Create new thread with relevant participants
        # You'll need to define logic for who should be in entity threads
        title = f"{entity_type.title()} Discussion - ID: {entity_id}"
        
        # Default participants (you can customize this)
        participant_ids = [user_id]
        
        thread = ChatService.create_thread(
            title=title,
            created_by=user_id,
            participant_ids=participant_ids,
            entity_type=entity_type,
            entity_id=str(entity_id)
        )
        
        return thread