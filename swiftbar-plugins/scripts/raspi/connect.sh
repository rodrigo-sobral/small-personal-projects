#!/bin/bash

# Disable locale warnings
unset LC_CTYPE

read -r SSH_HOST SSH_USER SSH_KEY_PATH <<< "$1 $2 $3"
if [ -z "$SSH_HOST" ] || [ -z "$SSH_USER" ] || [ -z "$SSH_KEY_PATH" ]; then
    echo "Usage: $0 <SSH_HOST> <SSH_USER> <SSH_KEY_PATH>"
    exit 1
fi

# Run SSH
ssh -i "$SSH_KEY_PATH" "$SSH_USER@$SSH_HOST"
