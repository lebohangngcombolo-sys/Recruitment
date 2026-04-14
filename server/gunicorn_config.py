"""
Gunicorn config for Render. We use gthread worker to avoid RLock/lock errors
with SQLAlchemy and Flask. Gthread handles concurrency without eventlet.
"""

import os

bind = f"0.0.0.0:{os.environ.get('PORT', '5000')}"
workers = 2
threads = 4
worker_class = "gthread"
timeout = 120
keepalive = 5
preload_app = False
