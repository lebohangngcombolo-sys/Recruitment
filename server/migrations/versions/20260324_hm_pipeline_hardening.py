"""hm pipeline hardening: app updated_at and indexes

Revision ID: 20260324_hm_pipeline_hardening
Revises: 20260317_interview_approval
Create Date: 2026-03-24
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = "20260324_hm_pipeline_hardening"
down_revision = "20260319_000008"
branch_labels = None
depends_on = None


def _has_column(table_name, column_name):
    bind = op.get_bind()
    insp = inspect(bind)
    cols = [c["name"] for c in insp.get_columns(table_name)]
    return column_name in cols


def _has_index(table_name, index_name):
    bind = op.get_bind()
    insp = inspect(bind)
    idx = [i["name"] for i in insp.get_indexes(table_name)]
    return index_name in idx


def upgrade():
    if not _has_column("applications", "updated_at"):
        op.add_column(
            "applications",
            sa.Column(
                "updated_at",
                sa.DateTime(),
                nullable=True,
                server_default=sa.text("CURRENT_TIMESTAMP"),
            ),
        )
        op.execute(
            sa.text(
                "UPDATE applications SET updated_at = created_at WHERE updated_at IS NULL"
            )
        )

    if not _has_index("applications", "ix_applications_requisition_status_created"):
        op.create_index(
            "ix_applications_requisition_status_created",
            "applications",
            ["requisition_id", "status", "created_at"],
            unique=False,
        )

    if not _has_index("requisitions", "ix_requisitions_created_by_active_deleted"):
        op.create_index(
            "ix_requisitions_created_by_active_deleted",
            "requisitions",
            ["created_by", "is_active", "deleted_at"],
            unique=False,
        )

    if not _has_index("interview_slots", "ix_interview_slots_hm_start_end"):
        op.create_index(
            "ix_interview_slots_hm_start_end",
            "interview_slots",
            ["hiring_manager_id", "start_time", "end_time"],
            unique=False,
        )


def downgrade():
    if _has_index("interview_slots", "ix_interview_slots_hm_start_end"):
        op.drop_index("ix_interview_slots_hm_start_end", table_name="interview_slots")
    if _has_index("requisitions", "ix_requisitions_created_by_active_deleted"):
        op.drop_index(
            "ix_requisitions_created_by_active_deleted", table_name="requisitions"
        )
    if _has_index("applications", "ix_applications_requisition_status_created"):
        op.drop_index(
            "ix_applications_requisition_status_created", table_name="applications"
        )
    if _has_column("applications", "updated_at"):
        op.drop_column("applications", "updated_at")

