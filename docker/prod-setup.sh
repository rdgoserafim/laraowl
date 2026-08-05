#!/bin/bash
#
# Production setup helper for LaraOwl.
# Run this once on the production server after copying .env.prod to .env.
#

set -e

ENV_FILE="${1:-.env}"

if [ ! -f "$ENV_FILE" ]; then
    echo "Environment file not found: $ENV_FILE"
    echo "Usage: $0 [path-to-.env]"
    exit 1
fi

ensure_value() {
    local key="$1"
    local value="$2"

    if grep -q "^${key}=" "$ENV_FILE"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
    else
        echo "${key}=${value}" >> "$ENV_FILE"
    fi
}

echo "Generating secure application keys..."

# Generate Laravel APP_KEY if missing or placeholder
CURRENT_APP_KEY=$(grep "^APP_KEY=" "$ENV_FILE" | cut -d '=' -f2-)
if [ -z "$CURRENT_APP_KEY" ] || [ "$CURRENT_APP_KEY" = "base64:" ]; then
    APP_KEY=$(php -r 'echo "base64:" . base64_encode(random_bytes(32));')
    ensure_value "APP_KEY" "$APP_KEY"
    echo "  APP_KEY generated"
else
    echo "  APP_KEY already set, skipping"
fi

# Generate Reverb credentials if placeholders
CURRENT_REVERB_KEY=$(grep "^REVERB_APP_KEY=" "$ENV_FILE" | cut -d '=' -f2-)
if [ -z "$CURRENT_REVERB_KEY" ] || [ "$CURRENT_REVERB_KEY" = "change-me-to-a-random-string" ]; then
    ensure_value "REVERB_APP_ID" "$(shuf -i 100000-999999 -n 1)"
    ensure_value "REVERB_APP_KEY" "$(openssl rand -hex 24)"
    ensure_value "REVERB_APP_SECRET" "$(openssl rand -hex 32)"
    echo "  REVERB_APP_ID, REVERB_APP_KEY and REVERB_APP_SECRET generated"
else
    echo "  Reverb credentials already set, skipping"
fi

echo ""
echo "Production environment configured in $ENV_FILE"
echo "Review the following variables before starting the application:"
echo "  - APP_URL"
echo "  - APP_HOSTNAME"
echo "  - DB_PASSWORD"
echo "  - REDIS_PASSWORD"
echo "  - MAIL_*"
echo ""
echo "Start the application with:"
echo "  docker compose up -d --build"
