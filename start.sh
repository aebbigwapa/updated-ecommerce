#!/bin/sh
# Startup script for Render deployment

echo "Starting E-Commerce Backend..."
echo "PORT: $PORT"

# Start gunicorn with factory pattern
exec gunicorn --bind "0.0.0.0:${PORT:-5000}" \
    --workers 1 \
    --timeout 120 \
    --access-logfile - \
    --error-logfile - \
    "app:create_app()"
