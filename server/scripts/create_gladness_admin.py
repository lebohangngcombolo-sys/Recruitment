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

EMAIL = "gladness.mulaudzi+hm@khonology.com"
PASSWORD = "GladnessHM2025!"
ROLE = "hiring_manager"

def create_user():
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
            print(f"Created hiring manager user: {email}")
        else:
            user.role = ROLE
            user.is_verified = True
            user.is_active = True
            user.enrollment_completed = True
            user.password = AuthService.hash_password(PASSWORD)
            print(f"Updated user to hiring manager: {email}")
        
        db.session.commit()
        print(f"Hiring Manager account verified and ready for login.")

if __name__ == "__main__":
    create_user()
