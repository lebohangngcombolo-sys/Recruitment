import time
from unittest.mock import MagicMock, patch
import logging
import sys
import os

# Add server to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'server'))

from app.services.analysis_service_client import AnalysisServiceClient

# Setup logging to see the backoff in action
logging.basicConfig(level=logging.INFO)

def test_polling_backoff():
    print("Testing Polling Exponential Backoff...")
    
    mock_status = MagicMock()
    # First 3 calls return 'processing', then 'completed'
    mock_status.side_effect = [
        {"status": "processing"},
        {"status": "processing"},
        {"status": "processing"},
        {"status": "completed"}
    ]
    
    # Mock result call
    mock_result = MagicMock(return_value={"result": "success"})
    
    with patch.object(AnalysisServiceClient, 'get_analysis_status', mock_status), \
         patch.object(AnalysisServiceClient, 'get_analysis_result', mock_result):
        
        start_time = time.time()
        result = AnalysisServiceClient.wait_for_result(
            "test-id", 
            initial_poll_interval=0.1,  # Small for fast test
            max_poll_interval=0.5
        )
        end_time = time.time()
        
        duration = end_time - start_time
        print(f"Polling took {duration:.2f} seconds and {mock_status.call_count} calls.")
        
        assert result == {"result": "success"}
        assert mock_status.call_count == 4
        print("✅ Polling backoff test passed!")

if __name__ == "__main__":
    try:
        test_polling_backoff()
    except Exception as e:
        print(f"❌ Polling test failed: {e}")
        import traceback
        traceback.print_exc()
