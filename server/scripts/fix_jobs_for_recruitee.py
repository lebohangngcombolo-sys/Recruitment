"""
Auto-fix common job data issues for Recruitee compatibility.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from app import create_app
from app.models import Requisition, db

app = create_app()

VALID_EMPLOYMENT_TYPES = ['full_time', 'part_time', 'contract', 'internship', 'temporary']

def fix_jobs():
    with app.app_context():
        print("=" * 70)
        print("AUTO-FIXING JOBS FOR RECRUITEE")
        print("=" * 70)
        
        jobs = Requisition.query.all()
        fixes = []
        
        for job in jobs:
            job_fixed = False
            fix_details = []
            
            # Fix 1: Normalize employment_type
            if job.employment_type:
                emp_type = job.employment_type.lower().replace(' ', '_').replace('-', '_')
                if emp_type not in VALID_EMPLOYMENT_TYPES:
                    old_value = job.employment_type
                    job.employment_type = 'full_time'
                    job_fixed = True
                    fix_details.append(f"employment_type: '{old_value}' -> 'full_time'")
            
            # Fix 2: Ensure title is not empty
            if not job.title or job.title.strip() == '':
                job.title = f"Job #{job.id} (Untitled)"
                job_fixed = True
                fix_details.append(f"Added default title: '{job.title}'")
            
            # Fix 3: Normalize employment_type casing
            if job.employment_type and job.employment_type != job.employment_type.lower():
                old_value = job.employment_type
                job.employment_type = job.employment_type.lower()
                job_fixed = True
                fix_details.append(f"Lowercased employment_type: '{old_value}' -> '{job.employment_type}'")
            
            # Fix 4: Fix swapped salary min/max
            if job.salary_min and job.salary_max and job.salary_min > job.salary_max:
                job.salary_min, job.salary_max = job.salary_max, job.salary_min
                job_fixed = True
                fix_details.append(f"Swapped salary min/max to correct order")
            
            if job_fixed:
                fixes.append({
                    'id': job.id,
                    'title': job.title,
                    'fixes': fix_details
                })
        
        # Commit all changes
        if fixes:
            db.session.commit()
            print(f"\n✓ Fixed {len(fixes)} jobs:\n")
            for fix in fixes:
                print(f"Job ID {fix['id']}: {fix['title']}")
                for detail in fix['fixes']:
                    print(f"  - {detail}")
        else:
            print("\n✓ No fixes needed - all jobs look good!")
        
        print("\n" + "=" * 70)
        print("FIX COMPLETE")
        print("=" * 70)

if __name__ == "__main__":
    fix_jobs()
