import eventlet

# Ensure eventlet monkey patching happens before any app imports.
eventlet.monkey_patch()

from app import create_app

app = create_app()
