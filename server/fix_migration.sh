#!/bin/bash
# Fix migration heads and run FastAPI integration

echo "Checking migration heads..."

cd /mnt/c/Users/User/Recruitment/server
source .venv/bin/activate

# Check current heads
echo "Current migration heads:"
python -m flask db heads

echo ""
echo "Current migration history:"
python -m flask db history

echo ""
echo "Checking for our FastAPI migration..."
python -m flask db show 20240314_add_external_analysis_id

echo ""
echo "If you see multiple heads above, we need to merge them."
echo "Let's try to upgrade to our specific migration:"

# Try to upgrade to our specific migration
python -m flask db upgrade 20240314_add_external_analysis_id

if [ $? -eq 0 ]; then
    echo "✅ FastAPI migration completed successfully!"
else
    echo "❌ Migration failed. Trying alternative approach..."
    echo "Let's check if we need to merge heads first."
    
    # Show current state
    python -m flask db current
    python -m flask db heads
    
    echo ""
    echo "If there are multiple heads, you may need to run:"
    echo "python -m flask db merge heads -m 'merge_heads'"
    echo "python -m flask db upgrade"
fi
