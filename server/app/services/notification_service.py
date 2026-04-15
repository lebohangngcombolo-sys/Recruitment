from datetime import datetime
from app.models import Notification, User
from app.extensions import db, socketio
from flask_socketio import emit
from flask import current_app

# Create notification for a user
def create_notification(user_id, message):
    try:
        notification = Notification(user_id=user_id, message=message)
        db.session.add(notification)
        db.session.commit()

        # Emit real-time notification to specific user room
        socketio.emit(
            f"notification_{user_id}",
            notification.to_dict(),
            room=f'user_{user_id}'
        )
        return notification
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Create notification error: {str(e)}")
        raise

# Notify all admins
def notify_admins(message):
    try:
        admin_users = User.query.filter_by(role="admin", is_active=True).all()
        notifications = []
        for admin in admin_users:
            notification = Notification(user_id=admin.id, message=message, created_at=datetime.utcnow())
            db.session.add(notification)
            notifications.append(notification)
        
        db.session.commit()
        
        # Emit real-time notification after commit to individual admin rooms
        for notification in notifications:
            socketio.emit(
                f"notification_{notification.user_id}",
                notification.to_dict(),
                room=f'user_{notification.user_id}'
            )
        return notifications
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Notify admins error: {str(e)}")
        # Don't re-raise if we want to continue other flows
        return []

# Get notifications for a user
def get_user_notifications(user_id, unread_only=False):
    query = Notification.query.filter_by(user_id=user_id)
    if unread_only:
        query = query.filter_by(is_read=False)
    return query.order_by(Notification.created_at.desc()).all()

# Mark notification as read
def mark_notification_read(notification_id):
    notification = Notification.query.get_or_404(notification_id)
    notification.is_read = True
    db.session.commit()
    return notification
