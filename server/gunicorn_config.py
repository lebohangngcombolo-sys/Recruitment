"""
Gunicorn config for Render. We use gthread worker (see render_start.sh), not eventlet,
to avoid RLock/lock errors with SQLAlchemy and Flask. Add hooks or options here if needed.
"""

import os

bind = f"0.0.0.0:{os.environ.get('PORT', '5000')}"
workers = 2
threads = 4
worker_class = "gthread"
timeout = 120
keepalive = 5
preload_app = False

def post_fork(server, worker):
    """Apply eventlet monkey-patch after fork to avoid blocking mainloop"""
    import eventlet
    eventlet.monkey_patch()

def when_ready(server):
    server.log.info("Server is ready. Spawning workers")

def on_exit(server):
    server.log.info("Server is shutting down")
