#!/usr/bin/env python3
"""Pre-deployment verification script for Recruitee integration

Run this script before deploying to production to ensure:
1. All migrations are properly created
2. Database models match migrations
3. Environment variables are configured
4. No hardcoded secrets in code
5. Webhook security is configured
"""

import sys
import os

# Add server to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

def check_migrations():
    """Verify all Recruitee migrations exist"""
    print("\n=== Checking Migrations ===")
    
    required_migrations = [
        '20260413_add_recruitee_integration.py',
        '20260413_add_recruitee_sync_history.py', 
        '20260413_add_recruitee_webhook_logs.py'
    ]
    
    migrations_dir = os.path.join(os.path.dirname(__file__), '..', 'migrations', 'versions')
    
    for migration in required_migrations:
        path = os.path.join(migrations_dir, migration)
        if os.path.exists(path):
            print(f"  ✓ {migration}")
        else:
            print(f"  ✗ {migration} - MISSING")
            return False
    
    return True

def check_environment_variables():
    """Check required environment variables"""
    print("\n=== Checking Environment Variables ===")
    
    required_vars = [
        'RECRUITEE_ENABLED',
        'RECRUITEE_COMPANY_ID',
        'RECRUITEE_API_TOKEN',
        'RECRUITEE_WEBHOOK_SECRET',
    ]
    
    missing = []
    for var in required_vars:
        value = os.environ.get(var)
        if value:
            # Don't print the actual secret values
            if 'SECRET' in var or 'TOKEN' in var or 'API' in var:
                print(f"  ✓ {var} is set (value hidden)")
            else:
                print(f"  ✓ {var} = {value}")
        else:
            print(f"  ✗ {var} - NOT SET")
            missing.append(var)
    
    return len(missing) == 0

def check_models():
    """Verify Recruitee models can be imported"""
    print("\n=== Checking Database Models ===")
    
    try:
        from app import create_app
        from app.models import RecruiteeSyncHistory, Requisition, Candidate
        
        # Check if models have Recruitee fields
        req_fields = [col.name for col in Requisition.__table__.columns]
        cand_fields = [col.name for col in Candidate.__table__.columns]
        
        required_req_fields = ['recruitee_id', 'sync_to_recruitee', 'last_synced_at', 'last_synced_source']
        required_cand_fields = ['recruitee_id', 'sync_to_recruitee', 'last_synced_at', 'last_synced_source']
        
        missing_req = [f for f in required_req_fields if f not in req_fields]
        missing_cand = [f for f in required_cand_fields if f not in cand_fields]
        
        if missing_req:
            print(f"  ✗ Requisition missing fields: {missing_req}")
            return False
        else:
            print(f"  ✓ Requisition has all Recruitee fields")
        
        if missing_cand:
            print(f"  ✗ Candidate missing fields: {missing_cand}")
            return False
        else:
            print(f"  ✓ Candidate has all Recruitee fields")
        
        print(f"  ✓ RecruiteeSyncHistory model available")
        
        return True
    except Exception as e:
        print(f"  ✗ Error checking models: {e}")
        return False

def check_webhook_security():
    """Verify webhook signature validation is configured"""
    print("\n=== Checking Webhook Security ===")
    
    webhook_secret = os.environ.get('RECRUITEE_WEBHOOK_SECRET')
    
    if not webhook_secret:
        print("  ✗ RECRUITEE_WEBHOOK_SECRET not set - webhooks will fail verification")
        return False
    
    if len(webhook_secret) < 20:
        print(f"  ⚠ Webhook secret seems short ({len(webhook_secret)} chars) - verify this is correct")
    else:
        print(f"  ✓ Webhook secret configured ({len(webhook_secret)} chars)")
    
    # Check if webhook endpoint exists
    try:
        routes_path = os.path.join(os.path.dirname(__file__), '..', 'app', 'routes', 'recruitee_routes.py')
        with open(routes_path, 'r') as f:
            content = f.read()
            if 'verify_signature' in content or 'hmac' in content.lower():
                print("  ✓ Webhook signature verification code found")
            else:
                print("  ⚠ Webhook signature verification not found in routes - verify manually")
    except Exception as e:
        print(f"  ⚠ Could not verify webhook routes: {e}")
    
    return True

def check_for_hardcoded_secrets():
    """Scan for hardcoded credentials"""
    print("\n=== Checking for Hardcoded Secrets ===")
    
    dangerous_patterns = [
        'khonology1',  # Company ID
        'uG6JPh',      # API token pattern
        'uio9NJQX',    # Webhook secret pattern
        '130989',      # Company ID
    ]
    
    server_dir = os.path.join(os.path.dirname(__file__), '..', 'app')
    
    issues_found = []
    for root, dirs, files in os.walk(server_dir):
        # Skip cache directories
        dirs[:] = [d for d in dirs if d != '__pycache__' and not d.endswith('.pyc')]
        
        for file in files:
            if file.endswith('.py'):
                filepath = os.path.join(root, file)
                try:
                    with open(filepath, 'r', encoding='utf-8') as f:
                        content = f.read()
                        for pattern in dangerous_patterns:
                            if pattern in content:
                                issues_found.append(f"  ⚠ Potential secret '{pattern}' found in {filepath}")
                except:
                    pass
    
    if issues_found:
        for issue in issues_found:
            print(issue)
        print("\n  Review these files manually to ensure no secrets are hardcoded!")
        return False
    else:
        print("  ✓ No obvious hardcoded secrets found")
        return True

def main():
    """Run all checks"""
    print("=" * 60)
    print("PRE-DEPLOYMENT VERIFICATION FOR RECRUITEE INTEGRATION")
    print("=" * 60)
    
    checks = [
        ("Migrations", check_migrations),
        ("Environment Variables", check_environment_variables),
        ("Database Models", check_models),
        ("Webhook Security", check_webhook_security),
        ("Hardcoded Secrets", check_for_hardcoded_secrets),
    ]
    
    results = []
    for name, check_func in checks:
        try:
            result = check_func()
            results.append((name, result))
        except Exception as e:
            print(f"\n  ✗ Error in {name} check: {e}")
            results.append((name, False))
    
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    
    all_passed = True
    for name, result in results:
        status = "✓ PASS" if result else "✗ FAIL"
        print(f"  {status}: {name}")
        if not result:
            all_passed = False
    
    print("\n" + "=" * 60)
    if all_passed:
        print("✓ ALL CHECKS PASSED - READY FOR DEPLOYMENT")
        print("=" * 60)
        return 0
    else:
        print("✗ SOME CHECKS FAILED - FIX ISSUES BEFORE DEPLOYING")
        print("=" * 60)
        return 1

if __name__ == '__main__':
    sys.exit(main())
