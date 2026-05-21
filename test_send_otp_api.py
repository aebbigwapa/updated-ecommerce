import requests
import json

# Test the send-otp API endpoint
url = "https://ecommerce-backend-o0hl.onrender.com/api/auth/send-otp"
payload = {"email": "yasona.ryan11@gmail.com"}

print(f"Testing: POST {url}")
print(f"Payload: {json.dumps(payload, indent=2)}")
print("-" * 50)

try:
    response = requests.post(url, json=payload, timeout=30)
    print(f"Status Code: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
except Exception as e:
    print(f"Error: {e}")
