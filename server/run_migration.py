#!/usr/bin/env python3
"""
Manual script to run the FastAPI integration migration
"""
import sys
import os
from pathlib import Path

# Add the server directory to Python path
server_dir = Path(__file__).parent
sys.path.insert(0, str(server_dir))

# Load environment variables
from dotenv import load_dotenv
env_path = server_dir / ".env"
if env_path.exists():
    load_dotenv(env_path)

try:
    # Import Flask app and create context
    from app import create_app
    from alembic.config import Config
    from alembic import command
    
    # Create Flask app and context
    app = create_app()
    with app.app_context():
        # Configure Alembic
        alembic_cfg = Config("migrations/alembic.ini")
        alembic_cfg.set_main_option('script_location', 'migrations')
        
        print("Running FastAPI integration migration...")
        command.upgrade(alembic_cfg, '20240314_add_external_analysis_id')
        print("Migration completed successfully!")
        
except Exception as e:
    print(f"Migration failed: {e}")
    sys.exit(1)
