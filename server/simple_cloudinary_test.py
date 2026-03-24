#!/usr/bin/env python3
"""
Simple Cloudinary test
"""

import os
from dotenv import load_dotenv
import cloudinary
import cloudinary.uploader
import cloudinary.api

def test_cloudinary():
    print("☁️  Simple Cloudinary Test\n")
    
    load_dotenv()
    
    # Configure Cloudinary
    cloudinary.config(
        cloud_name=os.getenv('CLOUDINARY_CLOUD_NAME'),
        api_key=os.getenv('CLOUDINARY_API_KEY'),
        api_secret=os.getenv('CLOUDINARY_API_SECRET')
    )
    
    try:
        # Test connection
        print("1. Testing connection...")
        ping = cloudinary.api.ping()
        print(f"✅ Ping: {ping}")
        
        # Upload simple content
        print("2. Uploading test file...")
        result = cloudinary.uploader.upload(
            b"Cloudinary test content",
            resource_type="raw",
            folder="test",
            public_id="simple_test.txt"
        )
        
        print(f"✅ Upload successful!")
        print(f"   URL: {result['secure_url']}")
        print(f"   Size: {result['bytes']} bytes")
        
        # Verify access
        print("3. Verifying access...")
        resource = cloudinary.api.resource("test/simple_test.txt", resource_type="raw")
        print(f"✅ Access verified: {resource['secure_url']}")
        
        # Clean up
        print("4. Cleaning up...")
        cloudinary.api.delete_resources(["test/simple_test.txt"], resource_type="raw")
        print("✅ Test file deleted")
        
        print("\n🎉 Cloudinary test PASSED!")
        return True
        
    except Exception as e:
        print(f"❌ Test failed: {e}")
        return False

if __name__ == "__main__":
    test_cloudinary()
