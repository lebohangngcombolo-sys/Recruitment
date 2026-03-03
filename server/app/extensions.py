import os
import ssl
from pathlib import Path

# Load .env when app package is imported (e.g. flask db upgrade) so MONGO_URI/REDIS_URL are set
_server_dir = Path(__file__).resolve().parent.parent
_env_path = _server_dir / ".env"
if _env_path.exists():
    from dotenv import load_dotenv
    load_dotenv(_env_path)

import cloudinary
import cloudinary.uploader
from flask_sqlalchemy import SQLAlchemy
from flask_jwt_extended import JWTManager
from flask_mail import Mail
from flask_migrate import Migrate
from flask_cors import CORS
from pymongo import MongoClient
from authlib.integrations.flask_client import OAuth  # <-- updated
import redis
import firebase_admin
from flask_socketio import SocketIO
from flask_bcrypt import Bcrypt
from flask_socketio import SocketIO
# In app/extensions.py
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from app.utils.password_validator import PasswordValidator



# ------------------- Flask Extensions -------------------
db = SQLAlchemy()
jwt = JWTManager()
mail = Mail()
migrate = Migrate()
oauth = OAuth()  # <-- Authlib OAuth
cors = CORS()
validator = PasswordValidator()   # ΓåÉ IMPORTANT
bcrypt = Bcrypt()
socketio = SocketIO()

# ------------------- Cloudinary Client -------------------
class CloudinaryClient:
    def init_app(self, app):
        cloud_name = app.config.get('CLOUDINARY_CLOUD_NAME')
        api_key = app.config.get('CLOUDINARY_API_KEY')
        api_secret = app.config.get('CLOUDINARY_API_SECRET')
        if not all([cloud_name, api_key, api_secret]):
            import logging
            logging.getLogger(__name__).warning(
                "Cloudinary credentials missing (CLOUDINARY_CLOUD_NAME, API_KEY, API_SECRET). CV uploads will fail."
            )
        else:
            cloudinary.config(
                cloud_name=cloud_name,
                api_key=api_key,
                api_secret=api_secret,
                secure=True
            )

    def upload(self, file_path):
        try:
            return cloudinary.uploader.upload(file_path)
        except Exception as e:
            raise Exception(f"Cloudinary upload failed: {str(e)}")

cloudinary_client = CloudinaryClient()


limiter = Limiter(key_func=get_remote_address)
# ------------------- MongoDB Client -------------------
# Use MONGO_URI from env (e.g. .env) so local run can use cloud MongoDB; default localhost for minimal setup.
_mongo_uri = os.getenv("MONGO_URI", "mongodb://localhost:27017/recruitment_cv").strip()
_mongo_db_name = _mongo_uri.rstrip("/").split("/")[-1].split("?")[0] or "recruitment_cv"
mongo_client = MongoClient(_mongo_uri)
mongo_db = mongo_client[_mongo_db_name]


# ------------------- Redis Client -------------------
# Supports local Redis (redis://) and Upstash/TLS (rediss://)
redis_url = os.getenv("REDIS_URL", "redis://localhost:6379/0")
redis_ssl_required = redis_url.startswith("rediss://")
ssl_cert_reqs_env = os.getenv("REDIS_SSL_CERT_REQS", "required").lower()
if redis_ssl_required:
    if ssl_cert_reqs_env == "none":
        ssl_cert_reqs = ssl.CERT_NONE
    elif ssl_cert_reqs_env == "optional":
        ssl_cert_reqs = ssl.CERT_OPTIONAL
    else:
        ssl_cert_reqs = ssl.CERT_REQUIRED
else:
    ssl_cert_reqs = None

redis_client = redis.from_url(
    redis_url,
    decode_responses=True,
    ssl_cert_reqs=ssl_cert_reqs,
)




