import os
from dotenv import load_dotenv
import requests

load_dotenv()

backend_url = os.getenv("BACKEND_URL", "http://localhost:5000")
login_url = f"{backend_url}/api/auth/login"
data = {"email": "lebohangngcombolo@gmail.com", "password": "stenamantech"}

r = requests.post(login_url, json=data)
tokens = r.json()

access_token = tokens.get("access_token")
print("Access Token:", access_token)
