#!/usr/bin/env python
"""Fix alembic version table"""
import psycopg2
import os

# Get database URL from env
db_url = os.getenv('DATABASE_URL', 'postgresql://recruitement_deploy_user:tHkpCaJ8nxQpN1tCItF7BEXNvzLrkgiQ@dpg-d62tb67pm1nc738h8jv0-a.oregon-postgres.render.com/recruitement_deploy?sslmode=require')

# Connect and fix alembic version
conn = psycopg2.connect(db_url)
cursor = conn.cursor()

# Get current versions
cursor.execute('SELECT version_num FROM alembic_version;')
versions = cursor.fetchall()
print(f'Current versions: {versions}')

# Check if bad revision exists
bad_revisions = []
for v in versions:
    if '20260324' in v[0] or 'hm_pipeline' in v[0]:
        bad_revisions.append(v[0])

if bad_revisions:
    print(f'Removing bad revisions: {bad_revisions}')
    for rev in bad_revisions:
        cursor.execute('DELETE FROM alembic_version WHERE version_num = %s;', (rev,))
    conn.commit()
    print('Fixed alembic_version table')

# Stamp with correct revision (7ec5a07c5b21 - before our new migration)
target_revision = '7ec5a07c5b21'
cursor.execute('DELETE FROM alembic_version;')
cursor.execute('INSERT INTO alembic_version (version_num) VALUES (%s);', (target_revision,))
conn.commit()
print(f'Stamped database with revision: {target_revision}')

conn.close()
print('Done!')
