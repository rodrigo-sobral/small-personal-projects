#!/bin/bash
# <bitbar.title>CERN SSH Proxy</bitbar.title>
# <bitbar.version>v1.0</bitbar.version>
# <bitbar.author>Rodrigo Sobral</bitbar.author>
# <bitbar.author.github>rodrigo-sobral</bitbar.author.github>
# <bitbar.desc>Connect and disconnect from CERN SOCKS proxy using Bitwarden-stored credentials.</bitbar.desc>
# <bitbar.dependencies>bash,ssh,bw</bitbar.dependencies>

PLUGIN="cern"
PWD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$PWD_DIR/scripts/$PLUGIN"

# Scripts
CONNECT_SCRIPT="$SCRIPTS_DIR/connect.sh"
DISCONNECT_SCRIPT="$SCRIPTS_DIR/disconnect.sh"
ENABLE_PROXY_SCRIPT="$SCRIPTS_DIR/enableproxy.sh"
DISABLE_PROXY_SCRIPT="$SCRIPTS_DIR/disableproxy.sh"
AUTOSSH_SCRIPT="$SCRIPTS_DIR/autossh.sh"

if [ -z "$SSH_HOST" ]; then
    PLUGIN=$PLUGIN source "$PWD_DIR/scripts/source_env.sh"
fi


# Get proxy state
PROXY_STATE=$(networksetup -getsocksfirewallproxy "Wi-Fi" | grep -q "Enabled: Yes" && echo "on" || echo "off")

# Get SSH socket tunnels (including the ones created from vscode processes)
SSH_SOCKET_PIDS="$(pgrep -f "(^ssh|ssh:).*$SSH_HOST(\.cern\.ch)?(:[0-9]+)?( \[mux\])?$" | tr '\n' ' ' | xargs)"

# Get SSH tunnels (only manual SSH connections over PROXY_PORT)
SSH_CONN_PIDS="$(pgrep -f "^(ssh|connect.sh|autossh.sh).*($PROXY_PORT)?.*$SSH_HOST$" | tr '\n' ' ' | xargs)"


# Check if SSH tunnel is running
[ -n "$SSH_SOCKET_PIDS" ] && status="👍🏻" || status="👎🏿"

# Check if the Proxy is on
[ "$PROXY_STATE" == "on" ] && proxy_status="👍🏻" || proxy_status="👎🏿"

# Check if both SSH and Proxy are ok
[[ $status == "👍🏻" && $proxy_status == "👍🏻" ]] && icon="🟢" || icon="🔴"


# --- Menu Bar Display ---
echo "$icon CERN"
echo "---"
# --- Labels Display ---
echo "SSH: $status Proxy: $proxy_status | color=gray"
echo "---"

# --- Options Display ---
if [[ "$status" == "👎🏿" || "$proxy_status" == "👎🏿" ]]; then
    echo "Connect All | bash='$CONNECT_SCRIPT' param1='$ENABLE_PROXY_SCRIPT' param2='$AUTOSSH_SCRIPT' param3='$PROXY_PORT' param4='$SSH_HOST' param5='$BW_CERN_ID' param6='$BW_CLIENTID' param7='$BW_CLIENTSECRET' param8='$SSH_CONN_PIDS' terminal=true refresh=true"
    if [ "$status" == "👍🏻" ]; then
        echo "Disconnect Socket | bash='$DISCONNECT_SCRIPT' param1='$DISABLE_PROXY_SCRIPT' param2='$PROXY_PORT' param3='$SSH_SOCKET_PIDS $SSH_CONN_PIDS' terminal=false refresh=true"
    fi
else
    echo "Disconnect All | bash='$DISCONNECT_SCRIPT' param1='$DISABLE_PROXY_SCRIPT' param2='$PROXY_PORT' param3='$SSH_CONN_PIDS' terminal=false refresh=true"
    echo "Disconnect Socket | bash='$DISCONNECT_SCRIPT' param1='$DISABLE_PROXY_SCRIPT' param2='$PROXY_PORT' param3='$SSH_SOCKET_PIDS $SSH_CONN_PIDS' terminal=false refresh=true"
fi
if [ "$proxy_status" == "👎🏿" ]; then
    echo "Connect Proxy | bash='$ENABLE_PROXY_SCRIPT' param1='$PROXY_PORT' terminal=false refresh=true"
else
    echo "Disconnect Proxy | bash='$DISABLE_PROXY_SCRIPT' terminal=false refresh=true"
fi
