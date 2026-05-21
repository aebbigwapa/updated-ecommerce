#!/usr/bin/env python
from app import create_app

app = create_app()

# Test if the routes exist
found_routes = []
for rule in app.url_map.iter_rules():
    if 'test' in rule.rule or 'terms' in rule.rule or 'privacy' in rule.rule:
        found_routes.append((rule.rule, rule.endpoint))

print("Routes found:")
for route, endpoint in found_routes:
    print(f"  {route} -> {endpoint}")

if not found_routes:
    print("  No test/terms/privacy routes found!")

# Also check auth routes
auth_routes = []
for rule in app.url_map.iter_rules():
    if 'auth' in rule.endpoint:
        auth_routes.append((rule.rule, rule.endpoint))

print("\nAuth routes:")
for route, endpoint in auth_routes[:5]:
    print(f"  {route} -> {endpoint}")
print(f"  ... and {len(auth_routes) - 5} more")
