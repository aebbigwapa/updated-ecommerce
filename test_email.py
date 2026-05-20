import smtplib
import os
from dotenv import load_dotenv

load_dotenv()

sender = os.getenv('EMAIL_ADDRESS')
password = os.getenv('EMAIL_PASSWORD')

print(f"Testing SMTP with: {sender}")
print(f"Password length: {len(password) if password else 0} chars")

try:
    with smtplib.SMTP('smtp.gmail.com', 587, timeout=10) as smtp:
        smtp.starttls()
        smtp.login(sender, password)
        print("SUCCESS: Gmail authentication works!")
except smtplib.SMTPAuthenticationError as e:
    print(f"AUTH ERROR: {e}")
    print("\nFix:")
    print("1. Go to https://myaccount.google.com/apppasswords")
    print("2. Generate new app password")
    print("3. Update EMAIL_PASSWORD in .env")
except Exception as e:
    print(f"ERROR: {e}")
