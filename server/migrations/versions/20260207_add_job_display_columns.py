"""Add job display columns to requisitions.

Revision ID: 20260207_add_job_display_columns
Revises: 
Create Date: 2026-02-07 18:00:00
"""

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = "20260207_add_job_display_columns"
down_revision = None
branch_labels = None
depends_on = None


def _column_exists(bind, table_name, column_name):
    inspector = sa.inspect(bind)
    return column_name in [col["name"] for col in inspector.get_columns(table_name)]


def upgrade():
    bind = op.get_bind()

    if not _column_exists(bind, "requisitions", "location"):
        op.add_column(
            "requisitions",
            sa.Column(
                "location",
                sa.String(length=150),
                server_default=sa.text("''"),
                nullable=True,
            ),
        )

    if not _column_exists(bind, "requisitions", "employment_type"):
        op.add_column(
            "requisitions",
            sa.Column(
                "employment_type",
                sa.String(length=80),
                server_default=sa.text("'Full Time'"),
                nullable=True,
            ),
        )

    if not _column_exists(bind, "requisitions", "salary_range"):
        op.add_column(
            "requisitions",
            sa.Column(
                "salary_range",
                sa.String(length=100),
                server_default=sa.text("''"),
                nullable=True,
            ),
        )

    if not _column_exists(bind, "requisitions", "application_deadline"):
        op.add_column(
            "requisitions",
            sa.Column("application_deadline", sa.DateTime(), nullable=True),
        )

    if not _column_exists(bind, "requisitions", "company"):
        op.add_column(
            "requisitions",
            sa.Column(
                "company",
                sa.String(length=200),
                server_default=sa.text("''"),
                nullable=True,
            ),
        )

    if not _column_exists(bind, "requisitions", "banner"):
        op.add_column(
            "requisitions",
            sa.Column("banner", sa.String(length=500), nullable=True),
        )


def downgrade():
    bind = op.get_bind()

    for column_name in ("banner", "application_deadline", "salary_range"):
        if _column_exists(bind, "requisitions", column_name):
            op.drop_column("requisitions", column_name)
