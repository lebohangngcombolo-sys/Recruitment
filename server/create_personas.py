#!/usr/bin/env python3
"""Create 2 personas for each user (primary + secondary roles)."""

import os
import sys

# Database connection
DATABASE_URL = "postgresql://recruitment_db_vexi_user:UcI5op62mjxTmneB9ZThvaxoC4EGMspu@dpg-d64aam8gjchc739jpt5g-a.oregon-postgres.render.com/recruitment_db_vexi?sslmode=require"
os.environ['DATABASE_URL'] = DATABASE_URL

sys.path.insert(0, '.')

from app import create_app
from app.extensions import db
from app.models import User
from werkzeug.security import generate_password_hash

app = create_app()

# Personas to create (2 for each person)
personas = [
    # Bongiwe Mbele - Persona 1: Hiring Manager (already exists)
    {
        'email': 'bongiwe.mbele@company.com',
        'first_name': 'Bongiwe',
        'last_name': 'Mbele',
        'role': 'hiring_manager',
        'password': 'TempPass123!',
        'persona': 'Work - Hiring Manager',
        'phone': '+27 82 123 4567'
    },
    # Bongiwe Mbele - Persona 2: Candidate
    {
        'email': 'bongiwe.mbele.personal@gmail.com',
        'first_name': 'Bongiwe',
        'last_name': 'Mbele',
        'role': 'candidate',
        'password': 'TempPass123!',
        'persona': 'Personal - Candidate',
        'phone': '+27 82 123 4568'
    },
    
    # Nkosinathi Radebe - Persona 1: Admin (already exists)
    {
        'email': 'nkosinathi.radebe@company.com',
        'first_name': 'Nkosinathi',
        'last_name': 'Radebe',
        'role': 'admin',
        'password': 'TempPass123!',
        'persona': 'Work - Admin',
        'phone': '+27 83 987 6543'
    },
    # Nkosinathi Radebe - Persona 2: Hiring Manager
    {
        'email': 'nkosinathi.radebe.hiring@company.com',
        'first_name': 'Nkosinathi',
        'last_name': 'Radebe',
        'role': 'hiring_manager',
        'password': 'TempPass123!',
        'persona': 'Work - Hiring Manager (Secondary)',
        'phone': '+27 83 987 6544'
    },
]

print('='*70)
print('CREATING 2 PERSONAS FOR EACH USER')
print('='*70)

with app.app_context():
    for persona in personas:
        # Check if user already exists
        existing = User.query.filter_by(email=persona['email']).first()
        
        if existing:
            print(f"\n⚠️  Persona already exists: {persona['email']}")
            print(f"   Persona: {persona['persona']}")
            print(f"   Role: {existing.role}")
            
            # Ensure verified
            if not existing.is_verified:
                existing.is_verified = True
                db.session.commit()
                print(f"   ✅ Verified")
        else:
            # Create new persona
            new_user = User(
                email=persona['email'],
                password=generate_password_hash(persona['password']),
                role=persona['role'],
                is_verified=True,
                profile={
                    'first_name': persona['first_name'],
                    'last_name': persona['last_name'],
                    'full_name': f"{persona['first_name']} {persona['last_name']}",
                    'phone': persona['phone']
                }
            )
            db.session.add(new_user)
            db.session.commit()
            
            print(f"\n✅ Created persona: {persona['email']}")
            print(f"   Persona: {persona['persona']}")
            print(f"   Role: {persona['role']}")
            print(f"   Phone: {persona['phone']}")

# Summary
print('\n' + '='*70)
print('PERSONA SUMMARY BY USER')
print('='*70)

with app.app_context():
    print("\n👤 BONGIWE MBELE:")
    bongiwe_emails = ['bongiwe.mbele@company.com', 'bongiwe.mbele.personal@gmail.com']
    for email in bongiwe_emails:
        user = User.query.filter_by(email=email).first()
        if user:
            print(f"   ✅ {user.email}")
            print(f"      Role: {user.role} | Verified: {user.is_verified}")
    
    print("\n👤 NKOSINATHI RADEBE:")
    nkosinathi_emails = ['nkosinathi.radebe@company.com', 'nkosinathi.radebe.hiring@company.com']
    for email in nkosinathi_emails:
        user = User.query.filter_by(email=email).first()
        if user:
            print(f"   ✅ {user.email}")
            print(f"      Role: {user.role} | Verified: {user.is_verified}")

print('\n' + '='*70)
print('ALL PERSONAS CREATED AND VERIFIED!')
print('='*70)
print("\nBongiwe Mbele's personas:")
print("  1. Work: bongiwe.mbele@company.com (Hiring Manager)")
print("  2. Personal: bongiwe.mbele.personal@gmail.com (Candidate)")
print("\nNkosinathi Radebe's personas:")
print("  1. Admin: nkosinathi.radebe@company.com (Admin)")
print("  2. Hiring: nkosinathi.radebe.hiring@company.com (Hiring Manager)")
print("\nAll passwords: TempPass123!")
