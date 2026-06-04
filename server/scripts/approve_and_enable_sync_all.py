"""
Approve all pending jobs and enable Recruitee sync for testing.
Use this to prepare all jobs for Recruitee sync testing.
"""
import os
import sys
from datetime import datetime

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from app import create_app
from app.models import Requisition, db

app = create_app()
ADMIN_USER_ID = 51  # Use admin ID from your logs

def approve_and_enable_sync():
    with app.app_context():
        print("=" * 70)
        print("APPROVE ALL JOBS & ENABLE RECRUITEE SYNC")
        print("=" * 70)
        
        # Get all non-approved jobs
        pending_jobs = Requisition.query.filter(
            Requisition.approval_status != 'approved'
        ).all()
        
        print(f"\nFound {len(pending_jobs)} non-approved jobs\n")
        
        approved_count = 0
        enabled_count = 0
        
        for job in pending_jobs:
            old_status = job.approval_status
            
            # Approve the job
            job.approval_status = 'approved'
            job.approved_at = datetime.utcnow()
            job.approved_by = ADMIN_USER_ID
            job.rejection_reason = None
            approved_count += 1
            
            print(f"✓ Job {job.id}: {job.title}")
            print(f"  Status: {old_status} -> approved")
        
        # Enable sync for all approved jobs that don't have it enabled
        all_approved = Requisition.query.filter_by(approval_status='approved').all()
        
        print(f"\n{'='*70}")
        print(f"ENABLING RECRUITEE SYNC FOR {len(all_approved)} APPROVED JOBS")
        print(f"{'='*70}\n")
        
        for job in all_approved:
            if not job.sync_to_recruitee:
                job.sync_to_recruitee = True
                enabled_count += 1
                print(f"✓ Enabled sync for Job {job.id}: {job.title}")
        
        # Commit all changes
        db.session.commit()
        
        print(f"\n{'='*70}")
        print("SUMMARY")
        print(f"{'='*70}")
        print(f"Jobs approved: {approved_count}")
        print(f"Sync enabled: {enabled_count}")
        print(f"\n✓ All jobs are now ready for Recruitee sync testing!")
        print(f"{'='*70}")

if __name__ == "__main__":
    approve_and_enable_sync()
