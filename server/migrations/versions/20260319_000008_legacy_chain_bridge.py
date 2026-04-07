"""legacy chain bridge for existing deployed revision

Revision ID: 20260319_000008
Revises: 20260317_interview_approval
Create Date: 2026-03-24
"""

from alembic import op


revision = "20260319_000008"
down_revision = "20260317_interview_approval"
branch_labels = None
depends_on = None


def upgrade():
    # No-op bridge revision to reconcile historical database version pointer.
    pass


def downgrade():
    pass

