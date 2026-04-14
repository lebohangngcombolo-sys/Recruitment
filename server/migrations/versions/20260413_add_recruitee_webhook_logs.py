"""Add RecruiteeWebhookLog table for webhook tracking

Revision ID: 20260413_add_recruitee_webhook_logs
Revises: 20260413_add_recruitee_sync_history
Create Date: 2026-04-13 00:02:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '20260413_add_recruitee_webhook_logs'
down_revision = '20260413_add_recruitee_sync_history'
branch_labels = None
depends_on = None


def upgrade():
    from sqlalchemy import inspect
    
    conn = op.get_bind()
    inspector = inspect(conn)
    
    # Check if table already exists
    existing_tables = inspector.get_table_names()
    
    if 'recruitee_webhook_logs' not in existing_tables:
        op.create_table(
            'recruitee_webhook_logs',
            sa.Column('id', sa.Integer(), nullable=False, primary_key=True),
            sa.Column('event_id', sa.String(100), nullable=False, unique=True),  # Recruitee's event ID for idempotency
            sa.Column('event_type', sa.String(50), nullable=False),  # e.g., 'offer.created', 'candidate.updated'
            sa.Column('raw_payload', sa.JSON(), nullable=True, server_default='{}'),  # Full webhook payload JSON
            sa.Column('processed', sa.Boolean(), nullable=False, server_default='false'),
            sa.Column('processing_status', sa.String(20), nullable=False, server_default='pending'),  # pending, success, failed
            sa.Column('error_message', sa.Text(), nullable=True),
            sa.Column('processed_at', sa.DateTime(), nullable=True),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.text('CURRENT_TIMESTAMP')),
        )
        
        # Create indexes
        op.create_index('ix_recruitee_webhook_logs_event_id', 'recruitee_webhook_logs', ['event_id'], unique=True)
        op.create_index('ix_recruitee_webhook_logs_event_type', 'recruitee_webhook_logs', ['event_type'], unique=False)
        op.create_index('ix_recruitee_webhook_logs_created_at', 'recruitee_webhook_logs', ['created_at'], unique=False)


def downgrade():
    op.drop_table('recruitee_webhook_logs')
