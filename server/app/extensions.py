import os
import ssl
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
validator = PasswordValidator()   # ← IMPORTANT
bcrypt = Bcrypt()
socketio = SocketIO()

# ------------------- Cloudinary Client -------------------
class CloudinaryClient:
    def init_app(self, app):
        name = app.config.get('CLOUDINARY_CLOUD_NAME')
        key = app.config.get('CLOUDINARY_API_KEY')
        secret = app.config.get('CLOUDINARY_API_SECRET')
        if name and key and secret:
            cloudinary.config(
                cloud_name=name,
                api_key=key,
                api_secret=secret,
                secure=True
            )
        # else: skip config so app starts in dev without Cloudinary; uploads will fail until set

    def upload(self, file_path):
        try:
            return cloudinary.uploader.upload(file_path)
        except Exception as e:
            raise Exception(f"Cloudinary upload failed: {str(e)}")

cloudinary_client = CloudinaryClient()


limiter = Limiter(key_func=get_remote_address)
# ------------------- MongoDB Client -------------------
# Use MONGO_URI and MONGO_DB_NAME from .env (e.g. MongoDB Atlas)
_mongo_uri = os.getenv("MONGO_URI", "mongodb://localhost:27017/")
_mongo_db_name = os.getenv("MONGO_DB_NAME", "recruitment_cv")
mongo_client = MongoClient(_mongo_uri)
mongo_db = mongo_client[_mongo_db_name]


# ------------------- Redis Client -------------------
# REDIS_URL (full URL) or build from REDIS_HOST, REDIS_PORT, REDIS_PASSWORD, REDIS_DB
_redis_url = os.getenv("REDIS_URL")
if _redis_url:
    redis_url = _redis_url
else:
    _host = os.getenv("REDIS_HOST", "localhost")
    _port = os.getenv("REDIS_PORT", "6379")
    _pw = os.getenv("REDIS_PASSWORD", "")
    _db = os.getenv("REDIS_DB", "0")
    if _pw:
        redis_url = f"redis://:{_pw}@{_host}:{_port}/{_db}"
    else:
        redis_url = f"redis://{_host}:{_port}/{_db}"
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




