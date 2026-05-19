#!/usr/bin/env python3
"""
Startup script to test imports and catch errors
"""
import sys
import traceback

print("=" * 50)
print("Testing imports...")
print("=" * 50)

try:
    print("1. Testing Flask...")
    from flask import Flask
    print("   ✓ Flask OK")
except Exception as e:
    print(f"   ✗ Flask FAILED: {e}")
    traceback.print_exc()
    sys.exit(1)

try:
    print("2. Testing dotenv...")
    from dotenv import load_dotenv
    print("   ✓ dotenv OK")
except Exception as e:
    print(f"   ✗ dotenv FAILED: {e}")
    traceback.print_exc()
    sys.exit(1)

try:
    print("3. Testing supabase...")
    from supabase import create_client
    print("   ✓ supabase OK")
except Exception as e:
    print(f"   ✗ supabase FAILED: {e}")
    traceback.print_exc()
    sys.exit(1)

try:
    print("4. Testing security module...")
    from security import configure_session
    print("   ✓ security OK")
except Exception as e:
    print(f"   ✗ security FAILED: {e}")
    traceback.print_exc()
    sys.exit(1)

try:
    print("5. Testing routes...")
    from routes.auth_routes import auth_bp
    print("   ✓ routes OK")
except Exception as e:
    print(f"   ✗ routes FAILED: {e}")
    traceback.print_exc()
    sys.exit(1)

try:
    print("6. Testing models...")
    from models.product_model import ProductModel
    print("   ✓ models OK")
except Exception as e:
    print(f"   ✗ models FAILED: {e}")
    traceback.print_exc()
    sys.exit(1)

try:
    print("7. Creating app...")
    from app import create_app
    app = create_app()
    print("   ✓ App created OK")
except Exception as e:
    print(f"   ✗ App creation FAILED: {e}")
    traceback.print_exc()
    sys.exit(1)

print("=" * 50)
print("All imports successful! ✓")
print("=" * 50)
