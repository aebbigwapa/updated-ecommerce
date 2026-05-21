import requests

api_key = "re_CpovRFCD_JRAxY2vDDiULCmXWLYy7GJLD"
test_email = "yasona.ryan11@gmail.com"

payload = {
    "from": "Grande Marketplace <onboarding@resend.dev>",
    "to": [test_email],
    "subject": "Test OTP - Grande",
    "html": "<h1>Your OTP: 123456</h1><p>This is a test email.</p>"
}

headers = {
    "Authorization": f"Bearer {api_key}",
    "Content-Type": "application/json"
}

print(f"Testing Resend API...")
print(f"Sending to: {test_email}")
print("-" * 50)

try:
    response = requests.post(
        'https://api.resend.com/emails',
        json=payload,
        headers=headers,
        timeout=10
    )
    
    print(f"Status Code: {response.status_code}")
    print(f"Response: {response.text}")
    
    if response.status_code in (200, 201):
        print("\n✅ SUCCESS! Check your email.")
    else:
        print(f"\n❌ FAILED!")
except Exception as e:
    print(f"Error: {e}")
