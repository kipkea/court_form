#!/usr/bin/env bash
set -e

echo "=========================================================="
echo "  Starting Court Smart Form & Print Studio Container      "
echo "=========================================================="

# 1. Wait for PostgreSQL Database to be ready
echo "Checking database connection at ${DB_HOST}:${DB_PORT}..."
python - << 'EOF'
import os
import sys
import time
import psycopg2

db_name = os.environ.get('DB_NAME', 'cdmc_system')
db_user = os.environ.get('DB_USER', 'cdmc')
db_pass = os.environ.get('DB_PASSWORD', 'Cdmc@12345')
db_host = os.environ.get('DB_HOST', 'localhost')
db_port = os.environ.get('DB_PORT', '5432')

for attempt in range(1, 31):
    try:
        conn = psycopg2.connect(
            dbname=db_name,
            user=db_user,
            password=db_pass,
            host=db_host,
            port=db_port,
            connect_timeout=3
        )
        conn.close()
        print(f"Database ready on attempt {attempt}!")
        sys.exit(0)
    except Exception as e:
        print(f"Database not ready yet (attempt {attempt}/30)... waiting 2s: {e}")
        time.sleep(2)

print("Error: Could not connect to database after 60s.")
sys.exit(1)
EOF

# 2. Run Database Migrations
echo "Applying database migrations..."
python manage.py migrate --noinput

# 3. Seed Initial Routine Templates and Paper Presets
echo "Seeding initial paper presets, routine templates and data sources..."
python seed_initial_data.py || true

echo "System initialization complete. Starting Web Server on Port ${PORT}..."
exec "$@"
