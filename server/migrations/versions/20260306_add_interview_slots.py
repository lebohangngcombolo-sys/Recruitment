"""add interview_slots table for HM availability (smart scheduling)

Revision ID: 20260306_interview_slots
Revises: 20260306_req_start_certs
Create Date: 2026-03-06

"""
from alembic import op
import sqlalchemy as sa

revision = "20260306_interview_slots"
down_revision = "20260306_req_start_certs"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "interview_slots",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("hiring_manager_id", sa.Integer(), nullable=False),
        sa.Column("requisition_id", sa.Integer(), nullable=True),
        sa.Column("start_time", sa.DateTime(), nullable=False),
        sa.Column("end_time", sa.DateTime(), nullable=False),
        sa.Column("meeting_link", sa.String(500), nullable=True),
        sa.Column("interview_type", sa.String(50), nullable=True),
        sa.Column("interview_id", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(["hiring_manager_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["requisition_id"], ["requisitions.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["interview_id"], ["interviews.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_interview_slots_hiring_manager_id"), "interview_slots", ["hiring_manager_id"], unique=False)
    op.create_index(op.f("ix_interview_slots_start_time"), "interview_slots", ["start_time"], unique=False)


def downgrade():
    op.drop_index(op.f("ix_interview_slots_start_time"), table_name="interview_slots")
    op.drop_index(op.f("ix_interview_slots_hiring_manager_id"), table_name="interview_slots")
    op.drop_table("interview_slots")
