#!/usr/bin/env bash
# Generates the OIDC client ID / secret pairs that authentik's blueprint reads
# from .env, so the provider side of every SSO integration is ready before the
# stack first starts.
#
# Why these live in .env rather than in the blueprint: each pair has to be
# entered on BOTH sides - authentik creates the provider with it, and the app
# (Immich, Nextcloud, ...) is configured with the same values. Keeping them in
# .env means the blueprint stays committable and you have one place to copy
# from when configuring each app.
#
# Safe to re-run: existing values are left alone, so it never invalidates an
# integration you've already set up. Use --rotate to deliberately reissue one.
#
# Usage:  ./scripts/04_setup-authentik.sh                  (called by 01_setup.sh)
#         ./scripts/04_setup-authentik.sh --rotate immich   (reissue one app's pair)

set -euo pipefail
cd "$(dirname "$0")/.."

ENV_FILE=".env"
APPS=(IMMICH NEXTCLOUD JELLYFIN BESZEL)

if [[ ! -f "$ENV_FILE" ]]; then
  echo "No .env found. Copy .env.example to .env first." >&2
  exit 1
fi

set_env() {
  local key="$1" val="$2"
  python3 - "$ENV_FILE" "$key" "$val" <<'PY'
import sys
path, key, val = sys.argv[1], sys.argv[2], sys.argv[3]
lines = open(path).read().splitlines(keepends=True)
found = False
out = []
for line in lines:
    if line.split('=', 1)[0] == key:
        out.append(f'{key}=\"{val}\"\n'); found = True
    else:
        out.append(line)
if not found:
    if out and not out[-1].endswith('\n'):
        out.append('\n')
    out.append(f'{key}=\"{val}\"\n')
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

# Alphanumeric only. Several of these apps put the client ID straight into a
# URL query string, and a couple handle '+' or '/' from base64 badly.
rand() { 
  python3 -c "
    import secrets, string
    print(''.join(secrets.choice(string.ascii_letters + string.digits) for _ in range($1)))
  ";
}

ROTATE_APP=""
if [[ "${1:-}" == "--rotate" ]]; then
  ROTATE_APP="$(echo "${2:-}" | tr 'a-z' 'A-Z')"
  [[ -n "$ROTATE_APP" ]] || { echo "--rotate needs an app name, e.g. --rotate immich" >&2; exit 1; }
fi

CHANGED=0
for app in "${APPS[@]}"; do
  id_key="${app}_OIDC_CLIENT_ID"
  secret_key="${app}_OIDC_CLIENT_SECRET"

  if [[ "$ROTATE_APP" == "$app" ]]; then
    set_env "$id_key" ""
    set_env "$secret_key" ""
    echo "==> Rotating $app"
  fi

  if [[ -z "$(read_env "$id_key")" ]]; then
    set_env "$id_key" "$(rand 40)"
    set_env "$secret_key" "$(rand 64)"
    echo "==> Generated OIDC credentials for $app"
    CHANGED=1
  fi
done

if [[ "$CHANGED" == "0" && -z "$ROTATE_APP" ]]; then
  echo "==> All OIDC credentials already present in .env, nothing to do"
fi

echo ""
echo "Authentik's side of every integration is declared in"
echo "  authentik/blueprints/homelab.yaml"
echo "and applied automatically on startup. The app side still needs the"
echo "matching values pasted in - see the README's SSO table for which apps"
echo "need what (some need a plugin installed first)."
