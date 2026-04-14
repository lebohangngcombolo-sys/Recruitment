"""Add RecruiteeSyncHistory table for audit logging

Revision ID: 20260413_add_recruitee_sync_history
Revises: 20260413_add_recruitee_integration
Create Date: 2026-04-13 00:01:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '20260413_add_recruitee_sync_history'
down_revision = '20260413_add_recruitee_integration'
branch_labels = None
depends_on = None


def upgrade():
    from sqlalchemy import inspect
    
    conn = op.get_bind()
    inspector = inspect(conn)
    
    # Check if table already exists
    existing_tables = inspector.get_table_names()
    
    if 'recruitee_sync_history' not in existing_tables:
        # Create table with all columns matching the model
        op.create_table(
            'recruitee_sync_history',
            sa.Column('id', sa.Integer(), nullable=False, primary_key=True),
            sa.Column('entity_type', sa.String(20), nullable=False),  # 'job' or 'candidate'
            sa.Column('entity_id', sa.Integer(), nullable=False),  # local requisition_id or candidate_id
            sa.Column('recruitee_id', sa.String(100), nullable=True),  # Recruitee's ID
            sa.Column('action', sa.String(20), nullable=False),  # 'create', 'update', 'delete', 'retry'
            sa.Column('status', sa.String(20), nullable=False, server_default='pending'),  # 'success', 'failed', 'pending', 'skipped'
            sa.Column('error_message', sa.Text(), nullable=True),
            sa.Column('retry_count', sa.Integer(), nullable=False, server_default='0'),
            sa.Column('max_retries', sa.Integer(), nullable=False, server_default='3'),
            sa.Column('next_retry_at', sa.DateTime(), nullable=True),
            sa.Column('request_data', sa.JSON(), nullable=False, server_default='{}'),
            sa.Column('response_data', sa.JSON(), nullable=False, server_default='{}'),
            sa.Column('synced_by', sa.Integer(), sa.ForeignKey('users.id'), nullable=True),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.text('CURRENT_TIMESTAMP')),
            sa.Column('completed_at', sa.DateTime(), nullable=True),
        )
        
        # Create indexes
        op.create_index('ix_recruitee_sync_history_entity', 'recruitee_sync_history', ['entity_type', 'entity_id'], unique=False)
        op.create_index('ix_recruitee_sync_history_status', 'recruitee_sync_history', ['status'], unique=False)
        op.create_index('ix_recruitee_sync_history_created_at', 'recruitee_sync_history', ['created_at'], unique=False)
        op.create_index('ix_recruitee_sync_history_recruitee_id', 'recruitee_sync_history', ['recruitee_id'], unique=False)


def downgrade():
    op.drop_table('recruitee_sync_history')
