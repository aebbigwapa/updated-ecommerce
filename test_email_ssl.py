import smtplib
import os
from dotenv import load_dotenv

load_dotenv()

sender = os.getenv('EMAIL_ADDRESS')
password = os.getenv('EMAIL_PASSWORD')

print(f"Testing SMTP with: {sender}")
print(f"Password length: {len(password) if password else 0} chars")

# Try port 465 with SSL
try:
    with smtplib.SMTP_SSL('smtp.gmail.com', 465, timeout=10) as smtp:
        smtp.login(sender, password)
        print("SUCCESS: Gmail authentication works with SSL!")
except Exception as e:
    print(f"ERROR: {e}")
