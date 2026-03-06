"""add requisition start_date_from, start_date_to, min_years_per_skill, required_certifications

Revision ID: 20260306_req_start_certs
Revises: 20260228_last_login
Create Date: 2026-03-06

"""
from alembic import op
import sqlalchemy as sa

revision = "20260306_req_start_certs"
down_revision = "20260228_last_login"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("requisitions", sa.Column("start_date_from", sa.Date(), nullable=True))
    op.add_column("requisitions", sa.Column("start_date_to", sa.Date(), nullable=True))
    op.add_column("requisitions", sa.Column("min_years_per_skill", sa.JSON(), nullable=True))
    op.add_column("requisitions", sa.Column("required_certifications", sa.JSON(), nullable=True))


def downgrade():
    op.drop_column("requisitions", "required_certifications")
    op.drop_column("requisitions", "min_years_per_skill")
    op.drop_column("requisitions", "start_date_to")
    op.drop_column("requisitions", "start_date_from")
