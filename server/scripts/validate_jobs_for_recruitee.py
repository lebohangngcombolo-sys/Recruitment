"""
Validate all jobs in the database for Recruitee compatibility.
Run this to identify data issues before syncing.
"""
import os
import sys

# Add parent directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from app import create_app
from app.models import Requisition, db

app = create_app()

VALID_EMPLOYMENT_TYPES = ['full_time', 'part_time', 'contract', 'internship', 'temporary']

def validate_jobs():
    with app.app_context():
        print("=" * 70)
        print("RECRUITEE JOB VALIDATION REPORT")
        print("=" * 70)
        
        # Get all jobs
        jobs = Requisition.query.all()
        print(f"\nTotal jobs in database: {len(jobs)}\n")
        
        issues = []
        warnings = []
        
        for job in jobs:
            job_issues = []
            job_warnings = []
            
            # Check 1: Title is required
            if not job.title or job.title.strip() == '':
                job_issues.append("Missing title (REQUIRED)")
            
            # Check 2: Title length (Recruitee might have limits)
            if job.title and len(job.title) > 200:
                job_warnings.append(f"Title very long ({len(job.title)} chars)")
            
            # Check 3: Employment type
            if job.employment_type:
                emp_type_normalized = job.employment_type.lower().replace(' ', '_').replace('-', '_')
                if emp_type_normalized not in VALID_EMPLOYMENT_TYPES:
                    job_warnings.append(f"Unusual employment_type: '{job.employment_type}' (will map to 'full_time')")
            
            # Check 4: Description length
            if job.description and len(job.description) > 10000:
                job_warnings.append(f"Description very long ({len(job.description)} chars)")
            
            # Check 5: Salary data
            if job.salary_min and job.salary_max:
                if job.salary_min > job.salary_max:
                    job_warnings.append(f"salary_min ({job.salary_min}) > salary_max ({job.salary_max})")
            
            # Check 6: Approval status for sync
            if job.approval_status != 'approved':
                job_warnings.append(f"Not approved (status: {job.approval_status}) - CANNOT SYNC")
            
            # Check 7: Sync enabled
            if not job.sync_to_recruitee:
                job_warnings.append("sync_to_recruitee is False - sync disabled")
            
            # Check 8: Required skills format
            if job.required_skills:
                if not isinstance(job.required_skills, list):
                    job_warnings.append(f"required_skills is not a list: {type(job.required_skills)}")
            
            # Check 9: Qualifications format
            if job.qualifications:
                if not isinstance(job.qualifications, list):
                    job_warnings.append(f"qualifications is not a list: {type(job.qualifications)}")
            
            # Record issues
            if job_issues:
                issues.append({
                    'id': job.id,
                    'title': job.title or 'NO TITLE',
                    'issues': job_issues
                })
            
            if job_warnings:
                warnings.append({
                    'id': job.id,
                    'title': job.title or 'NO TITLE',
                    'warnings': job_warnings
                })
        
        # Print critical issues
        print("\n" + "=" * 70)
        print(f"❌ CRITICAL ISSUES (will cause sync to fail): {len(issues)}")
        print("=" * 70)
        if issues:
            for item in issues:
                print(f"\nJob ID {item['id']}: {item['title']}")
                for issue in item['issues']:
                    print(f"  - {issue}")
        else:
            print("\n✓ No critical issues found!")
        
        # Print warnings
        print("\n" + "=" * 70)
        print(f"⚠️  WARNINGS (may cause unexpected behavior): {len(warnings)}")
        print("=" * 70)
        if warnings:
            for item in warnings:
                print(f"\nJob ID {item['id']}: {item['title']}")
                for warning in item['warnings']:
                    print(f"  - {warning}")
        else:
            print("\n✓ No warnings!")
        
        # Summary
        print("\n" + "=" * 70)
        print("SUMMARY")
        print("=" * 70)
        print(f"Total jobs: {len(jobs)}")
        print(f"Jobs with critical issues: {len(issues)}")
        print(f"Jobs with warnings: {len(warnings)}")
        print(f"Jobs ready for sync: {len(jobs) - len(issues)}")
        
        # Show approved jobs that can sync
        approved_jobs = Requisition.query.filter_by(approval_status='approved').count()
        sync_enabled_jobs = Requisition.query.filter_by(
            approval_status='approved', 
            sync_to_recruitee=True
        ).count()
        print(f"\nApproved jobs: {approved_jobs}")
        print(f"Approved + sync enabled: {sync_enabled_jobs}")
        
        return issues, warnings

if __name__ == "__main__":
    validate_jobs()
