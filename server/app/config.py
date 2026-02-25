import os
from datetime import timedelta
from dotenv import load_dotenv

load_dotenv()


def _database_uri():
    """Single source for DB URL: .env DATABASE_URL. Add sslmode=require for remote (e.g. Render)."""
    url = os.getenv('DATABASE_URL', 'postgresql://user:password@localhost:5432/recruitment_db')
    url = (url or "").strip()
    if not url:
        return 'postgresql://user:password@localhost:5432/recruitment_db'
    # Render and other cloud Postgres often require SSL for external connections
    if 'sslmode=' not in url and ('render.com' in url or 'localhost' not in url.split('@')[-1].split('/')[0]):
        separator = '?' if '?' not in url else '&'
        url = f"{url}{separator}sslmode=require"
    return url


class Config:
    SECRET_KEY = os.getenv('SECRET_KEY', 'dev-secret-key')
    JWT_SECRET_KEY = os.getenv('JWT_SECRET_KEY', 'jwt-secret-key')
    
    # PostgreSQL (from .env DATABASE_URL; SSL enabled for remote e.g. Render)
    SQLALCHEMY_DATABASE_URI = _database_uri()
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    # Resilient to Render free-tier (sleep/wake) and dropped connections
    SQLALCHEMY_ENGINE_OPTIONS = {
        "pool_pre_ping": True,
        "connect_args": {"connect_timeout": 30},
        "pool_recycle": 300,
    }
    
    # MongoDB
    MONGO_URI = os.getenv('MONGO_URI', 'mongodb://localhost:27017/recruitment_cv')
    
    # Redis
    #REDIS_URL = os.getenv('REDIS_URL', 'redis://localhost:6379/0')
    
    # JWT (access token: after this time of inactivity the app may need to refresh or re-login)
    def _parse_positive(s: str, default: int) -> int:
        try:
            n = int((s or "").strip())
            return max(1, n) if n > 0 else default
        except (ValueError, TypeError):
            return default
    _access_days = (os.getenv('JWT_ACCESS_TOKEN_DAYS') or "").strip()
    _access_hours = os.getenv('JWT_ACCESS_TOKEN_HOURS', '2')
    if _access_days:
        JWT_ACCESS_TOKEN_EXPIRES = timedelta(days=_parse_positive(_access_days, 1))
    else:
        JWT_ACCESS_TOKEN_EXPIRES = timedelta(hours=_parse_positive(_access_hours, 1))
    JWT_REFRESH_TOKEN_EXPIRES = timedelta(days=_parse_positive(os.getenv('JWT_REFRESH_TOKEN_DAYS', '30'), 30))
    JWT_TOKEN_LOCATION = ["headers", "query_string"]  # Allow token in headers or query string
    JWT_QUERY_STRING_NAME = "access_token"            # Query param name
    
    # Email
    MAIL_SERVER = os.getenv('MAIL_SERVER', 'smtp.gmail.com')
    MAIL_PORT = int(os.getenv('MAIL_PORT', 587))
    MAIL_USE_TLS = os.getenv('MAIL_USE_TLS', 'True').lower() == 'true'
    MAIL_USERNAME = os.getenv('MAIL_USERNAME')
    MAIL_PASSWORD = os.getenv('MAIL_PASSWORD')
    MAIL_DEFAULT_SENDER = os.getenv('MAIL_DEFAULT_SENDER')
    
    # OAuth Configuration
    GOOGLE_CLIENT_ID = os.environ.get('GOOGLE_CLIENT_ID')
    GOOGLE_CLIENT_SECRET = os.environ.get('GOOGLE_CLIENT_SECRET')
    GITHUB_CLIENT_ID = os.environ.get('GITHUB_CLIENT_ID')
    GITHUB_CLIENT_SECRET = os.environ.get('GITHUB_CLIENT_SECRET')
    
    # Cloudinary
    CLOUDINARY_CLOUD_NAME = os.getenv('CLOUDINARY_CLOUD_NAME')
    CLOUDINARY_API_KEY = os.getenv('CLOUDINARY_API_KEY')
    CLOUDINARY_API_SECRET = os.getenv('CLOUDINARY_API_SECRET')
    
    # CV Processing
    CV_UPLOAD_FOLDER = os.getenv('CV_UPLOAD_FOLDER', 'uploads/cvs')
    MAX_CONTENT_LENGTH = 16 * 1024 * 1024  # 16MB max file size
    
    # Frontend URL
    FRONTEND_URL = os.getenv('FRONTEND_URL')
    
    # SSO Configuration for Company Hub Integration
    SSO_JWT_SECRET = os.getenv('SSO_JWT_SECRET', 'our-super-secret-code-123')  # Same as hub!
    PORTAL_HUB_URL = os.getenv('PORTAL_HUB_URL', 'http://localhost:5001')  # Hub address
    
    RATELIMIT_STORAGE_URI = "memory://"
    
    SSO_CLIENT_ID = os.getenv('SSO_CLIENT_ID') 
    SSO_CLIENT_SECRET = os.getenv('SSO_CLIENT_SECRET')
    SSO_METADATA_URL = os.getenv('SSO_METADATA_URL')
    SSO_USERINFO_URL = os.getenv('SSO_USERINFO_URL')
    
    VALID_ROLES = ["admin", "hiring_manager", "candidate", "hr"]
    
    # Google Calendar Integration (NEW)
    GOOGLE_CALENDAR_ENABLED = os.getenv('GOOGLE_CALENDAR_ENABLED', 'False').lower() == 'true'
    GOOGLE_CALENDAR_CREDENTIALS_PATH = os.getenv('GOOGLE_CALENDAR_CREDENTIALS_PATH', 'credentials.json')
    GOOGLE_CALENDAR_TOKEN_PATH = os.getenv('GOOGLE_CALENDAR_TOKEN_PATH', 'token.pickle')
    GOOGLE_CALENDAR_DEFAULT_DURATION = int(os.getenv('GOOGLE_CALENDAR_DEFAULT_DURATION', '60'))  # minutes
    GOOGLE_CALENDAR_TIMEZONE = os.getenv('GOOGLE_CALENDAR_TIMEZONE', 'UTC')

    
class DevelopmentConfig(Config):
    DEBUG = True

class ProductionConfig(Config):
    DEBUG = False

config = {
    'development': DevelopmentConfig,
    'production': ProductionConfig,
    'default': DevelopmentConfig
}