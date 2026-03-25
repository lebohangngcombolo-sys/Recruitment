#!/usr/bin/env python3

from app import create_app
from app.models import User, UserPresence, Meeting

def test_models():
    app = create_app()
    with app.app_context():
        print("🔍 Testing database models...")
        
        try:
            # Test User model
            user_count = User.query.count()
            print(f"✅ User model works! Total users: {user_count}")
            
            # Test UserPresence model
            presence_count = UserPresence.query.count()
            print(f"✅ UserPresence model works! Total presence records: {presence_count}")
            
            # Test Meeting model
            meeting_count = Meeting.query.count()
            print(f"✅ Meeting model works! Total meetings: {meeting_count}")
            
            print("✅ All models working correctly!")
            
        except Exception as e:
            print(f"❌ Error testing models: {e}")

if __name__ == "__main__":
    test_models()
