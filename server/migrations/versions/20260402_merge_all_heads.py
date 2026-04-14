"""merge multiple heads for unified database schema

Revision ID: 20260402_merge_all_heads
Revises: 20260328_add_analyser_sync_columns_fixed, 20260324_hm_pipeline_hardening, 3347cad1b18f
Create Date: 2026-04-02 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '20260402_merge_all_heads'
down_revision = ('20260328_add_analyser_sync_columns_fixed', '20260324_hm_pipeline_hardening')
branch_labels = None
depends_on = None


def upgrade():
    pass


def downgrade():
    pass
