"""Add Recruitee ATS integration columns to requisitions and candidates

Revision ID: 20260413_add_recruitee_integration
Revises: 20260402_final_merge
Create Date: 2026-04-13 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '20260413_add_recruitee_integration'
down_revision = '20260402_final_merge'
branch_labels = None
depends_on = None


def upgrade():
    from sqlalchemy import inspect
    
    conn = op.get_bind()
    inspector = inspect(conn)
    
    # Get existing columns
    req_columns = [col['name'] for col in inspector.get_columns('requisitions')]
    cand_columns = [col['name'] for col in inspector.get_columns('candidates')]
    
    # Add Recruitee columns to requisitions table if they don't exist
    if 'recruitee_id' not in req_columns:
        op.add_column('requisitions', sa.Column('recruitee_id', sa.String(100), nullable=True))
    
    if 'sync_to_recruitee' not in req_columns:
        op.add_column('requisitions', sa.Column('sync_to_recruitee', sa.Boolean(), nullable=False, server_default='false'))
    
    if 'last_synced_at' not in req_columns:
        op.add_column('requisitions', sa.Column('last_synced_at', sa.DateTime(), nullable=True))
    
    if 'last_synced_source' not in req_columns:
        op.add_column('requisitions', sa.Column('last_synced_source', sa.String(20), nullable=True))
    
    # Create index for requisitions if it doesn't exist
    existing_indexes = [idx['name'] for idx in inspector.get_indexes('requisitions')]
    if 'ix_requisitions_recruitee_id' not in existing_indexes and 'recruitee_id' in req_columns:
        op.create_index('ix_requisitions_recruitee_id', 'requisitions', ['recruitee_id'], unique=False)
    
    # Add Recruitee columns to candidates table if they don't exist
    if 'recruitee_id' not in cand_columns:
        op.add_column('candidates', sa.Column('recruitee_id', sa.String(100), nullable=True))
    
    if 'sync_to_recruitee' not in cand_columns:
        op.add_column('candidates', sa.Column('sync_to_recruitee', sa.Boolean(), nullable=False, server_default='false'))
    
    if 'last_synced_at' not in cand_columns:
        op.add_column('candidates', sa.Column('last_synced_at', sa.DateTime(), nullable=True))
    
    if 'last_synced_source' not in cand_columns:
        op.add_column('candidates', sa.Column('last_synced_source', sa.String(20), nullable=True))
    
    # Create index for candidates if it doesn't exist
    existing_cand_indexes = [idx['name'] for idx in inspector.get_indexes('candidates')]
    if 'ix_candidates_recruitee_id' not in existing_cand_indexes and 'recruitee_id' in cand_columns:
        op.create_index('ix_candidates_recruitee_id', 'candidates', ['recruitee_id'], unique=False)


def downgrade():
    # Drop columns from requisitions
    op.drop_index('ix_requisitions_recruitee_id', table_name='requisitions')
    op.drop_column('requisitions', 'last_synced_source')
    op.drop_column('requisitions', 'last_synced_at')
    op.drop_column('requisitions', 'sync_to_recruitee')
    op.drop_column('requisitions', 'recruitee_id')
    
    # Drop columns from candidates
    op.drop_index('ix_candidates_recruitee_id', table_name='candidates')
    op.drop_column('candidates', 'last_synced_source')
    op.drop_column('candidates', 'last_synced_at')
    op.drop_column('candidates', 'sync_to_recruitee')
    op.drop_column('candidates', 'recruitee_id')
