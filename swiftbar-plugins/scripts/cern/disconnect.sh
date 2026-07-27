#!/bin/bash

read -r DISABLE_PROXY_SCRIPT PROXY_PORT SSH_PIDS <<< "$1 $2 $3"

$DISABLE_PROXY_SCRIPT $PROXY_PORT

# Kill all SSH processes connected to the specified host
kill "$SSH_PIDS"
