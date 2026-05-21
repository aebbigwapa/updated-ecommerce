#!/usr/bin/env python
import requests

try:
    resp = requests.get('http://127.0.0.1:5000/terms-content')
    print(f"Status: {resp.status_code}")
    print(f"Headers: {dict(resp.headers)}")
    print(f"Content (first 500 chars): {resp.text[:500]}")
except Exception as e:
    print(f"Error: {e}")
