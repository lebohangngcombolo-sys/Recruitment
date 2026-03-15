#!/bin/bash
# FastAPI Integration Migration Script for WSL Ubuntu
# Run this script in your WSL Ubuntu environment

echo "Starting FastAPI Integration Migration..."

# Navigate to server directory
cd /mnt/c/Users/User/Recruitment/server

# Activate virtual environment
source .venv/bin/activate

# Install missing dependencies if needed
pip install flask-limiter

# Run the migration
echo "Running database migration..."
python -m flask db upgrade

# Check if migration was successful
if [ $? -eq 0 ]; then
    echo "✅ Migration completed successfully!"
    echo ""
    echo "FastAPI Integration Summary:"
    echo "- Added external_analysis_id column to cv_analyses table"
    echo "- Created indexes for efficient polling"
    echo "- Updated CVAnalysis model"
    echo "- Created AnalysisServiceClient for external API communication"
    echo "- Created DataMerger for intelligent profile enrichment"
    echo "- Created background polling task"
    echo "- Updated upload endpoint to use external service"
    echo "- Updated HM reviews endpoint for new format"
    echo "- Commented out legacy Celery task for rollback"
    echo ""
    echo "Next steps:"
    echo "1. Set environment variables in .env:"
    echo "   ANALYSIS_SERVICE_URL=https://your-fastapi-service.com"
    echo "   ANALYSIS_SERVICE_API_KEY=your-secret-api-key"
    echo "2. Deploy your FastAPI analysis service"
    echo "3. Restart Celery workers with beat scheduler"
    echo "4. Test the integration"
else
    echo "❌ Migration failed. Please check the error above."
fi

echo "Migration script completed."
