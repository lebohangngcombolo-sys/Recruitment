import sys
import os
from pathlib import Path

# Add the current directory to sys.path to allow importing from 'app'
sys.path.append(str(Path(__file__).resolve().parent.parent))

try:
    from app import create_app
    from app.services.recruitee_client import RecruiteeClient
    
    app = create_app()
    with app.app_context():
        print("--- Recruitee INTEGRATION FIX DIAGNOSTIC ---")
        client = RecruiteeClient()
        
        # 1. Fetch one existing offer in detail
        print("\n[1/2] Analyzing existing Job Schema...")
        offers_data = client.get_offers(limit=1)
        offers = offers_data.get('offers', [])
        
        if offers:
            offer = offers[0]
            print(f"Sample Job: {offer.get('title')}")
            print(f"  Current Location IDs: {offer.get('location_ids', offer.get('assigned_location_ids'))}")
            print(f"  Current Work Model: {offer.get('work_model')}")
        else:
            print("  No offers found to sample.")

        # 2. Fetch all available Locations for the company
        print("\n[2/2] Fetching active company locations...")
        try:
            # Try both common endpoints
            locations = client._request("GET", "/locations")
            loc_list = locations.get('locations', [])
            print(f"  Found {len(loc_list)} Active Locations:")
            for l in loc_list:
                print(f"    - ID: {l.get('id')} | Name: {l.get('name')}")
        except Exception as e:
            print(f"  Error fetching locations: {e}")

        print("\n--- Diagnostic Complete ---")

except Exception as e:
    print(f"\nError: {str(e)}")
