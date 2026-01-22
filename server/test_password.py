from app import create_app
from app.models import User
from app.services.auth_service import AuthService
app = create_app()
with app.app_context():
    user = User.query.filter_by(email='sleigh@khonorecruit.com').first()
    
    if user:
        print(f"Testing password for: {user.email}")
        print(f"Stored hash: {user.password}")
        
        # Test the password
        test_password = "sleigh123"
        is_valid = AuthService.verify_password(test_password, user.password)
        
        print(f"Password '{test_password}' valid: {is_valid}")
        
        if not is_valid:
            # Test with a new hash
            new_hash = AuthService.hash_password(test_password)
            print(f"New hash would be: {new_hash}")
            
            # Test the new hash
            new_valid = AuthService.verify_password(test_password, new_hash)
            print(f"New hash valid: {new_valid}")
            
            # Update the user password
            user.password = new_hash
            from app.extensions import db
            db.session.commit()
            print("✅ Password updated in database")
    else:
        print("User not found")
