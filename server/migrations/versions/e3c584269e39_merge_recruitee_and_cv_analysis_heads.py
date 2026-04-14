"""merge recruitee and cv_analysis heads

Revision ID: e3c584269e39
Revises: 20260413_add_recruitee_webhook_logs, f2aec9395850
Create Date: 2026-04-13 14:20:12.398362

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'e3c584269e39'
down_revision = ('20260413_add_recruitee_webhook_logs', 'f2aec9395850')
branch_labels = None
depends_on = None


def upgrade():
    pass


def downgrade():
    pass
