#!/usr/bin/env bash
#
# Build frontend assets locally and upload them to a low-memory server.
# Run this on a machine with enough RAM (your local machine or CI).
# The server only builds the PHP image, which expects public/build to already exist.
#
# Usage:
#   ./docker/build-prod-light.sh
#   REMOTE_HOST=observer REMOTE_PATH=/home/ubuntu/laraowl/public ./docker/build-prod-light.sh
#   SKIP_UPLOAD=1 ./docker/build-prod-light.sh
#

set -euo pipefail

REMOTE_HOST="${REMOTE_HOST:-observer}"
REMOTE_PATH="${REMOTE_PATH:-/home/ubuntu/laraowl/public}"
REMOTE_PATH="${REMOTE_PATH%/}"

cd "$(dirname "$0")/.."

if [ -f pnpm-lock.yaml ] && command -v pnpm >/dev/null 2>&1; then
    PACKAGE_MANAGER="pnpm"
    INSTALL_CMD=(pnpm install --frozen-lockfile)
else
    PACKAGE_MANAGER="npm"
    INSTALL_CMD=(npm install --no-audit --no-fund)
fi

echo "Installing Node dependencies with ${PACKAGE_MANAGER}..."
"${INSTALL_CMD[@]}"

echo "Building production assets..."
rm -rf public/build
NODE_OPTIONS=--max-old-space-size=4096 "${PACKAGE_MANAGER}" run build

if [ ! -d public/build ]; then
    echo "Build failed: public/build was not generated." >&2
    exit 1
fi

if [ "${SKIP_UPLOAD:-0}" = "1" ]; then
    echo ""
    echo "Build complete. Upload skipped (SKIP_UPLOAD=1)."
    echo "Assets are in public/build/"
    exit 0
fi

echo ""
echo "Uploading public/build to ${REMOTE_HOST}:${REMOTE_PATH}/build/ ..."
ssh "${REMOTE_HOST}" "mkdir -p '${REMOTE_PATH}/build'"
rsync -avz --delete public/build/ "${REMOTE_HOST}:${REMOTE_PATH}/build/"

echo ""
echo "Upload complete."
echo "On the server, build and start the light stack:"
echo "  docker compose -f docker-compose.prod-light.yaml up -d --build"
