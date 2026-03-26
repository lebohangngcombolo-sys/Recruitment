#!/usr/bin/env python3
"""
Comprehensive test for Cloudinary and SendGrid integration
"""

import os
import sys
import requests
import cloudinary
import cloudinary.uploader
import cloudinary.api
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail

def test_cloudinary():
    """Test Cloudinary upload and download functionality"""
    print("=== Testing Cloudinary ===")
    
    # Check configuration
    cloud_name = os.getenv('CLOUDINARY_CLOUD_NAME')
    api_key = os.getenv('CLOUDINARY_API_KEY')
    api_secret = os.getenv('CLOUDINARY_API_SECRET')
    
    print(f"Cloud Name: {cloud_name}")
    print(f"API Key: {api_key[:10]}..." if api_key else "Not set")
    print(f"API Secret: {'*' * len(api_secret) if api_secret else 'Not set'}")
    
    if not all([cloud_name, api_key, api_secret]):
        print("❌ Cloudinary not properly configured")
        return False
    
    # Configure Cloudinary
    cloudinary.config(
        cloud_name=cloud_name,
        api_key=api_key,
        api_secret=api_secret
    )
    
    try:
        # Test connection
        print("\n1. Testing Cloudinary connection...")
        ping_result = cloudinary.api.ping()
        print(f"✅ Cloudinary ping: {ping_result}")
        
        # Test upload with a simple text file
        print("\n2. Testing file upload...")
        test_content = b"This is a test file for Cloudinary upload"
        
        upload_result = cloudinary.uploader.upload(
            test_content,
            resource_type="raw",
            folder="test_uploads",
            public_id="test_file",
            format="txt"
        )
        
        print(f"✅ Upload successful: {upload_result['secure_url']}")
        print(f"   Public ID: {upload_result['public_id']}")
        print(f"   Size: {upload_result['bytes']} bytes")
        
        # Test download/access
        print("\n3. Testing file access...")
        resource = cloudinary.api.resource(upload_result['public_id'], resource_type="raw")
        print(f"✅ Resource accessible: {resource['secure_url']}")
        
        # Clean up
        print("\n4. Cleaning up test file...")
        cloudinary.api.delete_resources([upload_result['public_id']], resource_type="raw")
        print("✅ Test file deleted")
        
        return True
        
    except Exception as e:
        print(f"❌ Cloudinary test failed: {e}")
        return False

def test_sendgrid():
    """Test SendGrid email functionality"""
    print("\n=== Testing SendGrid ===")
    
    # Check configuration
    api_key = os.getenv('MAIL_PASSWORD')  # SendGrid API key is stored here
    sender_email = os.getenv('MAIL_DEFAULT_SENDER')
    test_email = os.getenv('TEST_EMAIL')
    
    print(f"API Key: {api_key[:10]}..." if api_key else "Not set")
    print(f"Sender Email: {sender_email}")
    print(f"Test Email: {test_email}")
    
    if not all([api_key, sender_email, test_email]):
        print("❌ SendGrid not properly configured")
        print("   Required: MAIL_PASSWORD, MAIL_DEFAULT_SENDER, TEST_EMAIL")
        return False
    
    try:
        # Initialize SendGrid client
        sg = SendGridAPIClient(api_key)
        
        # Create test email
        message = Mail(
            from_email=sender_email,
            to_emails=test_email,
            subject='Cloudinary & SendGrid Integration Test',
            html_content='''
            <h2>✅ Integration Test Successful</h2>
            <p>This is a test email to verify SendGrid integration with your recruitment system.</p>
            <p><strong>Services tested:</strong></p>
            <ul>
                <li>✅ SendGrid API connection</li>
                <li>✅ Email delivery</li>
                <li>✅ HTML content rendering</li>
            </ul>
            <p><em>Sent from Recruitment System Test Suite</em></p>
            '''
        )
        
        # Send email
        print("\n1. Sending test email...")
        response = sg.send(message)
        
        print(f"✅ Email sent successfully!")
        print(f"   Status Code: {response.status_code}")
        print(f"   Headers: {dict(response.headers)}")
        
        if response.status_code == 202:
            print("✅ Email accepted for delivery by SendGrid")
            return True
        else:
            print(f"⚠️  Unexpected status code: {response.status_code}")
            return False
            
    except Exception as e:
        print(f"❌ SendGrid test failed: {e}")
        return False

def test_cv_upload_workflow():
    """Test the complete CV upload workflow using the actual CV file"""
    print("\n=== Testing CV Upload Workflow ===")
    
    cv_path = "Dzunisani-Mabundas-Resume-Cv-Qualifications.pdf"
    
    if not os.path.exists(cv_path):
        print(f"❌ CV file not found: {cv_path}")
        return False
    
    try:
        print(f"1. Found CV file: {cv_path}")
        file_size = os.path.getsize(cv_path)
        print(f"   File size: {file_size:,} bytes")
        
        # Test upload to Cloudinary
        print("\n2. Uploading CV to Cloudinary...")
        
        with open(cv_path, 'rb') as f:
            upload_result = cloudinary.uploader.upload(
                f,
                resource_type="raw",
                folder="test_cv_uploads",
                use_filename=True,
                unique_filename=False,
                format="pdf"
            )
        
        print(f"✅ CV uploaded successfully!")
        print(f"   URL: {upload_result['secure_url']}")
        print(f"   Public ID: {upload_result['public_id']}")
        
        # Test access
        print("\n3. Testing CV access...")
        resource = cloudinary.api.resource(upload_result['public_id'], resource_type="raw")
        print(f"✅ CV accessible: {resource['secure_url']}")
        print(f"   Format: {resource.get('format', 'unknown')}")
        print(f"   Size: {resource.get('bytes', 'unknown')} bytes")
        
        # Clean up
        print("\n4. Cleaning up test CV...")
        cloudinary.api.delete_resources([upload_result['public_id']], resource_type="raw")
        print("✅ Test CV deleted")
        
        return True
        
    except Exception as e:
        print(f"❌ CV upload workflow failed: {e}")
        return False

def main():
    """Run all tests"""
    print("🚀 Starting Cloudinary & SendGrid Integration Tests\n")
    
    # Load environment variables
    from dotenv import load_dotenv
    load_dotenv()
    
    results = []
    
    # Test Cloudinary
    results.append(("Cloudinary", test_cloudinary()))
    
    # Test SendGrid
    results.append(("SendGrid", test_sendgrid()))
    
    # Test CV upload workflow
    results.append(("CV Upload Workflow", test_cv_upload_workflow()))
    
    # Summary
    print("\n" + "="*50)
    print("📊 TEST SUMMARY")
    print("="*50)
    
    all_passed = True
    for service, passed in results:
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"{service:<20} {status}")
        if not passed:
            all_passed = False
    
    print("="*50)
    if all_passed:
        print("🎉 ALL TESTS PASSED! Your Cloudinary and SendGrid integration is working correctly.")
    else:
        print("⚠️  Some tests failed. Please check the configuration above.")
    
    return 0 if all_passed else 1

if __name__ == "__main__":
    sys.exit(main())
