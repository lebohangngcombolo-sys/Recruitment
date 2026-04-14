import os
import sys
from pathlib import Path

# Load .env
server_dir = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(server_dir))
_env_path = server_dir / ".env"
if _env_path.exists():
    from dotenv import load_dotenv
    load_dotenv(_env_path)

from app import create_app
from app.extensions import db
from app.models import User, Candidate, Requisition, Application

def verify_accounts():
    app = create_app()
    with app.app_context():
        print("--- Verification Results ---")
        
        # 1. Candidate Account
        cand_user = User.query.filter_by(email="caitlin_candidate@khonology.com").first()
        if cand_user and cand_user.role == "candidate":
            cand = Candidate.query.filter_by(user_id=cand_user.id).first()
            if cand:
                apps = Application.query.filter_by(candidate_id=cand.id).all()
                print(f"✅ Candidate: Found {cand_user.email}")
                print(f"   - Profile: {'Complete' if cand.phone and cand.skills else 'Incomplete'}")
                print(f"   - Resume: {'Uploaded' if cand.cv_url else 'Missing'}")
                print(f"   - Applications: {len(apps)} submitted")
            else:
                print(f"❌ Candidate: {cand_user.email} has no Candidate record")
        else:
            print(f"❌ Candidate: caitlin_candidate@khonology.com not found or wrong role")

        # 2. HM Account
        hm_user = User.query.filter_by(email="caitlin_hm@khonology.com").first()
        if hm_user and hm_user.role == "hiring_manager":
            jobs = Requisition.query.filter_by(created_by=hm_user.id).all()
            print(f"✅ Hiring Manager: Found {hm_user.email}")
            print(f"   - Active Jobs: {len(jobs)}")
            if jobs:
                print(f"   - Job Requisition: {jobs[0].title} (Status: {jobs[0].approval_status})")
        else:
            print(f"❌ Hiring Manager: caitlin_hm@khonology.com not found or wrong role")

        # 3. Admin Account
        admin_user = User.query.filter_by(email="caitlin_admin@khonology.com").first()
        if admin_user and admin_user.role == "admin":
            print(f"✅ Admin: Found {admin_user.email}")
            print(f"   - Verified: {admin_user.is_verified}")
            print(f"   - Active: {admin_user.is_active}")
        else:
            print(f"❌ Admin: caitlin_admin@khonology.com not found or wrong role")

if __name__ == "__main__":
    verify_accounts()
