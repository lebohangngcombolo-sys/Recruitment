#!/usr/bin/env python3
"""
Test Cloudinary upload and functionality
"""

import os
import time
from dotenv import load_dotenv
import cloudinary
import cloudinary.uploader
import cloudinary.api

def test_cloudinary_upload():
    """Test Cloudinary upload with a test file"""
    print("☁️  Testing Cloudinary Upload\n")
    
    load_dotenv()
    
    # Get configuration
    cloud_name = os.getenv('CLOUDINARY_CLOUD_NAME')
    api_key = os.getenv('CLOUDINARY_API_KEY')
    api_secret = os.getenv('CLOUDINARY_API_SECRET')
    
    print(f"Cloud Name: {cloud_name}")
    print(f"API Key: {'✅ Configured' if api_key else '❌ Missing'}")
    print(f"API Secret: {'✅ Configured' if api_secret else '❌ Missing'}")
    
    if not all([cloud_name, api_key, api_secret]):
        print("❌ Missing Cloudinary configuration")
        return False
    
    # Configure Cloudinary
    cloudinary.config(
        cloud_name=cloud_name,
        api_key=api_key,
        api_secret=api_secret
    )
    
    try:
        # Test 1: Ping Cloudinary
        print("\n1. Testing Cloudinary connection...")
        ping_result = cloudinary.api.ping()
        print(f"✅ Cloudinary ping: {ping_result}")
        
        # Test 2: Upload a simple text file
        print("\n2. Uploading test file...")
        test_content = "Cloudinary Test File\n==================\n\nThis is a test file uploaded to Cloudinary from your Recruitment System.\n\nTest Details:\n- Upload Time: 2026-03-18 11:32:16\n- Cloud Name: dp4kugfk8\n- Test Purpose: Verify Cloudinary integration\n\n🚀 Your Cloudinary integration is working!"
        
        upload_result = cloudinary.uploader.upload(
            test_content,
            resource_type="raw",
            folder="recruitment_tests",
            public_id=f"test_file_{int(time.time())}",
            format="txt"
        )
        
        print(f"✅ Upload successful!")
        print(f"   URL: {upload_result['secure_url']}")
        print(f"   Public ID: {upload_result['public_id']}")
        print(f"   Size: {upload_result['bytes']} bytes")
        print(f"   Format: {upload_result.get('format', 'txt')}")
        
        # Test 3: Verify the uploaded file is accessible
        print("\n3. Verifying uploaded file...")
        resource = cloudinary.api.resource(upload_result['public_id'], resource_type="raw")
        
        if resource:
            print(f"✅ File is accessible!")
            print(f"   Secure URL: {resource['secure_url']}")
            print(f"   Resource Type: {resource.get('resource_type', 'raw')}")
            print(f"   Created At: {resource.get('created_at', 'N/A')}")
        else:
            print("❌ File not accessible")
            return False
        
        # Test 4: Upload your CV if it exists
        cv_path = "Dzunisani-Mabundas-Resume-Cv-Qualifications.pdf"
        if os.path.exists(cv_path):
            print(f"\n4. Testing CV upload: {cv_path}")
            
            with open(cv_path, 'rb') as f:
                cv_upload_result = cloudinary.uploader.upload(
                    f,
                    resource_type="raw",
                    folder="recruitment_tests",
                    public_id=f"test_cv_{int(time.time())}",
                    format="pdf"
                )
            
            print(f"✅ CV uploaded successfully!")
            print(f"   URL: {cv_upload_result['secure_url']}")
            print(f"   Size: {cv_upload_result['bytes']:,} bytes")
            print(f"   Public ID: {cv_upload_result['public_id']}")
            
            # Clean up CV test file
            cloudinary.api.delete_resources([cv_upload_result['public_id']], resource_type="raw")
            print("   ✅ Test CV cleaned up")
        
        # Test 5: Clean up test file
        print("\n5. Cleaning up test file...")
        cloudinary.api.delete_resources([upload_result['public_id']], resource_type="raw")
        print("✅ Test file cleaned up")
        
        print("\n🎉 All Cloudinary tests passed!")
        return True
        
    except Exception as e:
        print(f"❌ Cloudinary test failed: {e}")
        return False

if __name__ == "__main__":
    test_cloudinary_upload()
