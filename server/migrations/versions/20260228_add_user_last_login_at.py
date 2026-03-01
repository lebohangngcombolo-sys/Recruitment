"""add user last_login_at

Revision ID: 20260228_last_login
Revises: 20260219_test_packs
Create Date: 2026-02-28

"""
from alembic import op
import sqlalchemy as sa

revision = "20260228_last_login"
down_revision = "20260219_test_packs"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("users", sa.Column("last_login_at", sa.DateTime(), nullable=True))


def downgrade():
    op.drop_column("users", "last_login_at")
