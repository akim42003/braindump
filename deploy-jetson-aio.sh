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
    echo ""
    echo "Access your blog at:"
    echo "  http://$(hostname -I | awk '{print $1}'):1000"
    echo "  http://localhost:1000"
    echo ""
    echo "API endpoint: http://localhost:8001"
else
    echo "Failed to start Braindump"
    docker logs braindump
fi
