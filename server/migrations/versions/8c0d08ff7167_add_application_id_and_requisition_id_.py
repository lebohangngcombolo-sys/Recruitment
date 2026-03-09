"""Add application_id and requisition_id to cv_analyses

Revision ID: 8c0d08ff7167
Revises: 3bfd5d64b579
Create Date: 2026-03-09 01:52:23.403869

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '8c0d08ff7167'
down_revision = '3bfd5d64b579'
branch_labels = None
depends_on = None


def upgrade():
    # Add application_id and requisition_id columns to cv_analyses table
    op.add_column('cv_analyses', sa.Column('application_id', sa.Integer(), nullable=True))
    op.add_column('cv_analyses', sa.Column('requisition_id', sa.Integer(), nullable=True))
    
    # Create foreign key constraints
    op.create_foreign_key(
        'fk_cv_analyses_application_id', 
        'cv_analyses', 
        'applications', 
        ['application_id'], 
        ['id']
    )
    op.create_foreign_key(
        'fk_cv_analyses_requisition_id', 
        'cv_analyses', 
        'requisitions', 
        ['requisition_id'], 
        ['id']
    )
    
    # Create indexes for performance
    op.create_index('ix_cv_analyses_application_id', 'cv_analyses', ['application_id'])
    op.create_index('ix_cv_analyses_requisition_id', 'cv_analyses', ['requisition_id'])


def downgrade():
    # Drop indexes
    op.drop_index('ix_cv_analyses_requisition_id', table_name='cv_analyses')
    op.drop_index('ix_cv_analyses_application_id', table_name='cv_analyses')
    
    # Drop foreign key constraints
    op.drop_constraint('fk_cv_analyses_requisition_id', table_name='cv_analyses', type_='foreignkey')
    op.drop_constraint('fk_cv_analyses_application_id', table_name='cv_analyses', type_='foreignkey')
    
    # Drop columns
    op.drop_column('cv_analyses', 'requisition_id')
    op.drop_column('cv_analyses', 'application_id')
