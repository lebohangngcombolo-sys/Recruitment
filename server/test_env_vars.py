#!/usr/bin/env python3
"""
Simple test for SendGrid and Cloudinary environment variables
"""

import os
from dotenv import load_dotenv

def test_variables():
    """Test if SendGrid and Cloudinary variables are loaded correctly"""
    print("🔍 Testing Environment Variables\n")
    
    load_dotenv()
    
    # Test Cloudinary
    print("=== Cloudinary Variables ===")
    cloud_name = os.getenv('CLOUDINARY_CLOUD_NAME')
    api_key = os.getenv('CLOUDINARY_API_KEY')
    api_secret = os.getenv('CLOUDINARY_API_SECRET')
    
    print(f"CLOUDINARY_CLOUD_NAME: {'✅ SET' if cloud_name else '❌ MISSING'}")
    print(f"CLOUDINARY_API_KEY: {'✅ SET' if api_key else '❌ MISSING'}")
    print(f"CLOUDINARY_API_SECRET: {'✅ SET' if api_secret else '❌ MISSING'}")
    
    if all([cloud_name, api_key, api_secret]):
        print("✅ All Cloudinary variables are configured")
    else:
        print("❌ Some Cloudinary variables are missing")
    
    # Test SendGrid
    print("\n=== SendGrid Variables ===")
    mail_server = os.getenv('MAIL_SERVER')
    mail_port = os.getenv('MAIL_PORT')
    mail_username = os.getenv('MAIL_USERNAME')
    mail_password = os.getenv('MAIL_PASSWORD')
    mail_sender = os.getenv('MAIL_DEFAULT_SENDER')
    
    print(f"MAIL_SERVER: {'✅ SET' if mail_server else '❌ MISSING'}")
    print(f"MAIL_PORT: {'✅ SET' if mail_port else '❌ MISSING'}")
    print(f"MAIL_USERNAME: {'✅ SET' if mail_username else '❌ MISSING'}")
    print(f"MAIL_PASSWORD: {'✅ SET' if mail_password else '❌ MISSING'}")
    print(f"MAIL_DEFAULT_SENDER: {'✅ SET' if mail_sender else '❌ MISSING'}")
    
    # Check if it's SendGrid specifically
    is_sendgrid = mail_server == 'smtp.sendgrid.net' and mail_username == 'apikey'
    if is_sendgrid:
        print("✅ SendGrid configuration detected")
    else:
        print("⚠️  Not configured for SendGrid")
    
    if all([mail_server, mail_port, mail_username, mail_password, mail_sender]):
        print("✅ All mail variables are configured")
    else:
        print("❌ Some mail variables are missing")
    
    # Summary
    print("\n=== Summary ===")
    cloudinary_ok = all([cloud_name, api_key, api_secret])
    sendgrid_ok = all([mail_server, mail_port, mail_username, mail_password, mail_sender])
    
    if cloudinary_ok and sendgrid_ok:
        print("🎉 All variables are properly configured!")
        return True
    else:
        print("⚠️  Some variables need attention")
        return False

if __name__ == "__main__":
    test_variables()
