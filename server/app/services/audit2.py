import logging
from datetime import datetime
from flask import request
from app.extensions import db
from app.models import AuditLog

logger = logging.getLogger(__name__)


class AuditService:
    @staticmethod
    def record_action(
        admin_id: int,
        action: str,
        target_user_id: int = None,
        details: str = None,
        extra_data: dict = None,
        actor_label: str = "admin_id",
    ):
        """
        Log an action. admin_id is the actor's user id (stored in DB).
        actor_label is only for the log message (e.g. 'candidate_id' when actor is a candidate).
        """
        try:
            ip_address = request.remote_addr if request else None
            user_agent = request.headers.get("User-Agent", "") if request else None

            log_entry = AuditLog(
                admin_id=admin_id,
                action=action,
                target_user_id=target_user_id,
                details=details,
                extra_data=extra_data,
                ip_address=ip_address,
                user_agent=user_agent,
                timestamp=datetime.utcnow()
            )

            db.session.add(log_entry)
            db.session.commit()
            logger.info(f"Audit recorded: {action} by {actor_label}={admin_id}")

        except Exception as e:
            db.session.rollback()
            logger.error(f"Failed to record audit log: {e}", exc_info=True)

    @staticmethod
    def log(user_id: int, action: str, **kwargs):
        """
        Alias for record_action for backward compatibility.
        Maps old 'metadata' kwarg to 'extra_data'.
        Pass actor_label='candidate_id' for candidate-initiated actions.
        """
        extra_data = kwargs.get("metadata")  # support old calls
        actor_label = kwargs.get("actor_label", "admin_id")
        AuditService.record_action(
            admin_id=user_id, action=action, extra_data=extra_data, actor_label=actor_label
        )


# === Helper Decorators (Optional Integration) ===
def audit_action(action_description: str):
    """
    Decorator for automatically recording audits on route actions.
    Example:
    @audit_action("Created new job posting")
    """
    def decorator(func):
        from functools import wraps
        from flask_jwt_extended import get_jwt_identity

        @wraps(func)
        def wrapper(*args, **kwargs):
            response = func(*args, **kwargs)
            try:
                admin_id = get_jwt_identity()
                AuditService.record_action(
                    admin_id=admin_id,
                    action=action_description,
                    metadata={"endpoint": request.path, "method": request.method}
                )
            except Exception as e:
                logger.warning(f"Audit decorator failed: {e}")
            return response

        return wrapper
    return decorator
