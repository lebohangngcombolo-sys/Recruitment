"""add_db_indexes

Revision ID: 20260216_add_indexes
Revises: 
Create Date: 2026-02-16 00:10:00.000000

Adds recommended indexes for performance on frequently queried fields.
"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '20260216_add_indexes'
down_revision = '20260216_fix_requisition_duplicates'
branch_labels = None
depends_on = None

def upgrade():
    # Applications: composite index on (candidate_id, requisition_id)
    op.create_index('ix_applications_candidate_requisition', 'applications', ['candidate_id', 'requisition_id'])
    # Applications: index on (status, created_at)
    op.create_index('ix_applications_status_created_at', 'applications', ['status', 'created_at'])

    # Interviews: index on (candidate_id, scheduled_time)
    op.create_index('ix_interviews_candidate_scheduled', 'interviews', ['candidate_id', 'scheduled_time'])
    # Interviews: index on (hiring_manager_id, status)
    op.create_index('ix_interviews_hm_status', 'interviews', ['hiring_manager_id', 'status'])

    # Notifications: index on (user_id, is_read, created_at)
    op.create_index('ix_notifications_user_read_created', 'notifications', ['user_id', 'is_read', 'created_at'])

    # Requisitions: index on (is_active, deleted_at, category)
    op.create_index('ix_requisitions_active_deleted_category', 'requisitions', ['is_active', 'deleted_at', 'category'])


def downgrade():
    op.drop_index('ix_requisitions_active_deleted_category', table_name='requisitions')
    op.drop_index('ix_notifications_user_read_created', table_name='notifications')
    op.drop_index('ix_interviews_hm_status', table_name='interviews')
    op.drop_index('ix_interviews_candidate_scheduled', table_name='interviews')
    op.drop_index('ix_applications_status_created_at', table_name='applications')
    op.drop_index('ix_applications_candidate_requisition', table_name='applications')

