#!/usr/bin/env python3
"""
Test Cloudinary upload with actual CV document
"""

import os
from dotenv import load_dotenv
import cloudinary
import cloudinary.uploader
import cloudinary.api

def test_cv_upload():
    print("📄 Testing CV Upload to Cloudinary\n")
    
    load_dotenv()
    
    # Configure Cloudinary
    cloudinary.config(
        cloud_name=os.getenv('CLOUDINARY_CLOUD_NAME'),
        api_key=os.getenv('CLOUDINARY_API_KEY'),
        api_secret=os.getenv('CLOUDINARY_API_SECRET')
    )
    
    cv_path = "Dzunisani-Mabundas-Resume-Cv-Qualifications.pdf"
    
    if not os.path.exists(cv_path):
        print(f"❌ CV file not found: {cv_path}")
        return False
    
    file_size = os.path.getsize(cv_path)
    print(f"CV File: {cv_path}")
    print(f"File Size: {file_size:,} bytes ({file_size/1024/1024:.2f} MB)")
    
    try:
        # Test connection
        print("\n1. Testing Cloudinary connection...")
        ping = cloudinary.api.ping()
        print(f"✅ Connection: {ping}")
        
        # Upload CV
        print("\n2. Uploading CV to Cloudinary...")
        
        with open(cv_path, 'rb') as f:
            upload_result = cloudinary.uploader.upload(
                f,
                resource_type="raw",
                folder="recruitment_tests",
                public_id="dzunisani_cv_test.pdf",
                format="pdf"
            )
        
        cv_url = upload_result['secure_url']
        public_id = upload_result['public_id']
        
        print(f"✅ CV uploaded successfully!")
        print(f"   URL: {cv_url}")
        print(f"   Public ID: {public_id}")
        print(f"   Uploaded Size: {upload_result['bytes']:,} bytes")
        print(f"   Format: {upload_result.get('format', 'pdf')}")
        
        # Verify the uploaded CV is accessible
        print("\n3. Verifying CV access...")
        resource = cloudinary.api.resource(public_id, resource_type="raw")
        
        if resource:
            print(f"✅ CV is accessible!")
            print(f"   Secure URL: {resource['secure_url']}")
            print(f"   Resource Type: {resource.get('resource_type', 'raw')}")
            print(f"   Created At: {resource.get('created_at', 'N/A')}")
            print(f"   Bytes: {resource.get('bytes', 'N/A')}")
        else:
            print("❌ CV not accessible")
            return False
        
        # Test generating different URL formats
        print("\n4. Testing different URL formats...")
        
        # Test with transformation (thumbnail)
        thumbnail_url = cloudinary.utils.cloudinary_url(
            public_id,
            resource_type="raw",
            secure=True,
            format="pdf"
        )[0]
        
        print(f"✅ Direct URL: {thumbnail_url}")
        
        # Test signed URL (for secure access)
        try:
            signed_url, _ = cloudinary.utils.cloudinary_url(
                public_id,
                resource_type="raw",
                secure=True,
                sign_url=True,
                format="pdf"
            )
            print(f"✅ Signed URL: {signed_url[:100]}...")
        except Exception as e:
            print(f"⚠️  Signed URL generation failed: {e}")
        
        # Clean up
        print("\n5. Cleaning up test CV...")
        cloudinary.api.delete_resources([public_id], resource_type="raw")
        print("✅ Test CV deleted from Cloudinary")
        
        print("\n🎉 CV Upload Test PASSED!")
        print("✅ Your Cloudinary can handle PDF documents correctly!")
        return True
        
    except Exception as e:
        print(f"❌ CV upload test failed: {e}")
        return False

if __name__ == "__main__":
    test_cv_upload()
