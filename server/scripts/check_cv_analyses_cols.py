from app import create_app
from app.extensions import db
from sqlalchemy import inspect

app = create_app()
with app.app_context():
    inspector = inspect(db.engine)
    cols = inspector.get_columns('cv_analyses', schema='cv_analyser')
    print([col['name'] for col in cols])
