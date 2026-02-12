"""Legacy Render revision placeholder

Revision ID: 5e59a6f99a77
Revises:
Create Date: 2026-02-12

This revision exists only to satisfy databases that were stamped with
revision 5e59a6f99a77 before the current migration history was committed.

It is intentionally a no-op.

"""

from alembic import op

# revision identifiers, used by Alembic.
revision = "5e59a6f99a77"
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    pass


def downgrade():
    pass
