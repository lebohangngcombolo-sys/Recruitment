import os
import sys
from pathlib import Path

# Load .env from server directory
server_dir = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(server_dir))
_env_path = server_dir / ".env"
if _env_path.exists():
    from dotenv import load_dotenv
    load_dotenv(_env_path)

from app import create_app
from app.extensions import db
from app.models import User
from app.services.auth_service import AuthService

EMAIL = "admin@khonology.com"
PASSWORD = "KhonoAdmin2025!"
ROLE = "admin"

def create_admin():
    app = create_app()
    with app.app_context():
        email = EMAIL.lower()
        user = User.query.filter_by(email=email).first()
        
        if not user:
            user = User(
                email=email,
                password=AuthService.hash_password(PASSWORD),
                role=ROLE,
                is_verified=True,
                is_active=True,
                enrollment_completed=True,
                profile={"full_name": "Gladness Mulaudzi"}
            )
            db.session.add(user)
            print(f"Created admin user: {email}")
        else:
            user.role = ROLE
            user.is_verified = True
            user.is_active = True
            user.enrollment_completed = True
            user.password = AuthService.hash_password(PASSWORD)
            user.profile = {"full_name": "Gladness Mulaudzi"}
            print(f"Updated user to admin: {email}")
        
        db.session.commit()
        print(f"Admin account verified and ready for login.")

if __name__ == "__main__":
    create_admin()
