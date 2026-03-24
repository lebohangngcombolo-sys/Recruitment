from app import create_app
from app.extensions import db
from app.models import Candidate, Application, User

app = create_app()
with app.app_context():
    print('=== CANDIDATE ANALYSIS ===')
    
    # Count all candidates
    total_candidates = Candidate.query.count()
    print(f'Total candidates: {total_candidates}')
    
    # Count candidates with applications
    candidates_with_apps = db.session.query(Candidate.id).join(Application).distinct().count()
    print(f'Candidates with applications: {candidates_with_apps}')
    
    # Show sample candidates
    candidates = Candidate.query.limit(5).all()
    for c in candidates:
        user = User.query.get(c.user_id)
        app_count = Application.query.filter_by(candidate_id=c.id).count()
        print(f' - {c.full_name or "No name"} ({user.email if user else "No user"}) - {app_count} applications')
    
    print('========================')
