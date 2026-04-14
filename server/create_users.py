#!/usr/bin/env python3
"""Create hiring manager and admin users."""

import os
import sys
from datetime import datetime

# Database connection
DATABASE_URL = "postgresql://recruitment_db_vexi_user:UcI5op62mjxTmneB9ZThvaxoC4EGMspu@dpg-d64aam8gjchc739jpt5g-a.oregon-postgres.render.com/recruitment_db_vexi?sslmode=require"
os.environ['DATABASE_URL'] = DATABASE_URL

sys.path.insert(0, '.')

from app import create_app
from app.extensions import db
from app.models import User
from werkzeug.security import generate_password_hash

app = create_app()

users_to_create = [
    {
        'email': 'bongiwe.mbele@example.com',
        'first_name': 'Bongiwe',
        'last_name': 'Mbele',
        'role': 'hiring_manager',
        'password': 'TempPass123!'
    },
    {
        'email': 'nkosinathi.radebe@example.com',
        'first_name': 'Nkosinathi',
        'last_name': 'Radebe',
        'role': 'admin',
        'password': 'TempPass123!'
    }
]

print('='*70)
print('CREATING HIRING MANAGER & ADMIN USERS')
print('='*70)

with app.app_context():
    for user_data in users_to_create:
        # Check if user already exists
        existing = User.query.filter_by(email=user_data['email']).first()
        
        if existing:
            print(f"\n⚠️  User already exists: {user_data['email']}")
            print(f"   Role: {existing.role}")
            print(f"   Verified: {existing.is_verified}")
            
            # Update role if needed
            if existing.role != user_data['role']:
                existing.role = user_data['role']
                db.session.commit()
                print(f"   ✅ Updated role to: {user_data['role']}")
            
            # Verify user
            if not existing.is_verified:
                existing.is_verified = True
                db.session.commit()
                print(f"   ✅ Verified user")
        else:
            # Create new user
            new_user = User(
                email=user_data['email'],
                password=generate_password_hash(user_data['password']),
                role=user_data['role'],
                is_verified=True,
                profile={
                    'first_name': user_data['first_name'],
                    'last_name': user_data['last_name'],
                    'full_name': f"{user_data['first_name']} {user_data['last_name']}"
                }
            )
            db.session.add(new_user)
            db.session.commit()
            
            print(f"\n✅ Created user: {user_data['email']}")
            print(f"   Name: {user_data['first_name']} {user_data['last_name']}")
            print(f"   Role: {user_data['role']}")
            print(f"   Password: {user_data['password']} (temporary)")

# Verify all users
print('\n' + '='*70)
print('VERIFICATION - All Hiring Managers & Admins')
print('='*70)

with app.app_context():
    hiring_managers = User.query.filter_by(role='hiring_manager').all()
    admins = User.query.filter_by(role='admin').all()
    
    print(f"\n📊 Hiring Managers ({len(hiring_managers)}):")
    for user in hiring_managers:
        status = '✅' if user.is_verified else '❌'
        print(f"   {status} {user.email} - {user.full_name} (Verified: {user.is_verified})")
    
    print(f"\n📊 Admins ({len(admins)}):")
    for user in admins:
        status = '✅' if user.is_verified else '❌'
        print(f"   {status} {user.email} - {user.full_name} (Verified: {user.is_verified})")

print('\n' + '='*70)
print('USERS CREATED AND VERIFIED SUCCESSFULLY!')
print('='*70)
print('\nLogin credentials:')
print('  Bongiwe Mbele (Hiring Manager):')
print('    Email: bongiwe.mbele@example.com')
print('    Password: TempPass123!')
print('\n  Nkosinathi Radebe (Admin):')
print('    Email: nkosinathi.radebe@example.com')
print('    Password: TempPass123!')
