import os
import sys
from pathlib import Path
from datetime import datetime, date

# Load .env from server directory
server_dir = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(server_dir))
_env_path = server_dir / ".env"
if _env_path.exists():
    from dotenv import load_dotenv
    load_dotenv(_env_path)

from app import create_app
from app.extensions import db
from app.models import User, Candidate, Requisition, Application
from app.services.auth_service import AuthService

DEFAULT_PASSWORD = "CaitlinPass123!"

USERS = [
    {"email": "caitlin_candidate@khonology.com", "role": "candidate", "full_name": "Caitlin Candidate"},
    {"email": "caitlin_hm@khonology.com", "role": "hiring_manager", "full_name": "Caitlin HM"},
    {"email": "caitlin_admin@khonology.com", "role": "admin", "full_name": "Caitlin Admin"},
]

def create_users():
    app = create_app()
    with app.app_context():
        # 1. Create Users
        created_users = {}
        for spec in USERS:
            email = spec["email"].lower()
            user = User.query.filter_by(email=email).first()
            if not user:
                user = User(
                    email=email,
                    password=AuthService.hash_password(DEFAULT_PASSWORD),
                    role=spec["role"],
                    is_verified=True,
                    is_active=True,
                    enrollment_completed=True,
                    profile={"full_name": spec["full_name"]}
                )
                db.session.add(user)
                db.session.flush()
                print(f"Created user: {email}")
            else:
                user.role = spec["role"]
                user.is_verified = True
                user.is_active = True
                user.enrollment_completed = True
                user.password = AuthService.hash_password(DEFAULT_PASSWORD)
                print(f"Updated user: {email}")
            
            created_users[spec["role"]] = user

        # 2. Setup Candidate Profile
        cand_user = created_users["candidate"]
        cand = Candidate.query.filter_by(user_id=cand_user.id).first()
        if not cand:
            cand = Candidate(
                user_id=cand_user.id,
                full_name="Caitlin Candidate",
                phone="+27 12 345 6789",
                dob=date(1995, 5, 15),
                address="123 Sandton Drive, Johannesburg",
                title="Software Developer",
                location="Johannesburg",
                cv_url="https://res.cloudinary.com/dp4kugfk8/image/upload/v1/resumes/caitlin_resume.pdf",
                cv_text="Experienced software developer with focus on Python and Flutter.",
                skills=["Python", "Flutter", "SQL", "Flask"],
                education=[{"institution": "University of Cape Town", "degree": "BSc Computer Science", "year": "2017"}],
                work_experience=[{"company": "Tech Corp", "role": "Junior Dev", "duration": "2 years"}]
            )
            db.session.add(cand)
            db.session.flush()
            print(f"Created candidate profile for {cand_user.email}")
        
        # 3. Setup Hiring Manager with Job
        hm_user = created_users["hiring_manager"]
        job = Requisition.query.filter_by(created_by=hm_user.id).first()
        if not job:
            job = Requisition(
                title="Senior Python Developer",
                description="We are looking for a senior developer to join our team.",
                company="Khonology",
                location="Johannesburg",
                salary_min=600000,
                salary_max=900000,
                employment_type="full_time",
                created_by=hm_user.id,
                is_active=True,
                approval_status='approved',
                approved_at=datetime.utcnow(),
                approved_by=created_users["admin"].id
            )
            db.session.add(job)
            db.session.flush()
            print(f"Created job requisition for HM {hm_user.email}")

        # 4. Candidate submits test application
        app_check = Application.query.filter_by(candidate_id=cand.id, requisition_id=job.id).first()
        if not app_check:
            application = Application(
                candidate_id=cand.id,
                requisition_id=job.id,
                status="applied",
                resume_url=cand.cv_url,
                cv_score=85.0,
                overall_score=85.0
            )
            db.session.add(application)
            print(f"Submitted test application for {cand_user.email} to job {job.id}")

        db.session.commit()
        print("\nAll Caitlin accounts created and verified successfully.")
        print(f"Password: {DEFAULT_PASSWORD}")
        for spec in USERS:
            print(f"Role: {spec['role']:15} Email: {spec['email']}")

if __name__ == "__main__":
    create_users()
