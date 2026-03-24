#!/usr/bin/env python3
"""
Test CV Analysis Service Integration with Cloudinary
"""

import os
import sys
import requests
import cloudinary
import cloudinary.uploader
import time
from dotenv import load_dotenv

def test_cv_analysis_integration():
    """Test the complete CV analysis workflow"""
    print("=== Testing CV Analysis Service Integration ===")
    
    load_dotenv()
    
    # Configuration
    analysis_url = os.getenv('ANALYSIS_SERVICE_URL', 'https://cv-analyser-kt1u.onrender.com')
    api_key = os.getenv('ANALYSIS_SERVICE_API_KEY')
    cv_path = "Dzunisani-Mabundas-Resume-Cv-Qualifications.pdf"
    
    print(f"Analysis Service: {analysis_url}")
    print(f"API Key: {api_key[:10]}..." if api_key else "Not set")
    
    if not os.path.exists(cv_path):
        print(f"❌ CV file not found: {cv_path}")
        return False
    
    try:
        # Step 1: Upload CV to Cloudinary
        print("\n1. Uploading CV to Cloudinary...")
        cloudinary.config(
            cloud_name=os.getenv('CLOUDINARY_CLOUD_NAME'),
            api_key=os.getenv('CLOUDINARY_API_KEY'),
            api_secret=os.getenv('CLOUDINARY_API_SECRET')
        )
        
        with open(cv_path, 'rb') as f:
            upload_result = cloudinary.uploader.upload(
                f,
                resource_type="raw",
                folder="cv_analysis_test",
                use_filename=True,
                unique_filename=True,
                format="pdf"
            )
        
        cv_url = upload_result['secure_url']
        print(f"✅ CV uploaded to: {cv_url}")
        
        # Step 2: Submit for analysis
        print("\n2. Submitting CV for analysis...")
        
        headers = {
            'Content-Type': 'application/json',
            'X-API-Key': api_key
        }
        
        data = {
            'cv_url': cv_url,
            'job_description': 'Senior Software Engineer position requiring 5+ years of experience in Python, Django, and cloud technologies.'
        }
        
        response = requests.post(f"{analysis_url}/upload", 
                                files={'file': open(cv_path, 'rb')},
                                data={'job_description': 'Senior Software Engineer position requiring 5+ years of experience in Python, Django, and cloud technologies.'},
                                headers={'Authorization': f'Bearer {api_key}'})
        
        if response.status_code != 202:
            print(f"❌ Failed to submit analysis: {response.status_code}")
            print(f"Response: {response.text}")
            return False
        
        analysis_data = response.json()
        analysis_id = analysis_data.get('analysis_id')
        
        print(f"✅ Analysis submitted successfully")
        print(f"   Analysis ID: {analysis_id}")
        
        # Step 3: Poll for results
        print("\n3. Polling for analysis results...")
        
        max_attempts = 30
        for attempt in range(max_attempts):
            # First check status
            status_response = requests.get(f"{analysis_url}/analyses/{analysis_id}/status", 
                                         headers={'Authorization': f'Bearer {api_key}'})
            
            if status_response.status_code == 200:
                status_data = status_response.json()
                status = status_data.get('status')
                
                print(f"   Attempt {attempt + 1}: Status = {status}")
                
                if status == 'completed':
                    # Get the full result
                    result_response = requests.get(f"{analysis_url}/analyses/{analysis_id}/result",
                                                 headers={'Authorization': f'Bearer {api_key}'})
                    
                    if result_response.status_code == 200:
                        result = result_response.json()
                        print("✅ Analysis completed successfully!")
                        
                        # Display results
                        print(f"\n📊 Analysis Results:")
                        print(f"   Overall Score: {result.get('overall_score', 'N/A')}")
                        print(f"   Experience Match: {result.get('experience_match', 'N/A')}")
                        print(f"   Skills Match: {result.get('skills_match', 'N/A')}")
                        print(f"   Recommendation: {result.get('recommendation', 'N/A')}")
                        
                        # Clean up
                        print("\n4. Cleaning up...")
                        cloudinary.api.delete_resources([upload_result['public_id']], resource_type="raw")
                        print("✅ Test CV deleted from Cloudinary")
                        
                        return True
                    else:
                        print(f"❌ Failed to get results: {result_response.status_code}")
                        return False
                
                elif status == 'failed':
                    error = status_data.get('error', 'Unknown error')
                    print(f"❌ Analysis failed: {error}")
                    return False
                
            else:
                print(f"   Attempt {attempt + 1}: HTTP {status_response.status_code}")
            
            time.sleep(2)
        
        print("❌ Analysis timed out after 30 attempts")
        return False
        
    except Exception as e:
        print(f"❌ Integration test failed: {e}")
        return False

def main():
    print("🚀 CV Analysis Service Integration Test\n")
    
    if test_cv_analysis_integration():
        print("\n🎉 CV Analysis Integration Test PASSED!")
        print("Your complete system (Cloudinary + CV Analysis Service) is working correctly.")
        return 0
    else:
        print("\n❌ CV Analysis Integration Test FAILED!")
        return 1

if __name__ == "__main__":
    sys.exit(main())
