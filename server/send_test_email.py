#!/usr/bin/env python3
"""
Send test email using SendGrid
"""

import os
import requests
import json
from dotenv import load_dotenv

def send_test_email():
    """Send a test email using SendGrid API with requests"""
    print("📧 Sending Test Email via API (requests)\n")
    
    load_dotenv()
    
    # Get configuration
    api_key = os.getenv('MAIL_PASSWORD')  # SendGrid API key
    sender_email = os.getenv('MAIL_DEFAULT_SENDER')
    recipient_email = 'dzunisanimabunda85@gmail.com'
    
    print(f"From: {sender_email}")
    print(f"To: {recipient_email}")
    print(f"API Key: {'✅ Configured' if api_key else '❌ Missing'}")
    
    if not all([api_key, sender_email]):
        print("❌ Missing required configuration")
        return False
    
    url = "https://api.sendgrid.com/v3/mail/send"
    
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }
    
    payload = {
        "personalizations": [
            {
                "to": [{"email": recipient_email}],
                "subject": "✅ SendGrid Test - Recruitment System"
            }
        ],
        "from": {"email": sender_email},
        "content": [
            {
                "type": "text/html",
                "value": f'''
                <h2>SendGrid Integration Test</h2>
                <p>This is a test email to verify your SendGrid configuration is working correctly.</p>
                
                <div style="background-color: #f0f8ff; padding: 20px; border-radius: 8px; margin: 20px 0;">
                    <h3>🎉 Test Results</h3>
                    <ul>
                        <li>✅ SendGrid API Connection: Successful</li>
                        <li>✅ Authentication: Successful</li>
                        <li>✅ Email Delivery: In Progress</li>
                    </ul>
                </div>
                
                <p><strong>Configuration Details:</strong></p>
                <ul>
                    <li>Mail Server: smtp.sendgrid.net</li>
                    <li>Port: 587</li>
                    <li>Sender: {sender_email}</li>
                </ul>
                
                <p><em>This email was sent from the Recruitment System test suite.</em></p>
                <p><small>If you received this email, your SendGrid integration is working perfectly! 🚀</small></p>
                '''
            }
        ]
    }
    
    try:
        # Send email
        print("\n📤 Sending email via API...")
        response = requests.post(url, headers=headers, data=json.dumps(payload))
        
        print(f"✅ Email sent successfully!")
        print(f"   Status Code: {response.status_code}")
        
        if response.status_code == 202:
            print("✅ Email accepted for delivery by SendGrid")
            print(f"📬 Check your inbox at {recipient_email}")
            return True
        else:
            print(f"⚠️  Unexpected status code: {response.status_code}")
            print(f"   Response Body: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Failed to send email: {e}")
        return False

if __name__ == "__main__":
    send_test_email()
