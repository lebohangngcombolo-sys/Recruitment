#!/bin/bash
# Render start script for recruitment-api

# Run database migrations
flask db upgrade

# Start gunicorn server
gunicorn --config gunicorn_config.py wsgi:app
