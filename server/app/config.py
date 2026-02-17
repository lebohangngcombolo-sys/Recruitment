import os
from datetime import timedelta
from dotenv import load_dotenv

load_dotenv()

# Are we running in production? Honor common env var flags.
IS_PRODUCTION = os.getenv("FLASK_ENV", os.getenv("ENV", "development")) == "production"

def _get_env(name, default=None, required_in_production=False):
    val = os.getenv(name, default)
    if required_in_production and IS_PRODUCTION and (val is None or val == ""):
        raise RuntimeError(f"Missing required environment variable: {name}")
    return val


def _normalize_database_url(url):
    """Ensure production PostgreSQL URLs use SSL (e.g. Render requires sslmode=require)."""
    if not url or not IS_PRODUCTION:
        return url
    url = (url or "").strip()
    if not url.startswith("postgresql://") and not url.startswith("postgres://"):
        return url
    if "sslmode=" in url:
        return url
    sep = "&" if "?" in url else "?"
    return f"{url}{sep}sslmode=require"


class Config:
    # Secrets - allow dev defaults when not running in production
    SECRET_KEY = _get_env("SECRET_KEY", "dev-secret-key", required_in_production=True)
    JWT_SECRET_KEY = _get_env("JWT_SECRET_KEY", "jwt-secret-key", required_in_production=True)

    # PostgreSQL: in production, sslmode=require is appended if missing (Render Postgres).
    _database_url = _get_env(
        "DATABASE_URL", "postgresql://user:password@localhost/recruitment_db", required_in_production=True
    )
    SQLALCHEMY_DATABASE_URI = _normalize_database_url(_database_url)
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    # Cloud Postgres (e.g. Render) often closes idle connections after ~5 min; recycle sooner.
    SQLALCHEMY_ENGINE_OPTIONS = {
        "pool_pre_ping": True,
        "pool_recycle": 300,   # 5 min — match typical cloud idle timeout
    }

    # MongoDB (optional)
    MONGO_URI = _get_env("MONGO_URI", "mongodb://localhost:27017/recruitment_cv")

    # Redis (optional)
    REDIS_URL = _get_env("REDIS_URL", None)

    # JWT
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(hours=1)
    JWT_REFRESH_TOKEN_EXPIRES = timedelta(days=30)
    JWT_TOKEN_LOCATION = ["headers", "query_string"]
    JWT_QUERY_STRING_NAME = "access_token"

    # Email - username/password may be optional depending on provider
    MAIL_SERVER = _get_env("MAIL_SERVER", "smtp.gmail.com")
    MAIL_PORT = int(_get_env("MAIL_PORT", 587))
    MAIL_USE_TLS = _get_env("MAIL_USE_TLS", "True").lower() == "true"
    MAIL_USERNAME = _get_env("MAIL_USERNAME", None)
    MAIL_PASSWORD = _get_env("MAIL_PASSWORD", None)
    MAIL_DEFAULT_SENDER = _get_env("MAIL_DEFAULT_SENDER", None)

    # OAuth Configuration
    GOOGLE_CLIENT_ID = _get_env("GOOGLE_CLIENT_ID", None)
    GOOGLE_CLIENT_SECRET = _get_env("GOOGLE_CLIENT_SECRET", None)
    GITHUB_CLIENT_ID = _get_env("GITHUB_CLIENT_ID", None)
    GITHUB_CLIENT_SECRET = _get_env("GITHUB_CLIENT_SECRET", None)

    # Cloudinary - required in production if file uploads depend on it
    CLOUDINARY_CLOUD_NAME = _get_env("CLOUDINARY_CLOUD_NAME", None, required_in_production=True)
    CLOUDINARY_API_KEY = _get_env("CLOUDINARY_API_KEY", None, required_in_production=True)
    CLOUDINARY_API_SECRET = _get_env("CLOUDINARY_API_SECRET", None, required_in_production=True)

    # CV Processing
    CV_UPLOAD_FOLDER = _get_env("CV_UPLOAD_FOLDER", "uploads/cvs")
    _upload_mb = _get_env("UPLOAD_MAX_SIZE_MB", None)
    MAX_CONTENT_LENGTH = (int(_upload_mb) * 1024 * 1024) if (_upload_mb and str(_upload_mb).isdigit()) else (16 * 1024 * 1024)  # 16MB default

    # URLs
    FRONTEND_URL = _get_env("FRONTEND_URL", None)
    BACKEND_URL = _get_env("BACKEND_URL", None)  # e.g. http://localhost:5001

    # SSO Configuration - avoid default secret in source
    SSO_JWT_SECRET = _get_env("SSO_JWT_SECRET", None)
    PORTAL_HUB_URL = _get_env("PORTAL_HUB_URL", "http://localhost:5001")

    RATELIMIT_STORAGE_URI = "memory://"

    SSO_CLIENT_ID = _get_env("SSO_CLIENT_ID", None)
    SSO_CLIENT_SECRET = _get_env("SSO_CLIENT_SECRET", None)
    SSO_METADATA_URL = _get_env("SSO_METADATA_URL", None)
    SSO_USERINFO_URL = _get_env("SSO_USERINFO_URL", None)

    VALID_ROLES = ["admin", "hiring_manager", "candidate", "hr"]

    # Optional dev/debug (from .env)
    ENABLE_SECURITY_DEBUG_LOGS = _get_env("ENABLE_SECURITY_DEBUG_LOGS", "false").lower() == "true"

    # Google Calendar Integration
    GOOGLE_CALENDAR_ENABLED = _get_env("GOOGLE_CALENDAR_ENABLED", "False").lower() == "true"
    GOOGLE_CALENDAR_CREDENTIALS_PATH = _get_env("GOOGLE_CALENDAR_CREDENTIALS_PATH", "credentials.json")
    GOOGLE_CALENDAR_TOKEN_PATH = _get_env("GOOGLE_CALENDAR_TOKEN_PATH", "token.pickle")
    GOOGLE_CALENDAR_DEFAULT_DURATION = int(_get_env("GOOGLE_CALENDAR_DEFAULT_DURATION", "60"))
    GOOGLE_CALENDAR_TIMEZONE = _get_env("GOOGLE_CALENDAR_TIMEZONE", "UTC")


class DevelopmentConfig(Config):
    DEBUG = True


class ProductionConfig(Config):
    DEBUG = False


config = {
    "development": DevelopmentConfig,
    "production": ProductionConfig,
    "default": DevelopmentConfig,
}