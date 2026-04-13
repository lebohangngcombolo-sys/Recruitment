"""
Test script to diagnose Recruitee API 422 errors.
Directly tests the API with various payloads to find what works.
"""
import os
import sys
import json
import requests

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from app import create_app
from app.models import Requisition
from app.services.recruitee_client import RecruiteeClient, RecruiteeAPIError

app = create_app()

def test_recruitee_api():
    with app.app_context():
        # Get a job to test with
        job = Requisition.query.filter_by(id=37).first()
        if not job:
            print("❌ Job 37 not found")
            return
        
        print("=" * 70)
        print("RECRUITEE API DIAGNOSTIC TEST")
        print("=" * 70)
        print(f"\nJob: {job.title} (ID: {job.id})")
        print(f"Employment Type: {job.employment_type}")
        print(f"Is Active: {job.is_active}")
        print(f"Description length: {len(job.description or '')}")
        
        # Build minimal offer data
        minimal_offer = {
            "title": job.title or "Untitled Job",
            "status": "published" if job.is_active else "closed",
            "external_id": str(job.id)
        }
        
        print("\n" + "=" * 70)
        print("TEST 1: Minimal offer (only required fields)")
        print("=" * 70)
        print(f"Payload: {json.dumps({'offer': minimal_offer}, indent=2)}")
        
        client = RecruiteeClient()
        try:
            result = client.create_offer(minimal_offer)
            print(f"✅ SUCCESS: {json.dumps(result, indent=2)}")
        except RecruiteeAPIError as e:
            print(f"❌ FAILED: {e.message}")
            print(f"   Status: {e.status_code}")
            print(f"   Response: {e.response_body}")
        except Exception as e:
            print(f"❌ ERROR: {str(e)}")
        
        # Test with employment_type
        print("\n" + "=" * 70)
        print("TEST 2: With employment_type")
        print("=" * 70)
        offer_with_emp = {
            "title": job.title or "Untitled Job",
            "status": "published" if job.is_active else "closed",
            "external_id": str(job.id),
            "employment_type": job.employment_type or "full_time"
        }
        print(f"Payload: {json.dumps({'offer': offer_with_emp}, indent=2)}")
        
        try:
            result = client.create_offer(offer_with_emp)
            print(f"✅ SUCCESS: {json.dumps(result, indent=2)}")
        except RecruiteeAPIError as e:
            print(f"❌ FAILED: {e.message}")
            print(f"   Response: {e.response_body}")
        except Exception as e:
            print(f"❌ ERROR: {str(e)}")
        
        # Test with description
        print("\n" + "=" * 70)
        print("TEST 3: With description")
        print("=" * 70)
        offer_with_desc = {
            "title": job.title or "Untitled Job",
            "status": "published" if job.is_active else "closed",
            "external_id": str(job.id),
            "employment_type": job.employment_type or "full_time",
            "description": (job.description or "")[:500]  # Truncate to be safe
        }
        print(f"Payload: {json.dumps({'offer': offer_with_desc}, indent=2)}")
        
        try:
            result = client.create_offer(offer_with_desc)
            print(f"✅ SUCCESS: {json.dumps(result, indent=2)}")
        except RecruiteeAPIError as e:
            print(f"❌ FAILED: {e.message}")
            print(f"   Response: {e.response_body}")
        except Exception as e:
            print(f"❌ ERROR: {str(e)}")
        
        # Test full mapper output
        print("\n" + "=" * 70)
        print("TEST 4: Full mapper output (what sync actually sends)")
        print("=" * 70)
        from app.services.recruitee_mapper import requisition_to_offer
        full_offer = requisition_to_offer(job)
        print(f"Payload: {json.dumps({'offer': full_offer}, indent=2)}")
        
        try:
            result = client.create_offer(full_offer)
            print(f"✅ SUCCESS: {json.dumps(result, indent=2)}")
        except RecruiteeAPIError as e:
            print(f"❌ FAILED: {e.message}")
            print(f"   Response: {e.response_body}")
            
            # Try to analyze the error
            if e.response_body:
                try:
                    error_data = json.loads(e.response_body)
                    print(f"\n🔍 Error Analysis:")
                    if 'errors' in error_data:
                        for field, errors in error_data['errors'].items():
                            print(f"   - Field '{field}': {errors}")
                except:
                    pass
        except Exception as e:
            print(f"❌ ERROR: {str(e)}")

if __name__ == "__main__":
    test_recruitee_api()
