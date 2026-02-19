"""
Gunicorn config for Render. Eventlet monkey-patching is done in post_fork
so only worker processes are patched; the arbiter stays unpatched and
avoids "do not call blocking functions from the mainloop" crashes.
"""
import os


def post_fork(server, worker):
    """Run in each worker after fork. Patch eventlet here so the arbiter is never patched."""
    import eventlet
    eventlet.monkey_patch()
