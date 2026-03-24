from app import create_app
from app.extensions import db
from sqlalchemy import inspect

app = create_app()
with app.app_context():
    inspector = inspect(db.engine)
    print("Public tables:", inspector.get_table_names(schema='public'))
    print("CV Analyser tables:", inspector.get_table_names(schema='cv_analyser'))
