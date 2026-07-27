#!/bin/bash

SSH_HOST="$1"
if [ -z "$SSH_HOST" ]; then
    echo "Usage: $0 <SSH_HOST>"
    exit 1
fi

# Kill all SSH processes connected to the specified host
pkill -f "^ssh.*$SSH_HOST$"
