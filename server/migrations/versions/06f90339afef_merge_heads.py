"""merge_heads

Revision ID: 06f90339afef
Revises: 20240314_add_external_analysis_id, 20260306_interview_slots
Create Date: 2026-03-15 15:14:44.729323

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '06f90339afef'
down_revision = ('20240314_add_external_analysis_id', '20260306_interview_slots')
branch_labels = None
depends_on = None


def upgrade():
    pass


def downgrade():
    pass
