#!/usr/bin/env bash
# Pre-configures Beszel so there is nothing to click after first boot.
#
# Without this you'd have to: start the stack, open the hub, add a system by
# hand, copy the token and the hub's SSH public key out of the UI, paste both
# into .env, then restart the agent. This script does all of it up front.
#
# It works because of two things in Beszel's own design:
#
#   1. The hub reads its SSH private key from <data-dir>/id_ed25519 if that
#      file already exists, and only generates one when it's missing. So we
#      generate the pair ourselves and bind-mount the private key in - which
#      means we know the matching public key before the hub has ever run, and
#      can hand it to the agent as KEY.
#
#   2. The hub syncs its systems from <data-dir>/config.yml on every start,
#      including the registration token. So we can declare the system and its
#      token in advance, and the agent authenticates on its first connection.
#
# Safe to re-run: it reuses an existing key and token rather than rotating
# them, so it won't break an agent that's already registered.
#
# Usage:  ./scripts/03_setup-beszel.sh          (called by scripts/01_setup.sh)
#         ./scripts/03_setup-beszel.sh --rotate (force a new key + token)

set -euo pipefail
cd "$(dirname "$0")/.."

BESZEL_DIR="beszel"
KEY_FILE="$BESZEL_DIR/id_ed25519"
CONFIG_FILE="$BESZEL_DIR/config.yml"
ENV_FILE=".env"
ROTATE="${1:-}"
# Tracks whether the hub's SSH key changed this run. The running hub keeps its
# private key in memory, so a changed key only takes effect after the hub is
# recreated - see the warning printed at the end.
KEY_CHANGED=false
# BESZEL_SYSTEM_USER / BESZEL_SYSTEM_NAME are resolved from .env further down
# (once read_env is defined), not from the shell environment. Reading them from
# the environment only worked when this script was invoked by 01_setup.sh, which
# sources .env first - running it directly, which is the normal way to re-run
# it, silently saw them as empty and skipped the user assignment.

if [[ ! -f "$ENV_FILE" ]]; then
  echo "No .env found. Copy .env.example to .env first." >&2
  exit 1
fi

for cmd in ssh-keygen; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "'$cmd' not found. Install openssh-client (or openssh) and re-run." >&2
    exit 1
  }
done

mkdir -p "$BESZEL_DIR"

# --- upsert a KEY=VALUE into .env, preserving everything else ---------------
set_env() {
  local key="$1" val="$2"
  python3 - "$ENV_FILE" "$key" "$val" <<'PY'
import sys
path, key, val = sys.argv[1], sys.argv[2], sys.argv[3]
lines = open(path).read().splitlines(keepends=True)
out = []
escaped = val.replace('\\', '\\\\').replace('"', '\\"').replace('$', '\\$').replace('`', '\\`')
found = False
for line in lines:
    if line.split('=', 1)[0] == key:
        out.append(f'{key}="{escaped}"\n'); found = True
    else:
        out.append(line)
if not found:
    if out and not out[-1].endswith('\n'):
        out.append('\n')
    out.append(f'{key}="{escaped}"\n')
open(path, 'w').writelines(out)
PY
}

read_env() {
  python3 - "$ENV_FILE" "$1" <<'PY'
import shlex
import sys

path, key = sys.argv[1], sys.argv[2]
value = ''
for line in open(path):
    if line.rstrip('\n').split('=', 1)[0] == key:
        parts = shlex.split(line.split('=', 1)[1], comments=False)
        value = ' '.join(parts)
print(value)
PY
}

# Resolve these now that read_env exists. An explicit shell environment value
# still wins, so 01_setup.sh (which sources .env) behaves identically.
BESZEL_SYSTEM_USER="${BESZEL_SYSTEM_USER:-$(read_env BESZEL_SYSTEM_USER)}"
BESZEL_SYSTEM_NAME="${BESZEL_SYSTEM_NAME:-$(read_env BESZEL_SYSTEM_NAME)}"

# --- 1. hub SSH key ---------------------------------------------------------
if [[ "$ROTATE" == "--rotate" ]]; then
  echo "==> Rotating: removing existing Beszel key and token"
  rm -f "$KEY_FILE" "$KEY_FILE.pub"
  set_env BESZEL_TOKEN ""
  KEY_CHANGED=true
fi

if [[ -f "$KEY_FILE" ]]; then
  echo "==> Reusing existing Beszel hub key ($KEY_FILE)"
else
  echo "==> Generating the Beszel hub's ed25519 key pair"
  # -N '' = no passphrase; the hub reads this unattended.
  ssh-keygen -t ed25519 -N '' -C 'beszel-hub' -f "$KEY_FILE" >/dev/null
  KEY_CHANGED=true
fi
chmod 600 "$KEY_FILE"

