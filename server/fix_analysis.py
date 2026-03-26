from app import create_app
from app.extensions import db
from app.models import User, Candidate, Requisition, Application

app = create_app()
with app.app_context():
    print('=== CANDIDATE NAME FIX ANALYSIS ===')
    
    # Check candidates with missing names
    candidates_no_name = Candidate.query.filter(Candidate.full_name.is_(None) | (Candidate.full_name == '')).all()
    print(f'Candidates with missing names: {len(candidates_no_name)}')
    
    for c in candidates_no_name:
        user = User.query.get(c.user_id)
        if user:
            profile = user.profile or {}
            first_name = profile.get('first_name', '')
            last_name = profile.get('last_name', '')
            email = user.email
            
            print(f'Candidate ID: {c.id}')
            print(f'  User Email: {email}')
            print(f'  Profile first_name: {first_name}')
            print(f'  Profile last_name: {last_name}')
            print(f'  Current full_name: {c.full_name}')
            
            # Try to construct name from profile
            if first_name or last_name:
                new_name = f"{first_name} {last_name}".strip()
                print(f'  Suggested name: {new_name}')
            else:
                # Use email prefix as fallback
                new_name = email.split('@')[0].replace('.', ' ').title()
                print(f'  Fallback name from email: {new_name}')
            print()
    
    print('=== TEAM COLLABORATION USER ANALYSIS ===')
    
    # Get all users for team collaboration
    all_users = User.query.filter(User.is_active == True).all()
    print(f'Active users total: {len(all_users)}')
    
    users_by_role = {}
    for user in all_users:
        role = user.role
        if role not in users_by_role:
            users_by_role[role] = []
        users_by_role[role].append(user)
    
    for role, users in users_by_role.items():
        print(f'\n{role.upper()} users ({len(users)}):')
        for user in users[:5]:  # Show first 5
            profile = user.profile or {}
            display_name = profile.get('first_name', '') + ' ' + profile.get('last_name', '')
            display_name = display_name.strip() or user.email
            print(f'  - {display_name} ({user.email})')
        if len(users) > 5:
            print(f'  ... and {len(users) - 5} more')
    
    print('\n=== JOB APPROVAL ANALYSIS ===')
    
    # Check pending jobs
    pending_jobs = Requisition.query.filter_by(approval_status='pending').all()
    print(f'Pending jobs: {len(pending_jobs)}')
    
    for job in pending_jobs:
        creator = User.query.get(job.created_by)
        creator_name = creator.email if creator else 'Unknown'
        print(f'  Job ID: {job.id}')
        print(f'  Title: {job.title}')
        print(f'  Created by: {creator_name}')
        print(f'  Created at: {job.created_at}')
        print()
    
    print('=== ANALYSIS COMPLETE ===')
