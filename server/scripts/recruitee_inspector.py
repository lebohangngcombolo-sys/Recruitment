import sys
import os
import json
from pathlib import Path

# Add project root to path
sys.path.append(str(Path(__file__).resolve().parent.parent))

try:
    from app import create_app
    from app.services.recruitee_client import RecruiteeClient
    
    app = create_app()
    with app.app_context():
        print("🔍 --- RECRUITEE MASTER INSPECTOR ---")
        client = RecruiteeClient()
        
        def dump_endpoint(label, path):
            print(f"\n--- {label} ({path}) ---")
            try:
                data = client._request("GET", path)
                print(json.dumps(data, indent=2))
                return data
            except Exception as e:
                print(f"Error fetching {label}: {str(e)}")
                return {}

        # 1. Check locations (MANDATORY FOR NEW OFFERS)
        dump_endpoint("LOCATIONS", "/locations")
        
        # 2. Check full detail of ONE offer (to see work_model format)
        offers = client.get_offers(limit=1)
        if offers.get('offers'):
            offer_id = offers['offers'][0]['id']
            dump_endpoint(f"SAMPLE OFFER DETAIL (ID: {offer_id})", f"/offers/{offer_id}")
        
        # 3. Check stages
        dump_endpoint("STAGES", "/stages")
        
        # 4. Check departments
        dump_endpoint("DEPARTMENTS", "/departments")

        print("\n✅ --- INSPECTION COMPLETE ---")

except Exception as e:
    print(f"\nCRITICAL ERROR: {str(e)}")
