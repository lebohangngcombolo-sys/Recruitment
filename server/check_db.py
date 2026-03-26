from app import create_app
from app.extensions import db
from app.models import User, Candidate, Requisition, Application

app = create_app()
with app.app_context():
    print('=== DATABASE ANALYSIS ===')
    
    # Check total candidates
    total_candidates = Candidate.query.count()
    print(f'Total candidates in database: {total_candidates}')
    
    # Check candidates with user accounts
    candidates_with_users = Candidate.query.filter(Candidate.user_id.isnot(None)).count()
    print(f'Candidates with user accounts: {candidates_with_users}')
    
    # Check total users by role
    admin_users = User.query.filter_by(role='admin').count()
    hm_users = User.query.filter_by(role='hiring_manager').count()
    candidate_users = User.query.filter_by(role='candidate').count()
    print(f'Admin users: {admin_users}')
    print(f'Hiring manager users: {hm_users}')
    print(f'Candidate users: {candidate_users}')
    
    # Check jobs and applications
    total_jobs = Requisition.query.count()
    pending_jobs = Requisition.query.filter_by(approval_status='pending').count()
    total_applications = Application.query.count()
    print(f'Total jobs: {total_jobs}')
    print(f'Pending jobs: {pending_jobs}')
    print(f'Total applications: {total_applications}')
    
    # Sample candidates
    sample_candidates = Candidate.query.limit(5).all()
    print('\nSample candidates:')
    for c in sample_candidates:
        user = User.query.get(c.user_id) if c.user_id else None
        email = user.email if user else 'No user account'
        print(f'ID: {c.id}, Name: {c.full_name}, User ID: {c.user_id}, Email: {email}')
    
    # Check for duplicate route definitions
    print('\n=== CHECKING FOR API ISSUES ===')
    
    # Test the candidates/all endpoint directly
    print('Testing candidate query logic...')
    current_user = User.query.filter_by(role='admin').first()
    if current_user:
        print(f'Using admin user: {current_user.email}')
        
        # Simulate the query from the endpoint
        query = Candidate.query
        if current_user.role == "hiring_manager":
            from sqlalchemy import select
            candidate_ids_subquery = select(Application.candidate_id).distinct()
            query = Candidate.query.filter(Candidate.id.in_(candidate_ids_subquery))
        
        test_candidates = query.limit(3).all()
        print(f'Query would return {len(test_candidates)} candidates')
        for c in test_candidates:
            print(f'  - {c.full_name}')
    else:
        print('No admin user found!')
        
    print('\n=== ANALYSIS COMPLETE ===')
