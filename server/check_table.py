#!/usr/bin/env python3
from app import db
from app.models import CVAnalysis

print('CVAnalysis table exists:', CVAnalysis.__table__.exists(db.engine))