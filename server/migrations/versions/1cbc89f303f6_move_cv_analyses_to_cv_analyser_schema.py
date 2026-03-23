"""Move cv_analyses to cv_analyser schema

Revision ID: 1cbc89f303f6
Revises: 4be7809db296
Create Date: 2026-03-19 18:57:41.708603

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '1cbc89f303f6'
down_revision = '4be7809db296'
branch_labels = None
depends_on = None


def upgrade():
    # Create cv_analyser schema if it doesn't exist
    # Table is already in cv_analyser schema from manual migration
    op.execute("CREATE SCHEMA IF NOT EXISTS cv_analyser")


def downgrade():
    # Move cv_analyses back to public schema
    op.execute("ALTER TABLE cv_analyses SET SCHEMA public")
    
    # Note: We don't drop the cv_analyser schema as it might contain other tables
