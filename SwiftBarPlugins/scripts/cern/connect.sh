#!/bin/bash
set -e

read -r ENABLE_PROXY_SCRIPT AUTOSSH_SCRIPT PROXY_PORT SSH_HOST BW_CERN_ID_VAL BW_CLIENTID_VAL BW_CLIENTSECRET_VAL SSH_CONN_PIDS <<< "$1 $2 $3 $4 $5 $6 $7 $8"

export BW_CERN_ID="$BW_CERN_ID_VAL"
export BW_CLIENTID="$BW_CLIENTID_VAL"
export BW_CLIENTSECRET="$BW_CLIENTSECRET_VAL"

# 1. Handle Bitwarden Authentication via API Key
if ! bw login --check >/dev/null 2>&1; then
    bw login --apikey >/dev/null
fi

# 2. Handle Vault Unlock & Session Management
_unlock_vault() {
    export BW_SESSION="$(bw unlock --raw)"
    echo "$BW_SESSION" > "$HOME/.bw_session"
    chmod 600 "$HOME/.bw_session"
    echo "Vault unlocked and session saved"
}

# Load existing session from file if BW_SESSION isn't already set
if [ -z "$BW_SESSION" ] && [ -f "$HOME/.bw_session" ]; then
    export BW_SESSION="$(cat "$HOME/.bw_session")"
fi

# Validate session with a lightweight, non-interactive call
# `bw list folders` is fast and never prompts — it just fails with exit code 1 if session is invalid
if ! bw list folders --session "$BW_SESSION" >/dev/null 2>&1; then
    _unlock_vault
fi

# Now sync with the confirmed-valid session
bw sync --session "$BW_SESSION" >/dev/null

# 3. Retrieve Credentials
ssh_pass=$(bw get password "$BW_CERN_ID" --session "$BW_SESSION" | base64)
ssh_totp=$(bw get totp "$BW_CERN_ID" --session "$BW_SESSION" | base64)

# 4. Network and Proxy Setup
$ENABLE_PROXY_SCRIPT $PROXY_PORT

# 5. SSH into the machine
if [ -z "$SSH_CONN_PIDS" ]; then
    $AUTOSSH_SCRIPT "$ssh_pass" "$ssh_totp" ssh -D "$PROXY_PORT" "$SSH_HOST"
fi
