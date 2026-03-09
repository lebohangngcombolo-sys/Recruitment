from celery import Celery
import os
import ssl
from dotenv import load_dotenv

def make_celery(app_name=__name__):
    load_dotenv()
    broker_env = os.getenv("CELERY_BROKER_URL")
    redis_env = os.getenv("REDIS_URL")
    # Prefer REDIS_URL when it points to TLS (Upstash)
    if redis_env and redis_env.startswith("rediss://"):
        redis_url = redis_env
    else:
        redis_url = broker_env or redis_env or "redis://localhost:6379/0"
    backend = os.getenv("CELERY_RESULT_BACKEND", redis_url)
    celery = Celery(app_name, broker=redis_url, backend=backend)
    task_always_eager = os.getenv("CELERY_TASK_ALWAYS_EAGER", "false").lower() == "true"
    task_eager_propagates = os.getenv("CELERY_TASK_EAGER_PROPAGATES", "true").lower() == "true"

    celery.conf.update(
        task_acks_late=True,
        worker_prefetch_multiplier=1,
        task_serializer="json",
        result_serializer="json",
        accept_content=["json"],
        timezone="UTC",
        enable_utc=True,
        task_always_eager=task_always_eager,
        task_eager_propagates=task_eager_propagates,
    )
    if redis_url.startswith("rediss://") or backend.startswith("rediss://"):
        ssl_opts = {"ssl_cert_reqs": ssl.CERT_REQUIRED}
        celery.conf.broker_use_ssl = ssl_opts
        celery.conf.redis_backend_use_ssl = ssl_opts
    celery.autodiscover_tasks(["app"])
    return celery

celery = make_celery()

