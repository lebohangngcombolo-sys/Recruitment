from flask import Flask
from .extensions import db, jwt, mail, cloudinary_client, mongo_client, migrate, cors, bcrypt, oauth, limiter, socketio
from .models import *
from .routes import auth, admin_routes, candidate_routes, ai_routes, mfa_routes, sso_routes, analytics_routes, chat_routes, offer_routes, public_routes
from .websocket_handler import register_websocket_handlers
import firebase_admin
from firebase_admin import credentials
import os

def create_app():
    app = Flask(__name__)
    app.config.from_object("app.config.Config")

    # ---------------- Initialize Extensions ----------------
    db.init_app(app)
    jwt.init_app(app)
    mail.init_app(app)
    oauth.init_app(app)  # important for OAuth providers
    bcrypt.init_app(app)
    cloudinary_client.init_app(app)
    migrate.init_app(app, db)
    limiter.init_app(app)

    # Initialize Firebase Admin SDK
    try:
        firebase_service_account_key_file = os.getenv('FIREBASE_SERVICE_ACCOUNT_KEY_FILE')
        if firebase_service_account_key_file:
            if not os.path.isabs(firebase_service_account_key_file):
                # Resolve relative to server root (parent of app package)
                _server_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                firebase_service_account_key_file = os.path.normpath(
                    os.path.join(_server_root, firebase_service_account_key_file)
                )
            if os.path.isfile(firebase_service_account_key_file):
                cred = credentials.Certificate(firebase_service_account_key_file)
                firebase_admin.initialize_app(cred)
                app.logger.info("Firebase Admin SDK initialized successfully.")
            else:
                app.logger.warning(
                    f"Firebase key file not found: {firebase_service_account_key_file}. "
                    "Firebase Admin SDK not initialized."
                )
        else:
            app.logger.warning("FIREBASE_SERVICE_ACCOUNT_KEY_FILE environment variable not set. Firebase Admin SDK not initialized.")
    except Exception as e:
        app.logger.error(f"Failed to initialize Firebase Admin SDK: {e}")
        # Depending on your application's needs, you might want to exit or handle this more gracefully.
        # For now, we'll just log the error.
    socketio.init_app(
        app,
        cors_allowed_origins="*",
        async_mode='threading',  # use threading to avoid eventlet/gevent compatibility problems
        manage_session=False,
        ping_timeout=60,
        ping_interval=25
    )
    # In production, restrict CORS to FRONTEND_URL when set; otherwise allow all (e.g. local dev)
    _cors_origins = ["*"]
    if app.config.get("FLASK_ENV") == "production":
        _frontend = (app.config.get("FRONTEND_URL") or "").strip().rstrip("/")
        if _frontend:
            _cors_origins = [_frontend]
    cors.init_app(
        app,
        origins=_cors_origins,
        methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["Content-Type", "Authorization", "X-Requested-With", "Accept"],
        supports_credentials=False,  # Required when using origins="*"; auth uses header not cookies
    )

    # ---------------- Register Blueprints ----------------
    auth.init_auth_routes(app)  # existing auth routes
    app.register_blueprint(admin_routes.admin_bp, url_prefix="/api/admin")
    app.register_blueprint(candidate_routes.candidate_bp, url_prefix="/api/candidate")
    app.register_blueprint(ai_routes.ai_bp)
    app.register_blueprint(mfa_routes.mfa_bp, url_prefix="/api/auth")  # MFA routes
    app.register_blueprint(analytics_routes.analytics_bp, url_prefix="/api")
    app.register_blueprint(chat_routes.chat_bp, url_prefix="/api/chat")
    app.register_blueprint(offer_routes.offer_bp, url_prefix="/api/offer")
    app.register_blueprint(public_routes.public_bp, url_prefix="/api/public")

    # ---------------- Register SSO Blueprint ----------------
    sso_routes.register_sso_provider(app)      # initialize Auth0 / SSO provider
    app.register_blueprint(sso_routes.sso_bp)  # SSO routes

    # ---------------- Register WebSocket Handlers ----------------
    register_websocket_handlers(app)

    return app
