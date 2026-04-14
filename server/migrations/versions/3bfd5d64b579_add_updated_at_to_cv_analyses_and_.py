"""add updated_at to cv_analyses and ethnicity to candidates

Revision ID: 3bfd5d64b579
Revises: 20260228_last_login
Create Date: 2026-03-08 10:41:13.121663

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '3bfd5d64b579'
down_revision = '20260228_last_login'
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table('candidates', schema=None) as batch_op:
        batch_op.add_column(sa.Column('ethnicity', sa.String(length=50), nullable=True))

    with op.batch_alter_table('cv_analyses', schema=None) as batch_op:
        batch_op.add_column(sa.Column('updated_at', sa.DateTime(), nullable=True))


def downgrade():
    with op.batch_alter_table('cv_analyses', schema=None) as batch_op:
        batch_op.drop_column('updated_at')

    with op.batch_alter_table('candidates', schema=None) as batch_op:
        batch_op.drop_column('ethnicity')
