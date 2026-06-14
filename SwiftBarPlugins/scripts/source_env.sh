#!/bin/bash

ENV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PLUGIN_PATH="$ENV_DIR/$PLUGIN"
if [ -z "$PLUGIN" ]; then
    echo "Error: Plugin name not provided."
    exit 1
elif [ ! -f "$PLUGIN_PATH/.env" ]; then
    echo "Error: .env file not found in plugin directory ($PLUGIN_PATH/.env)."
    exit 1
fi

# Load environment variables
source "$PLUGIN_PATH/.env"

if [ $PLUGIN == "raspi" ]; then
    required_vars=("SSH_USER" "SSH_HOST" "SSH_KEY_PATH")
elif [ $PLUGIN == "cern" ]; then
    required_vars=("SSH_HOST" "PROXY_PORT" "BW_CERN_ID" "BW_CLIENTID" "BW_CLIENTSECRET")
fi

# Validate required variables
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Error: $var is not set in .env."
        exit 1
    fi
done
