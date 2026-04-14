#!/usr/bin/env python3
"""Test Bob Mabena CV specifically."""

import requests
import time
import json

def test_bob_mabena_cv():
    """Test Bob Mabena CV specifically."""
    print("Testing Bob Mabena CV Extraction")
    print("=" * 50)
    
    try:
        with open("Bob Mabena CV.pdf", 'rb') as f:
            files = {'cv_file': ('Bob Mabena CV.pdf', f, 'application/pdf')}
            headers = {'Authorization': 'Bearer hf_PWzUkNotngsnBvpOHWLXOqXCbkdTgYHYzdF'}
            
            print("Submitting Bob Mabena CV for analysis...")
            response = requests.post(
                'https://dzunisani007-cv-analyser.hf.space/api/v1/analyze-file',
                files=files,
                headers=headers
            )
            
            print(f"Status Code: {response.status_code}")
            
            if response.status_code == 202:
                job_data = response.json()
                print(f"Response data: {job_data}")
                job_id = job_data.get('job_id') or job_data.get('id') or job_data.get('analysis_id')
                print(f"Job ID: {job_id}")
                
                # Poll for results
                print("Monitoring analysis progress...")
                for attempt in range(1, 61):
                    status_response = requests.get(
                        f'https://dzunisani007-cv-analyser.hf.space/api/v1/analyze/{job_id}/status',
                        headers=headers
                    )
                    
                    if status_response.status_code == 200:
                        status_data = status_response.json()
                        status = status_data.get('status')
                        print(f"Attempt {attempt}: {status}")
                        
                        if status == 'completed':
                            print("Analysis completed!")
                            break
                        elif status == 'failed':
                            print("Analysis failed!")
                            return
                    
                    time.sleep(3)
                else:
                    print("Analysis timed out!")
                    return
                
                # Get results
                result_response = requests.get(
                    f'https://dzunisani007-cv-analyser.hf.space/api/v1/analyze/{job_id}/result',
                    headers=headers
                )
                
                if result_response.status_code == 200:
                    result = result_response.json()
                    print("\n" + "="*50)
                    print("EXTRACTION RESULTS")
                    print("="*50)
                    
                    # Check experience extraction
                    experience = result.get('structured_data', {}).get('experience', [])
                    print(f"\nEXPERIENCE ({len(experience)} entries):")
                    for i, exp in enumerate(experience[:3], 1):
                        print(f"  {i}. {exp.get('title', 'N/A')} at {exp.get('company', 'N/A')}")
                    
                    # Check education extraction
                    education = result.get('structured_data', {}).get('education', [])
                    print(f"\nEDUCATION ({len(education)} entries):")
                    for i, edu in enumerate(education[:3], 1):
                        print(f"  {i}. {edu.get('degree', 'N/A')} from {edu.get('institution', 'N/A')}")
                    
                    # Check quality metrics
                    quality = result.get('quality_metrics', {})
                    print(f"\nQUALITY SCORE: {quality.get('overall_score', 'N/A')}")
                    print(f"QUALITY LEVEL: {quality.get('quality_level', 'N/A')}")
                    
                    # Check if extraction is working correctly
                    print("\n" + "="*50)
                    print("EXTRACTION VALIDATION")
                    print("="*50)
                    
                    # Expected results for Bob Mabena
                    expected_experience = "Data Analyst"
                    expected_company = "Amazon Web Services (AWS)"
                    expected_education = "Bachelor of Science in Data Science"
                    expected_institution = "University of Cape Town"
                    
                    experience_correct = False
                    education_correct = False
                    
                    # Check experience
                    for exp in experience:
                        if expected_experience in str(exp.get('title', '')) and expected_company in str(exp.get('company', '')):
                            experience_correct = True
                            print(f"Experience: CORRECT - {exp.get('title')} at {exp.get('company')}")
                            break
                    
                    if not experience_correct:
                        print(f"Experience: INCORRECT - Expected '{expected_experience}' at '{expected_company}'")
                    
                    # Check education
                    for edu in education:
                        if expected_education in str(edu.get('degree', '')) and expected_institution in str(edu.get('institution', '')):
                            education_correct = True
                            print(f"Education: CORRECT - {edu.get('degree')} from {edu.get('institution')}")
                            break
                    
                    if not education_correct:
                        print(f"Education: INCORRECT - Expected '{expected_education}' from '{expected_institution}'")
                    
                    # Overall assessment
                    print("\n" + "="*50)
                    if experience_correct and education_correct:
                        print("SUCCESS: AI intelligence fixes are working correctly!")
                        print("The Hugging Face Space has been deployed with the latest fixes.")
                    else:
                        print("FAILURE: AI intelligence fixes are NOT deployed yet.")
                        print("The Hugging Face Space is still running the old code.")
                    print("="*50)
                    
                else:
                    print(f"Failed to get results: {result_response.status_code}")
                    print(result_response.text)
            else:
                print(f"Failed to submit CV: {response.status_code}")
                print(response.text)
                
    except FileNotFoundError:
        print("ERROR: Bob Mabena CV.pdf not found in current directory")
    except Exception as e:
        print(f"ERROR: {e}")

if __name__ == "__main__":
    test_bob_mabena_cv()