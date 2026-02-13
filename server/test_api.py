#!/usr/bin/env python3
"""
Test script to verify the enhanced API endpoints work correctly
"""

import requests
import json
from datetime import datetime

BASE_URL = "http://127.0.0.1:5000"

def test_endpoint(endpoint, description):
    """Test an endpoint and print results"""
    print(f"\n=== Testing {description} ===")
    print(f"Endpoint: {endpoint}")
    
    try:
        response = requests.get(f"{BASE_URL}{endpoint}")
        print(f"Status Code: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            print(f"Response Keys: {list(data.keys())}")
            
            # Print sample of the data structure
            if 'candidates' in data:
                candidates = data['candidates']
                print(f"Total candidates: {len(candidates)}")
                if candidates:
                    print(f"Sample candidate keys: {list(candidates[0].keys())}")
                    if 'statistics' in candidates[0]:
                        print(f"Sample statistics keys: {list(candidates[0]['statistics'].keys())}")
            
            if 'candidate_demographics' in data:
                demographics = data['candidate_demographics']
                print(f"Demographics keys: {list(demographics.keys())}")
                
        else:
            print(f"Error: {response.text}")
            
    except Exception as e:
        print(f"Exception: {e}")

def main():
    print("API Testing Script")
    print("=" * 50)
    
    # Test endpoints (without auth - will show structure)
    test_endpoint("/", "Root endpoint")
    test_endpoint("/api/admin/dashboard-counts", "Dashboard counts (requires auth)")
    test_endpoint("/api/admin/candidates", "Candidates endpoint (requires auth)")
    
    print(f"\n=== Test completed at {datetime.now()} ===")

if __name__ == "__main__":
    main()
