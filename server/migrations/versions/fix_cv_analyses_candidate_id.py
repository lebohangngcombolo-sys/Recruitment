"""Add missing candidate_id column to cv_analyses

Revision ID: fix_cv_analyses_candidate_id
Revises: 1cbc89f303f6
Create Date: 2026-03-23 10:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'fix_cv_analyses_candidate_id'
down_revision = '1cbc89f303f6'
branch_labels = None
depends_on = None


def upgrade():
    # Check if candidate_id column exists in cv_analyser.cv_analyses table
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    columns = [col['name'] for col in inspector.get_columns('cv_analyses', schema='cv_analyser')]
    
    if 'candidate_id' not in columns:
        # Add the missing candidate_id column
        op.execute("""
            ALTER TABLE cv_analyser.cv_analyses 
            ADD COLUMN candidate_id INTEGER REFERENCES candidates(id)
        """)
        
        # If there are existing records without candidate_id, try to populate from application
        op.execute("""
            UPDATE cv_analyser.cv_analyses ca
            SET candidate_id = a.candidate_id
            FROM applications a
            WHERE ca.application_id = a.id 
            AND ca.candidate_id IS NULL
        """)


def downgrade():
    # Remove the candidate_id column
    op.execute("ALTER TABLE cv_analyser.cv_analyses DROP COLUMN candidate_id")
