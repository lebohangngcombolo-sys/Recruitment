"""Merge legacy revision 5e59a6f99a77 with current migration chain

Revision ID: 8c2b6b1a9d21
Revises: d544fdd839da, 5e59a6f99a77
Create Date: 2026-02-12

This is a no-op merge revision that allows databases stamped with the legacy
revision 5e59a6f99a77 to upgrade into the current migration chain.

"""

from alembic import op

# revision identifiers, used by Alembic.
revision = "8c2b6b1a9d21"
down_revision = ("d544fdd839da", "5e59a6f99a77")
branch_labels = None
depends_on = None


def upgrade():
    pass


def downgrade():
    pass
