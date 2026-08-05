#!/bin/bash
#
# Build frontend assets locally and package them for low-memory servers.
# Run this on a machine with enough RAM (your local machine or CI),
# then upload public/build to the server before running docker compose build.
#

set -e

echo "Installing Node dependencies..."
npm install --no-audit --no-fund

echo "Building production assets..."
NODE_OPTIONS=--max-old-space-size=4096 npm run build

echo ""
echo "Build complete. The assets are in public/build/"
echo "Upload them to the server before building the Docker image:"
echo "  rsync -avz public/build ubuntu@your-server:~/laraowl/public/"

echo ""
echo "On the server, build using the light Dockerfile:"
echo "  docker compose -f docker-compose.prod-light.yaml up -d --build"
