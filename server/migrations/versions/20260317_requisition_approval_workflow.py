"""add requisition approval_status, approved_at, approved_by, rejection_reason

Revision ID: 20260317_approval
Revises: 20260306_interview_slots
Create Date: 2026-03-17

"""
from alembic import op
import sqlalchemy as sa

revision = "20260317_approval"
down_revision = "20260306_interview_slots"
branch_labels = None
depends_on = None


def upgrade():
    # Helper for checking columns to avoid failures if they already exist
    from sqlalchemy import inspect
    bind = op.get_bind()
    insp = inspect(bind)
    existing_cols = [c["name"] for c in insp.get_columns("requisitions")]

    if "approval_status" not in existing_cols:
        op.add_column("requisitions", sa.Column("approval_status", sa.String(20), nullable=False, server_default="pending"))
    if "approved_at" not in existing_cols:
        op.add_column("requisitions", sa.Column("approved_at", sa.DateTime(), nullable=True))
    if "approved_by" not in existing_cols:
        op.add_column("requisitions", sa.Column("approved_by", sa.Integer(), sa.ForeignKey("users.id"), nullable=True))
    if "rejection_reason" not in existing_cols:
        op.add_column("requisitions", sa.Column("rejection_reason", sa.Text(), nullable=True))
        
    # Set existing active requisitions to approved so candidates keep seeing them
    op.execute(sa.text(
        "UPDATE requisitions SET approval_status = 'approved' WHERE is_active = true AND deleted_at IS NULL AND approval_status = 'pending'"
    ))


def downgrade():
    op.drop_column("requisitions", "rejection_reason")
    op.drop_column("requisitions", "approved_by")
    op.drop_column("requisitions", "approved_at")
    op.drop_column("requisitions", "approval_status")
