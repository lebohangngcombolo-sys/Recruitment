from app import create_app
from app.models import User

app = create_app()
with app.app_context():
    print("--- Admin Users ---")
    admins = User.query.filter_by(role='admin').limit(5).all()
    for admin in admins:
        print(f"Email: {admin.email}")
    
    print("\n--- Hiring Manager Users ---")
    hms = User.query.filter_by(role='hiring_manager').limit(5).all()
    for hm in hms:
        print(f"Email: {hm.email}")
