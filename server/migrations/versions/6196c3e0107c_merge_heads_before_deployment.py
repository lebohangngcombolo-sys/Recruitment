"""merge heads before deployment

Revision ID: 6196c3e0107c
Revises: 20260317_interview_approval, fix_cv_analyses_candidate_id
Create Date: 2026-03-24 07:05:05.517708

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '6196c3e0107c'
down_revision = ('20260317_interview_approval', 'fix_cv_analyses_candidate_id')
branch_labels = None
depends_on = None


def upgrade():
    pass


def downgrade():
    pass
