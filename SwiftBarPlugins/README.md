# SwiftBar Custom Plugins

A collection of [SwiftBar](https://swiftbar.app/) plugins for managing SSH connections and network configurations. These plugins provide a convenient menu bar interface to control SSH tunnels and proxy settings from macOS.

## Projects

### 1. CERN SSH Proxy
A plugin for managing SSH connections to CERN infrastructure with automatic SOCKS proxy configuration.

**What it does:**
- Displays the status of SSH tunnel and SOCKS proxy connections to a CERN host
- Provides menu options to connect/disconnect SSH tunnel and enable/disable proxy
- Retrieves SSH credentials from Bitwarden for secure authentication
- Automatically manages macOS Wi-Fi SOCKS proxy settings
- Uses `autossh` to maintain stable SSH connections with automatic reconnection

**Status Indicators:**
- Main icon: 🟢 (both SSH and Proxy enabled) or 🔴 (at least one is disabled)
- SSH status: 👍🏻 (connected via socket tunnel) or 👎🏿 (disconnected)
- Proxy status: 👍🏻 (proxy enabled) or 👎🏿 (proxy disabled)

**Dependencies:**
- bash
- ssh
- [bw (Bitwarden CLI)](https://bitwarden.com/download/)

---

### 2. RaspberryPi SSH Connector
A simple plugin for managing SSH connections to a Raspberry Pi or other remote host.

**What it does:**
- Displays connection status to a remote SSH host (Raspberry Pi)
- Provides menu options to quickly connect/disconnect via SSH
- Uses SSH key-based authentication for secure access
- Shows connection status: 🟢 (connected) or 🔴 (disconnected)

**Dependencies:**
- bash
- ssh

---

## Configuration

### Environment Setup

Both plugins require environment variables to be configured. Create `.env` files in the appropriate script directories by copying the `.env.example` template.

#### `.env.example` Template

```bash
# scripts/cern/.env

PROXY_PORT=          # Port number for SOCKS proxy (e.g., 9999)
SSH_USER=            # SSH username for CERN host
SSH_HOST=            # CERN hostname (e.g., lxplus.cern.ch)
BW_EMAIL=            # Bitwarden account email for credential retrieval

# scripts/raspi/.env

SSH_KEY_PATH=        # Full path to SSH private key (e.g., ~/.ssh/id_rsa)
SSH_USER=            # SSH username for Raspberry Pi
SSH_HOST=            # Raspberry Pi hostname or IP address
```

### Setup Instructions

1. **Create environment files:**
   ```bash
   # For CERN plugin
   cp .env.example scripts/cern/.env

   # For RaspberryPi plugin
   cp .env.example scripts/raspi/.env
   ```

2. **Edit the `.env` files with your configuration:**
   - For **CERN**: Set your CERN credentials, desired proxy port, and Bitwarden email
   - For **RaspberryPi**: Set your SSH key path, username, and host address

3. **Ensure SSH keys have correct permissions:**
   ```bash
   chmod 600 ~/.ssh/id_rsa  # Or your SSH key path
   ```

4. **Install Bitwarden CLI (CERN plugin only):**
   ```bash
   brew install bitwarden-cli
   ```

5. **Add plugins to SwiftBar:**
   - Open SwiftBar
   - Click the SwiftBar icon → "Open Plugins Folder"
   - Copy `cern.1s.sh` and/or `raspi.1s.sh` to the plugins folder
   - Refresh SwiftBar (SwiftBar menu → "Refresh")

---

## Expected Results

### CERN SSH Proxy Plugin

**On First Launch:**
- Menu bar shows 🔴 CERN (disconnected)
- Dropdown menu displays:
  - `SSH: 👎🏿 Proxy: 👎🏿` (status indicators)
  - `Connect All` button (connects SSH tunnel and enables proxy)

**After Connecting:**
- Menu bar shows 🟢 CERN (fully connected)
- SOCKS proxy is automatically enabled on macOS Wi-Fi
- SSH tunnel established with automatic reconnection via autossh
- Dropdown menu now displays:
  - `SSH: 👍🏻 Proxy: 👍🏻` (both connected)
  - `Disconnect All` button
  - `Disconnect Socket` button

**Bitwarden Integration:**
- On first connection, you'll be prompted to enter your Bitwarden master password
- SSH password is securely retrieved from Bitwarden (stored entry: `login.cern.ch`)
- Session token is cached in `~/.bw_session` for subsequent operations

### RaspberryPi SSH Connector Plugin

**On First Launch:**
- Menu bar shows 🔴 RASPI (disconnected)
- Dropdown menu displays:
  - `Status: Disconnected`
  - `Connect` button (opens terminal with SSH session)

**After Connecting:**
- Menu bar shows 🟢 RASPI (connected)
- Terminal window opens with active SSH session
- Dropdown menu now displays:
  - `Status: Connected`
  - `Disconnect` button (kills the SSH process)

**Auto-refresh:**
- Plugin updates every 1 second (`1s` in filename)
- Status automatically reflects current connection state

---

## Usage

### CERN Plugin
- **Connect**: Click "Connect All" to establish both SSH tunnel and proxy
- **Disconnect**: Click "Disconnect All" or "Disconnect Socket" as needed
- **Toggle Proxy**: Use "Connect Proxy" / "Disconnect Proxy" to manage proxy independently

### RaspberryPi Plugin
- **Connect**: Click "Connect" to open SSH terminal session
- **Disconnect**: Click "Disconnect" to close the connection

---

## Troubleshooting

### "Error: .env file not found"
- Ensure `.env` file exists in the correct script directory
- Check file permissions: `ls -la scripts/raspi/.env`

### SSH Connection Fails
- Verify SSH key path is correct and accessible
- Check host is reachable: `ping <SSH_HOST>`
- Ensure SSH key has correct permissions: `chmod 600 ~/.ssh/your_key`

### Bitwarden Authentication (CERN)
- Ensure Bitwarden CLI is installed: `which bw`
- Verify your Bitwarden account email in `.env`
- Ensure login entry exists in Bitwarden with name `login.cern.ch`

---

## File Structure

```
SwiftBarPlugins/
├── README.md                          # This file
├── .env.example                       # Environment template
├── .swiftbarignore                    # SwiftBar ignore rules
├── cern.1s.sh                         # CERN plugin (refreshes every 1 second)
├── raspi.1s.sh                        # RaspberryPi plugin (refreshes every 1 second)
└── scripts/
    ├── source_env.sh                  # Shared environment loader
    ├── cern/
    │   ├── .env                       # CERN configuration
    │   ├── connect.sh                 # SSH tunnel + proxy setup
    │   ├── disconnect.sh              # SSH tunnel + proxy teardown
    │   ├── enableproxy.sh             # macOS proxy enable
    │   ├── disableproxy.sh            # macOS proxy disable
    │   └── autossh.sh                 # Secure SSH wrapper
    └── raspi/
        ├── .env                       # RaspberryPi configuration
        ├── connect.sh                 # SSH connection script
        └── disconnect.sh              # SSH disconnection script
```
