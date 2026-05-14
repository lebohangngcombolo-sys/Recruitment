"""add interview approval workflow fields

Revision ID: 20260317_interview_approval
Revises: 20260317_approval
Create Date: 2026-03-17

"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "20260317_interview_approval"
down_revision = "20260317_approval"
branch_labels = None
depends_on = None


def upgrade():
    # Helper for checking columns
    from sqlalchemy import inspect
    bind = op.get_bind()
    insp = inspect(bind)
    existing_cols = [c["name"] for c in insp.get_columns("interviews")]

    if "approval_status" not in existing_cols:
        op.add_column(
            "interviews",
            sa.Column("approval_status", sa.String(20), nullable=False, server_default="approved"),
        )
    if "approved_at" not in existing_cols:
        op.add_column("interviews", sa.Column("approved_at", sa.DateTime(), nullable=True))
    if "approved_by" not in existing_cols:
        op.add_column(
            "interviews",
            sa.Column("approved_by", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
        )
    if "rejection_reason" not in existing_cols:
        op.add_column("interviews", sa.Column("rejection_reason", sa.Text(), nullable=True))

    # Ensure pre-existing interviews remain visible to candidates
    op.execute(sa.text("UPDATE interviews SET approval_status = 'approved' WHERE approval_status IS NULL"))


def downgrade():
    op.drop_column("interviews", "rejection_reason")
    op.drop_column("interviews", "approved_by")
    op.drop_column("interviews", "approved_at")
    op.drop_column("interviews", "approval_status")

