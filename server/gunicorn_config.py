"""
Gunicorn config for Render. We use gthread worker (see render_start.sh), not eventlet,
to avoid RLock/lock errors with SQLAlchemy and Flask. Add hooks or options here if needed.
"""
