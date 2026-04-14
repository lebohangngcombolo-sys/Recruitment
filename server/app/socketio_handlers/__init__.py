# Socket.IO event handlers package
from .chat_handlers import register_chat_handlers
from .dashboard_handlers import register_dashboard_handlers

def register_all_socketio_handlers(socketio):
    """Register all Socket.IO event handlers."""
    register_chat_handlers(socketio)
    register_dashboard_handlers(socketio)
