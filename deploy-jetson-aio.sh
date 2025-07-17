#!/bin/bash

# Deploy all-in-one container on Jetson Nano

set -euo pipefail

IMAGE="akim42003/braindump-all-in-one:0.3.0"

echo "Deploying Braindump on Jetson Nano..."

# Stop and remove existing container
docker stop braindump 2>/dev/null || true
docker rm braindump 2>/dev/null || true

# Pull latest image
echo "Pulling image..."
docker pull "$IMAGE"

# Run container
echo "Starting container..."
docker run -d \
  -p 1000:80 \
  -p 8001:3000 \
  --name braindump \
  --restart unless-stopped \
  -v braindump_data:/var/lib/postgresql/data \
  "$IMAGE"

echo "Waiting for services to start..."
sleep 20

# Check if running
if docker ps | grep -q braindump; then
    echo "Braindump is running!"

    # Check for Supabase migration
    echo ""
    echo "Checking for Supabase data migration..."

    # Check if .env file exists with Supabase credentials
    if [ -f ".env" ]; then
        source .env
        if [ -n "${SUPABASE_URL}" ] && [ -n "${SUPABASE_ANON_KEY}" ]; then
            echo "Supabase credentials found, running migration..."

            # Wait a bit more for backend to be fully ready
            sleep 10

            # Run migration inside the container
            if docker exec braindump sh -c "cd /app/backend && SUPABASE_URL='${SUPABASE_URL}' SUPABASE_ANON_KEY='${SUPABASE_ANON_KEY}' node migrate.js"; then
                echo "Supabase migration completed successfully!"
            else
                echo "Migration failed, but blog is still running"
                echo "You can run migration manually later"
            fi
        else
            echo "No Supabase credentials found in .env file"
            echo "To migrate data, create .env file with:"
            echo "SUPABASE_URL=your_supabase_url"
            echo "SUPABASE_ANON_KEY=your_supabase_anon_key"
        fi
    else
        echo "No .env file found for Supabase migration"
        echo "To migrate data, create .env file with:"
        echo "SUPABASE_URL=your_supabase_url"
        echo "SUPABASE_ANON_KEY=your_supabase_anon_key"
    fi

    echo ""
    echo "Access your blog at:"
    echo "  http://$(hostname -I | awk '{print $1}'):1000"
    echo "  http://localhost:1000"
    echo ""
    echo "API endpoint: http://localhost:8001"
else
    echo " Failed to start Braindump"
    docker logs braindump
fi
