#!/usr/bin/env python3
from app import create_app

try:
    app = create_app()
    print("App created successfully")
    with app.app_context():
        from app import db
        print("Database connected successfully")
except Exception as e:
    print(f"Error: {e}")