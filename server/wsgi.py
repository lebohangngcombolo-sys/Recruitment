# Eventlet monkey-patch is done in gunicorn post_fork (see gunicorn_config.py)
# so the arbiter process is not patched (avoids "do not call blocking functions from the mainloop").
from app import create_app

app = create_app()
