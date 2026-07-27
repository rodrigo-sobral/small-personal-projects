#!/bin/bash
# <bitbar.title>RaspberryPi SSH Connector</bitbar.title>
# <bitbar.version>v1.0</bitbar.version>
# <bitbar.author>Rodrigo Sobral</bitbar.author>
# <bitbar.author.github>rodrigo-sobral</bitbar.author.github>
# <bitbar.desc>Turn on and off the connection to RaspberriPi over SSH.</bitbar.desc>
# <bitbar.dependencies>bash,ssh</bitbar.dependencies>

PLUGIN="raspi"
PWD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Scripts
CONNECT_SCRIPT="$PWD_DIR/scripts/$PLUGIN/connect.sh"
DISCONNECT_SCRIPT="$PWD_DIR/scripts/$PLUGIN/disconnect.sh"

if [ -z "$SSH_HOST" ]; then
    PLUGIN=$PLUGIN source "$PWD_DIR/scripts/source_env.sh"
fi

# Check if SSH tunnel is running
if pgrep -f "^ssh.*$SSH_HOST$" > /dev/null; then
    status="Connected"
    icon="🟢"
else
    status="Disconnected"
    icon="🔴"
fi

# --- Menu Bar Display ---
echo "$icon RASPI"
echo "---"
echo "Status: $status | color=gray"

if [ "$status" == "Disconnected" ]; then
    echo "Connect | bash='$CONNECT_SCRIPT' param1='$SSH_HOST' param2='$SSH_USER' param3='$SSH_KEY_PATH' terminal=true refresh=true"
else
    echo "Disconnect | bash='$DISCONNECT_SCRIPT' param1='$SSH_HOST' terminal=false refresh=true"
fi
