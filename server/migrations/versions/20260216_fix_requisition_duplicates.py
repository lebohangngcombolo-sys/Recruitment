"""fix_requisition_duplicates

Revision ID: 20260216_fix_requisition_duplicates
Revises: 
Create Date: 2026-02-16 00:00:00.000000

No-op migration to document removal of duplicate Requisition field declarations
from the SQLAlchemy model file. This migration intentionally does not modify the
database schema because the duplicate definitions were source-level only and
should not require destructive changes to the existing database.
"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '20260216_fix_requisition_duplicates'
down_revision = 'b6b9a43a3778'
branch_labels = None
depends_on = None

def upgrade():
    # Widen alembic_version.version_num so long revision IDs (e.g. 20260216_fix_requisition_duplicates) fit.
    op.execute("ALTER TABLE alembic_version ALTER COLUMN version_num TYPE VARCHAR(64);")
    # No other schema changes (duplicate Requisition was source-only).

def downgrade():
    # No-op
    pass

