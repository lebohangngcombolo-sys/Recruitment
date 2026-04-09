#!/usr/bin/env python3
"""Quick extraction test using existing analysis."""

import requests
import json

def test_existing_analysis():
    """Test using existing completed analysis."""
    print("Testing Bob Mabena CV Extraction (Existing Analysis)")
    print("=" * 60)
    
    # Use a known completed analysis ID
    job_id = "0e13cf5e-3ef1-43f1-b636-2118c33a8e94"  # Just submitted
    headers = {'Authorization': 'Bearer hf_PWzUkNotngsnBvpOHWLXOqXCbkdTgYHYzdF'}
    
    print(f"Checking analysis ID: {job_id}")
    
    # Check status first
    status_response = requests.get(
        f'https://dzunisani007-cv-analyser.hf.space/api/v1/analyze/{job_id}/status',
        headers=headers
    )
    
    if status_response.status_code == 200:
        status_data = status_response.json()
        status = status_data.get('status')
        print(f"Current status: {status}")
        
        if status == 'completed':
            print("Analysis completed! Getting results...")
            
            # Get results
            result_response = requests.get(
                f'https://dzunisani007-cv-analyser.hf.space/api/v1/analyze/{job_id}/result',
                headers=headers
            )
            
            if result_response.status_code == 200:
                result = result_response.json()
                print("\n" + "="*60)
                print("EXTRACTION RESULTS")
                print("="*60)
                
                # Check experience extraction
                experience = result.get('structured_data', {}).get('experience', [])
                print(f"\nEXPERIENCE ({len(experience)} entries):")
                for i, exp in enumerate(experience[:5], 1):
                    print(f"  {i}. Title: {exp.get('title', 'N/A')}")
                    print(f"     Company: {exp.get('company', 'N/A')}")
                    print(f"     Dates: {exp.get('start_date', 'N/A')} - {exp.get('end_date', 'N/A')}")
                    print()
                
                # Check education extraction
                education = result.get('structured_data', {}).get('education', [])
                print(f"EDUCATION ({len(education)} entries):")
                for i, edu in enumerate(education[:3], 1):
                    print(f"  {i}. Degree: {edu.get('degree', 'N/A')}")
                    print(f"     Institution: {edu.get('institution', 'N/A')}")
                    print(f"     Dates: {edu.get('start_date', 'N/A')} - {edu.get('end_date', 'N/A')}")
                    print()
                
                # Check quality metrics
                quality = result.get('quality_metrics', {})
                print(f"QUALITY SCORE: {quality.get('overall_score', 'N/A')}")
                print(f"QUALITY LEVEL: {quality.get('quality_level', 'N/A')}")
                
                # Check if extraction is working correctly
                print("\n" + "="*60)
                print("EXTRACTION VALIDATION")
                print("="*60)
                
                # Expected results for Bob Mabena
                expected_experience = "Data Analyst"
                expected_company = "Amazon Web Services"
                expected_education = "Bachelor of Science"
                expected_institution = "University"
                
                experience_correct = False
                education_correct = False
                
                # Check experience
                for exp in experience:
                    title = str(exp.get('title', '')).lower()
                    company = str(exp.get('company', '')).lower()
                    if expected_experience.lower() in title and expected_company.lower() in company:
                        experience_correct = True
                        print(f"Experience: CORRECT - {exp.get('title')} at {exp.get('company')}")
                        break
                
                if not experience_correct:
                    print(f"Experience: INCORRECT - Looking for '{expected_experience}' at '{expected_company}'")
                    print("Found entries:")
                    for exp in experience[:3]:
                        print(f"  - {exp.get('title')} at {exp.get('company')}")
                
                # Check education
                for edu in education:
                    degree = str(edu.get('degree', '')).lower()
                    institution = str(edu.get('institution', '')).lower()
                    if expected_education.lower() in degree and expected_institution.lower() in institution:
                        education_correct = True
                        print(f"Education: CORRECT - {edu.get('degree')} from {edu.get('institution')}")
                        break
                
                if not education_correct:
                    print(f"Education: INCORRECT - Looking for '{expected_education}' from '{expected_institution}'")
                    print("Found entries:")
                    for edu in education[:3]:
                        print(f"  - {edu.get('degree')} from {edu.get('institution')}")
                
                # Overall assessment
                print("\n" + "="*60)
                if experience_correct and education_correct:
                    print("SUCCESS: AI intelligence fixes are working correctly!")
                    print("The Hugging Face Space has been deployed with the latest fixes.")
                else:
                    print("FAILURE: AI intelligence fixes are NOT deployed yet.")
                    print("The Hugging Face Space is still running the old code.")
                    print("\nNEXT STEP: Deploy the AI intelligence fixes to Hugging Face Space")
                print("="*60)
                
            else:
                print(f"Failed to get results: {result_response.status_code}")
                print(result_response.text)
        else:
            print(f"Analysis not completed yet. Status: {status}")
            print("Let's try a previously completed analysis...")
            
            # Try a known completed analysis
            old_job_id = "b4f52a46-f41e-42c9-a204-57b0d7ca3a82"
            print(f"Trying old analysis ID: {old_job_id}")
            
            result_response = requests.get(
                f'https://dzunisani007-cv-analyser.hf.space/api/v1/analyze/{old_job_id}/result',
                headers=headers
            )
            
            if result_response.status_code == 200:
                result = result_response.json()
                print("\n" + "="*60)
                print("EXTRACTION RESULTS (OLD ANALYSIS)")
                print("="*60)
                
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
                
                print("\nThis shows the OLD extraction results (still broken)")
                print("The AI fixes need to be deployed to fix this.")
    else:
        print(f"Failed to check status: {status_response.status_code}")
        print(status_response.text)

if __name__ == "__main__":
    test_existing_analysis()
