"""change last_cv_analysis_id to string

Revision ID: f2aec9395850
Revises: 527d061bb0e5
Create Date: 2026-04-05 17:56:22.206126

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'f2aec9395850'
down_revision = '527d061bb0e5'
branch_labels = None
depends_on = None


def upgrade():
    op.alter_column('candidates', 'last_cv_analysis_id',
               existing_type=sa.Integer(),
               type_=sa.String(length=255),
               existing_nullable=True,
               postgresql_using='last_cv_analysis_id::varchar')

def downgrade():
    op.alter_column('candidates', 'last_cv_analysis_id',
               existing_type=sa.String(length=255),
               type_=sa.Integer(),
               existing_nullable=True,
               postgresql_using='last_cv_analysis_id::integer')
