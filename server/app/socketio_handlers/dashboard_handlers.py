"""Dashboard WebSocket event handlers.

Handles dashboard subscription/unsubscription and room management.
"""

from flask import current_app
from flask_socketio import join_room, leave_room


def register_dashboard_handlers(socketio):
    """Register dashboard-related Socket.IO event handlers."""
    
    @socketio.on('subscribe_dashboard')
    def handle_subscribe_dashboard(data):
        """
        Handle client subscription to dashboard events.
        
        Expected data format:
        {
            'user_id': 'user_id_string',
            'role': 'admin'  # optional
        }
        """
        try:
            user_id = data.get('user_id') if isinstance(data, dict) else None
            role = data.get('role', 'admin') if isinstance(data, dict) else 'admin'
            
            if not user_id:
                current_app.logger.warning("⚠️ WebSocket: subscribe_dashboard called without user_id")
                return {'status': 'error', 'message': 'user_id required'}
            
            room = f'dashboard_{user_id}'
            join_room(room)
            current_app.logger.info(f"📊 WebSocket: User {user_id} subscribed to dashboard (role: {role})")
            
            return {
                'status': 'success', 
                'message': f'Subscribed to dashboard_{user_id}',
                'room': room
            }
        except Exception as e:
            current_app.logger.error(f"❌ WebSocket: Error in subscribe_dashboard: {e}")
            return {'status': 'error', 'message': str(e)}
    
    @socketio.on('unsubscribe_dashboard')
    def handle_unsubscribe_dashboard(data):
        """
        Handle client unsubscription from dashboard events.
        
        Expected data format:
        {
            'user_id': 'user_id_string'
        }
        """
        try:
            user_id = data.get('user_id') if isinstance(data, dict) else None
            
            if not user_id:
                current_app.logger.warning("⚠️ WebSocket: unsubscribe_dashboard called without user_id")
                return {'status': 'error', 'message': 'user_id required'}
            
            room = f'dashboard_{user_id}'
            leave_room(room)
            current_app.logger.info(f"📊 WebSocket: User {user_id} unsubscribed from dashboard")
            
            return {
                'status': 'success',
                'message': f'Unsubscribed from dashboard_{user_id}',
                'room': room
            }
        except Exception as e:
            current_app.logger.error(f"❌ WebSocket: Error in unsubscribe_dashboard: {e}")
            return {'status': 'error', 'message': str(e)}
