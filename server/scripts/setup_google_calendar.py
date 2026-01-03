#!/usr/bin/env python3
"""
Google Calendar Setup Script
"""

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from flask import Flask
from app import create_app
from app.services.google_calendar_service import GoogleCalendarService

def setup_google_calendar():
    print("🔧 Setting up Google Calendar integration...")
    
    app = create_app()
    
    with app.app_context():
        if not app.config.get('GOOGLE_CALENDAR_ENABLED'):
            print("❌ Google Calendar integration is disabled in config.")
            print("   Set GOOGLE_CALENDAR_ENABLED=true in your .env file")
            return
        
        credentials_path = app.config.get('GOOGLE_CALENDAR_CREDENTIALS_PATH')
        if not os.path.exists(credentials_path):
            print(f"❌ Credentials file not found at: {credentials_path}")
            print("\n📋 To set up Google Calendar:")
            print("1. Go to https://console.cloud.google.com/")
            print("2. Create a new project or select existing one")
            print("3. Enable Google Calendar API")
            print("4. Create OAuth 2.0 credentials (Desktop app)")
            print("5. Download credentials as credentials.json")
            print(f"6. Save to: {credentials_path}")
            return
        
        print("🔐 Authenticating with Google Calendar...")
        calendar_service = GoogleCalendarService()
        
        if calendar_service.authenticate():
            print("✅ Successfully authenticated with Google Calendar!")
            print(f"📅 Token saved to: {app.config.get('GOOGLE_CALENDAR_TOKEN_PATH')}")
            
            events = calendar_service.get_user_events(max_results=5)
            print(f"✅ Found {len(events)} events in your calendar")
            
            print("\n🎉 Google Calendar setup complete!")
            print("\n📝 Next steps:")
            print("1. Schedule an interview through the admin panel")
            print("2. Check your Google Calendar for the new event")
            print("3. Verify attendees receive email invitations")
        else:
            print("❌ Authentication failed. Please check your credentials.")

if __name__ == "__main__":
    setup_google_calendar()