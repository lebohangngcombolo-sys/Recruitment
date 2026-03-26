from app import create_app
from app.extensions import db
from app.models import User, Candidate, Requisition, Application

app = create_app()
with app.app_context():
    print('=== SYSTEM STATUS CHECK ===')
    
    # 1. Candidates
    print('\n1. CANDIDATES:')
    total = Candidate.query.count()
    with_names = Candidate.query.filter(Candidate.full_name.isnot(None) & (Candidate.full_name != '')).count()
    print(f'   Total candidates: {total}')
    print(f'   With names: {with_names}')
    print(f'   Status: {"✅ FIXED" if with_names == total else "❌ ISSUE"}')
    
    # Show sample
    sample = Candidate.query.limit(3).all()
    for c in sample:
        print(f'   - {c.full_name or "NO NAME"} (ID: {c.id})')
    
    # 2. Users for team collaboration
    print('\n2. TEAM COLLABORATION USERS:')
    active = User.query.filter_by(is_active=True).count()
    admins = User.query.filter_by(role='admin', is_active=True).count()
    hms = User.query.filter_by(role='hiring_manager', is_active=True).count()
    candidates = User.query.filter_by(role='candidate', is_active=True).count()
    
    print(f'   Active users: {active}')
    print(f'   Admins: {admins}')
    print(f'   Hiring Managers: {hms}')
    print(f'   Candidates: {candidates}')
    print(f'   Status: {"✅ READY" if active > 0 else "❌ ISSUE"}')
    
    # 3. Job approval
    print('\n3. JOB APPROVAL:')
    jobs = Requisition.query.count()
    pending = Requisition.query.filter_by(approval_status='pending').count()
    print(f'   Total jobs: {jobs}')
    print(f'   Pending: {pending}')
    print(f'   Status: {"✅ READY" if jobs > 0 else "❌ ISSUE"}')
    
    if pending > 0:
        job = Requisition.query.filter_by(approval_status='pending').first()
        print(f'   Sample pending: {job.title} (ID: {job.id})')
    
    print('\n=== END CHECK ===')
