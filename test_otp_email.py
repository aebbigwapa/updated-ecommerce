import os
from dotenv import load_dotenv

load_dotenv()

# Test the fixed email service
from services.email_service import send_otp_email

test_email = input("Enter your email to test: ").strip()
test_otp = "123456"

print(f"\nSending OTP email to: {test_email}")
print(f"Using SMTP: {os.getenv('SMTP_SERVER')}:{os.getenv('SMTP_PORT')}")
print(f"From: {os.getenv('EMAIL_ADDRESS')}")
print("-" * 50)

success = send_otp_email(test_email, "Test User", test_otp)

if success:
    print("\n✅ SUCCESS! Email sent successfully!")
    print(f"Check {test_email} for the OTP email")
else:
    print("\n❌ FAILED! Email was not sent")
    print("Check the error messages above")
