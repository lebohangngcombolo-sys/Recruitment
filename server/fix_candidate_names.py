from app import create_app
from app.extensions import db
from app.models import User, Candidate

app = create_app()
with app.app_context():
    print('=== FIXING CANDIDATE NAMES ===')
    
    # Get candidates with missing names
    candidates_no_name = Candidate.query.filter(
        Candidate.full_name.is_(None) | (Candidate.full_name == '')
    ).all()
    
    print(f'Found {len(candidates_no_name)} candidates with missing names')
    
    fixed_count = 0
    for c in candidates_no_name:
        user = User.query.get(c.user_id)
        if user:
            profile = user.profile or {}
            first_name = profile.get('first_name', '')
            last_name = profile.get('last_name', '')
            email = user.email
            
            # Try to construct name from profile
            if first_name or last_name:
                new_name = f"{first_name} {last_name}".strip()
            else:
                # Use email prefix as fallback
                new_name = email.split('@')[0].replace('.', ' ').title()
            
            print(f'Fixing candidate {c.id}: "{c.full_name}" -> "{new_name}"')
            c.full_name = new_name
            fixed_count += 1
    
    if fixed_count > 0:
        db.session.commit()
        print(f'Successfully fixed {fixed_count} candidate names')
    else:
        print('No candidates needed fixing')
    
    # Verify the fix
    remaining_empty = Candidate.query.filter(
        Candidate.full_name.is_(None) | (Candidate.full_name == '')
    ).count()
    print(f'Remaining candidates with empty names: {remaining_empty}')
    
    print('=== CANDIDATE NAMES FIXED ===')
