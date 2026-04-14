import os
import sys
from pathlib import Path
import requests

# Load .env
server_dir = Path(__file__).resolve().parent.parent
_env_path = server_dir / ".env"
if _env_path.exists():
    from dotenv import load_dotenv
    load_dotenv(_env_path)

BASE_URL = "http://127.0.0.1:5000/api"
PASSWORD = "CaitlinPass123!"

USERS = [
    {"email": "caitlin_candidate@khonology.com", "role": "candidate"},
    {"email": "caitlin_hm@khonology.com", "role": "hiring_manager"},
    {"email": "caitlin_admin@khonology.com", "role": "admin"},
]

def test_login():
    print("Testing account logins...")
    for user in USERS:
        try:
            resp = requests.post(f"{BASE_URL}/auth/login", json={
                "email": user["email"],
                "password": PASSWORD
            })
            if resp.status_code == 200:
                data = resp.json()
                # Check role in response (if available) or via /me
                token = data.get("access_token")
                me_resp = requests.get(f"{BASE_URL}/auth/me", headers={"Authorization": f"Bearer {token}"})
                if me_resp.status_code == 200:
                    me_data = me_resp.json()
                    role = me_data.get("role")
                    if role == user["role"]:
                        print(f"✅ SUCCESS: {user['email']} logged in as {role}")
                    else:
                        print(f"❌ FAILED: {user['email']} expected role {user['role']}, got {role}")
                else:
                    print(f"❌ FAILED: {user['email']} could not access /me: {me_resp.text}")
            else:
                print(f"❌ FAILED: {user['email']} could not login: {resp.text}")
        except Exception as e:
            print(f"❌ ERROR: {user['email']} failed with {e}")

if __name__ == "__main__":
    # Note: This requires the server to be running.
    # I'll try to run the server in the background and then test.
    test_login()
