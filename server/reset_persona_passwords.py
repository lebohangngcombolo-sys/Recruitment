#!/usr/bin/env python3
"""Reset passwords for personas to fix bcrypt compatibility."""

import os
import sys

# Database connection
DATABASE_URL = "postgresql://recruitment_db_vexi_user:UcI5op62mjxTmneB9ZThvaxoC4EGMspu@dpg-d64aam8gjchc739jpt5g-a.oregon-postgres.render.com/recruitment_db_vexi?sslmode=require"
os.environ['DATABASE_URL'] = DATABASE_URL

sys.path.insert(0, '.')

from app import create_app
from app.extensions import db
from app.models import User
import bcrypt

app = create_app()

# Users to reset passwords for
personas = [
    {'email': 'bongiwe.mbele@company.com', 'password': 'TempPass123!'},
    {'email': 'bongiwe.mbele.personal@gmail.com', 'password': 'TempPass123!'},
    {'email': 'nkosinathi.radebe@company.com', 'password': 'TempPass123!'},
    {'email': 'nkosinathi.radebe.hiring@company.com', 'password': 'TempPass123!'},
]

print('='*70)
print('RESETTING PASSWORDS FOR PERSONAS')
print('='*70)

with app.app_context():
    for persona in personas:
        user = User.query.filter_by(email=persona['email']).first()
        
        if user:
            # Reset password with proper bcrypt hashing
            new_password_hash = bcrypt.hashpw(
                persona['password'].encode('utf-8'), 
                bcrypt.gensalt()
            ).decode('utf-8')
            
            user.password = new_password_hash
            db.session.commit()
            
            print(f"\n✅ Reset password for: {persona['email']}")
            print(f"   New password: {persona['password']}")
            print(f"   Role: {user.role}")
            print(f"   Verified: {user.is_verified}")
        else:
            print(f"\n⚠️  User not found: {persona['email']}")

print('\n' + '='*70)
print('PASSWORD RESET COMPLETE!')
print('='*70)
print("\nAll personas now have bcrypt-hashed passwords.")
print("Users can login with password: TempPass123!")