# The agent verifies the hub's signature against this. Strip the trailing
# comment: the agent parses it as an authorized_keys line, and a stray
# comment is harmless but makes the .env line needlessly long.
PUBKEY="$(cut -d' ' -f1,2 < "$KEY_FILE.pub")"

# --- 2. registration token --------------------------------------------------
TOKEN="$(read_env BESZEL_TOKEN)"
if [[ -z "$TOKEN" ]]; then
  echo "==> Generating a registration token"
  if command -v uuidgen >/dev/null 2>&1; then
    TOKEN="$(uuidgen | tr 'A-Z' 'a-z')"
  else
    TOKEN="$(python3 -c 'import uuid; print(uuid.uuid4())')"
  fi
else
  echo "==> Reusing existing BESZEL_TOKEN from .env"
fi

# --- 3. declare the system --------------------------------------------------
# One system, because there's one host. Every *container* on it is discovered
# automatically by the agent through the docker socket - there is nothing
# per-service to declare here, and adding a service to the stack needs no
# change to this file.
#
# host must match the agent's LISTEN value in docker-compose.yml: the hub
# dials the agent over that unix socket rather than a TCP port.
echo "==> Writing $CONFIG_FILE"

# The system entry is written unconditionally. An earlier version of this
# script emitted `systems: []` and then *appended* list items underneath it,
# which can never parse: `[]` is already a complete (empty) flow sequence, so
# the appended block items were either a YAML error or silently ignored. The
# hub logged "No systems defined in config.yml", never created a fingerprint
# record for the token, and the agent got HTTP 401 on every single connection
# attempt - which looks exactly like a credentials problem but wasn't one.
#
# `users:` is the only genuinely conditional part, and it is omitted rather
# than left empty when unknown: with no `users` key, Beszel assigns the system
# to the first user account, which is the admin you create on first login.
{
  cat <<EOF
# Generated by scripts/03_setup-beszel.sh - do not edit by hand.
#
# WARNING: once this file exists, Beszel treats it as the SOLE source of truth
# for systems on every restart. Any system you add later through the web UI
# will be DELETED on the next restart unless it's also listed here. If you add
# a second machine, add it below and re-run this script.
#
# Note this cuts both ways: saving the YAML config from Beszel's own settings
# page overwrites this file with whatever the database currently holds. If the
# database has no systems, you get \`systems: []\` back and monitoring stops.
#
# There is one system because there is one host. Every *container* on it is
# discovered automatically by the agent through the docker socket, so there is
# nothing per-service to declare here and adding a service to the stack needs
# no change to this file.
#
# host must match the agent's LISTEN value in docker-compose.yml: the hub
# dials the agent over that unix socket rather than a TCP port.
systems:
  - name: ${BESZEL_SYSTEM_NAME:-raspi}
    host: /beszel_socket/beszel.sock
    port: 45876
    token: ${TOKEN}
EOF
  if [[ -n "$BESZEL_SYSTEM_USER" ]]; then
    cat <<EOF
    users:
      - ${BESZEL_SYSTEM_USER}
EOF
  fi
} > "$CONFIG_FILE"

# Fail loudly here rather than letting the hub quietly ignore a malformed file
# - that silence is what made the original bug hard to spot.
if command -v python3 >/dev/null 2>&1; then
  python3 - "$CONFIG_FILE" <<'PY'
import sys, yaml
path = sys.argv[1]
try:
    doc = yaml.safe_load(open(path))
except Exception as exc:
    sys.exit(f"generated {path} is not valid YAML: {exc}")
systems = (doc or {}).get("systems")
if not systems:
    sys.exit(f"generated {path} declares no systems - the agent would get 401")
missing = [k for k in ("name", "host", "port", "token") if not systems[0].get(k)]
if missing:
    sys.exit(f"generated {path} system is missing: {', '.join(missing)}")
print(f"==> Verified {path}: {len(systems)} system(s), token present")
PY
fi

# --- 4. write the agent's half back into .env -------------------------------
set_env BESZEL_TOKEN "$TOKEN"
set_env BESZEL_KEY "$PUBKEY"

echo ""
echo "Beszel is pre-configured:"
echo "  hub key    $KEY_FILE  (mounted read-only into the hub)"
echo "  system     $CONFIG_FILE"
echo "  agent      BESZEL_TOKEN + BESZEL_KEY written to .env"
echo ""
if [[ "$KEY_CHANGED" == true ]]; then
  echo "!! The hub's SSH key changed this run."
  echo "   A running hub still holds the old private key, so recreate it (and the"
  echo "   agent, which now has the new public key) or the agent will log"
  echo "   \"invalid signature - check KEY value\":"
  echo "     docker compose up -d --force-recreate beszel beszel-agent"
  echo "   (scripts/01_setup.sh does this automatically for you.)"
  echo ""
fi
echo "Nothing to do in the UI except create your own account on first visit."
