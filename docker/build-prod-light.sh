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

if [ ! -f .env.production ]; then
    echo ".env.production not found in $(pwd)." >&2
    echo "The frontend bundle needs it to embed the VITE_* variables (Reverb websocket auth)." >&2
    exit 1
fi

echo "Installing Node dependencies with ${PACKAGE_MANAGER}..."
"${INSTALL_CMD[@]}"

# Vite resolves env files in this order for `--mode production`:
#   .env -> .env.local -> .env.production -> .env.production.local
# Local overrides would silently win over .env.production and ship the wrong
# websocket host/key to production, so refuse to build when they exist.
for stale_env in .env.local .env.production.local; do
    if [ -f "${stale_env}" ]; then
        echo "${stale_env} exists and would override .env.production during the build." >&2
        echo "Remove or rename it before building production assets." >&2
        exit 1
    fi
done

echo "Resolving VITE_* variables from .env.production..."
node --input-type=module -e "
import { loadEnv } from 'vite';

const required = [
    'VITE_APP_NAME',
    'VITE_REVERB_APP_KEY',
    'VITE_REVERB_HOST',
    'VITE_REVERB_PORT',
    'VITE_REVERB_SCHEME',
];

const env = loadEnv('production', process.cwd(), 'VITE_');
const missing = required.filter((key) => !env[key]);

for (const key of required) {
    console.log(\`  \${key}=\${env[key] ?? '<missing>'}\`);
}

if (missing.length > 0) {
    console.error(\`Missing or empty in .env.production: \${missing.join(', ')}\`);
    process.exit(1);
}
"

# The Vite build runs `php artisan wayfinder:generate`, which fails when
# bootstrap/cache holds caches generated inside the Docker container
# (absolute container paths and root/nobody ownership).
# echo "Clearing Laravel caches..."
# if ! php artisan optimize:clear >/dev/null 2>&1; then
#     echo "Could not clear Laravel caches." >&2
#     echo "bootstrap/cache and storage are probably owned by the Docker container user. Fix with:" >&2
#     echo "  sudo chown -R \"\$USER\":\"\$USER\" bootstrap/cache storage resources/js/actions resources/js/routes public" >&2
#     exit 1
# fi

echo "Building production assets..."
rm -rf public/build
NODE_OPTIONS=--max-old-space-size=4096 "${PACKAGE_MANAGER}" run build -- --mode production

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
