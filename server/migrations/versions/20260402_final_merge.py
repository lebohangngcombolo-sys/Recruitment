"""final merge for database synchronization

Revision ID: 20260402_final_merge
Revises: 20260402_merge_all_heads, 3347cad1b18f
Create Date: 2026-04-02 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '20260402_final_merge'
down_revision = ('20260402_merge_all_heads', '3347cad1b18f')
branch_labels = None
depends_on = None


def upgrade():
    pass


def downgrade():
    pass
