
import sys
import requests
import json
import time
import os

# Force UTF-8 for console output to handle CV bullets
if sys.stdout.encoding.lower() != 'utf-8':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

def test_remote_mabena_extraction():
    # HF Base URL
    base_url = "https://dzunisani007-cv-analyser.hf.space"
    pdf_path = "Bob Mabena CV.pdf"
    
    if not os.path.exists(pdf_path):
        # Try full path if in different CWD
        pdf_path = r"c:\Users\User\Recruitment\Bob Mabena CV.pdf"
        if not os.path.exists(pdf_path):
            print(f"❌ File not found: {pdf_path}")
            return

    print(f"🧪 Testing Remote Extraction for: {os.path.basename(pdf_path)}")
    print("=" * 60)

    # 1. Upload File
    print("\n1. Uploading file to Hugging Face...")
    try:
        with open(pdf_path, "rb") as f:
            files = {"cv_file": (os.path.basename(pdf_path), f, "application/pdf")}
            data = {"job_description": "Senior Data Analyst with SQL and Python expertise"}
            
            response = requests.post(f"{base_url}/api/v1/analyze-file", files=files, data=data, timeout=60)
            
        if response.status_code not in [200, 202]:
            print(f"❌ Upload failed: {response.status_code} - {response.text}")
            return
            
        analysis_data = response.json()
        analysis_id = analysis_data.get("analysis_id")
        print(f"✅ Upload Success! Analysis ID: {analysis_id}")
        
    except Exception as e:
        print(f"❌ Upload Error: {e}")
        return

    # 2. Polling for results
    print("\n2. Polling for results...")
    max_retries = 30 # 30 * 2s = 60s
    for i in range(max_retries):
        try:
            status_resp = requests.get(f"{base_url}/api/v1/analyze/{analysis_id}/status")
            status_data = status_resp.json()
            status = status_data.get("status")
            progress = status_data.get("progress", 0)
            
            print(f"   [{i+1}] Status: {status} ({progress}%)")
            
            if status == "completed":
                print("✅ Analysis Completed!")
                break
            elif status == "failed":
                print(f"❌ Analysis FAILED: {status_data.get('warnings')}")
                return
                
            time.sleep(2)
        except Exception as e:
            print(f"   ⚠️ Polling error: {e}")
            time.sleep(2)
    else:
        print("❌ Polling timed out (Space might be starting up or slow)")
        return

    # 3. Retrieve and Validate Results
    print("\n3. Retrieving final results...")
    result_resp = requests.get(f"{base_url}/api/v1/analyze/{analysis_id}/result")
    result_data = result_resp.json()
    
    # Check for the Bob Mabena merge fix
    # The result matches the new normalized schema
    experience = result_data.get("experience", []) or result_data.get("structured_data", {}).get("experience", [])
    
    print("\n--- EXTRACTION VALIDATION ---")
    if experience:
        print(f"✅ Found {len(experience)} experience entries.")
        found_target = False
        for exp in experience:
            title = exp.get('title', '')
            company = exp.get('company', '')
            print(f"   📍 Job: {title} at {company}")
            
            if "Data Analyst" in str(title) and "Amazon" in str(company):
                found_target = True
                # The fix is to ensure section headers like 'PROFESSIONAL EXPERIENCE' 
                # or previous skills like 'Agile/Scrum' are NOT merged into the title.
                if "PROFESSIONAL" in str(title) or "Scrum" in str(title):
                    print("   ❌ ALERT: Section header or skill detected inside job title (Merging issue still present)")
                else:
                    print("   ✅ SUCCESS: Job title correctly isolated.")
        
        if not found_target:
            print("   ⚠️ WARNING: 'Amazon Data Analyst' role not found in experience list.")
    else:
        print("   ❌ ERROR: No experience extracted.")

    print("\n--- METADATA ---")
    meta = result_data.get("extraction_metadata", {})
    print(f"   Method: {meta.get('method')}")
    print(f"   Quality: {meta.get('quality')}")

if __name__ == "__main__":
    test_remote_mabena_extraction()
