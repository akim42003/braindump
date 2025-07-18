#!/bin/bash

# Build and push all-in-one container

set -euo pipefail

DOCKER_USERNAME=${DOCKER_USERNAME:-"akim42003"}
VERSION=${VERSION:-"0.3.0"}
IMAGE_NAME="${DOCKER_USERNAME}/braindump-all-in-one"

echo "Building all-in-one Braindump container..."

# Build the image
docker build -f Dockerfile.all-in-one -t "${IMAGE_NAME}:${VERSION}" -t "${IMAGE_NAME}:latest" .

echo "Build complete!"
echo ""
echo "To push to Docker Hub:"
echo "  docker push ${IMAGE_NAME}:${VERSION}"
echo "  docker push ${IMAGE_NAME}:latest"
echo ""
echo "To run locally:"
echo "  docker run -d -p 80:80 -p 8001:8001 --name braindump ${IMAGE_NAME}:${VERSION}"
echo ""
echo "To deploy on Jetson:"
echo "  docker pull ${IMAGE_NAME}:${VERSION}"
echo "  docker run -d -p 80:80 -p 8001:8001 --name braindump ${IMAGE_NAME}:${VERSION}"
