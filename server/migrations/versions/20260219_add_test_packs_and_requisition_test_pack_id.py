"""add test_packs and requisition.test_pack_id

Revision ID: 20260219_test_packs
Revises: 20260216_add_indexes
Create Date: 2026-02-19

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = '20260219_test_packs'
down_revision = '20260216_add_indexes'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'test_packs',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(length=200), nullable=False),
        sa.Column('category', sa.String(length=50), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('questions', postgresql.JSON(astext_type=sa.Text()), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.Column('updated_at', sa.DateTime(), nullable=True),
        sa.Column('deleted_at', sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint('id')
    )
    op.add_column('requisitions', sa.Column('test_pack_id', sa.Integer(), nullable=True))
    op.create_foreign_key(
        'fk_requisitions_test_pack_id',
        'requisitions',
        'test_packs',
        ['test_pack_id'],
        ['id']
    )


def downgrade():
    op.drop_constraint('fk_requisitions_test_pack_id', 'requisitions', type_='foreignkey')
    op.drop_column('requisitions', 'test_pack_id')
    op.drop_table('test_packs')
