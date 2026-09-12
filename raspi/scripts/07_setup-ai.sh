#!/usr/bin/env bash
# Prepares the AI assistant (Ollama + Open WebUI).
#
# Two things have to happen before the chat is usable:
#   1. Open WebUI needs a stable session secret, or every restart invalidates
#      sessions (and any stored secrets it encrypted). We generate it into .env.
#   2. Ollama needs the model pulled. On a CPU-only Pi this is the slow part
#      (a ~1.5 GB download for qwen3:1.7b), so doing it here means the first
#      visit to the chat just works.
#
# Safe to re-run: an existing secret is kept and pulling an already-present
# model is a cheap no-op.
#
# Usage:  ./scripts/07_setup-ai.sh          (called by 01_setup.sh)

set -euo pipefail
cd "$(dirname "$0")/.."

ENV_FILE=".env"

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
        out.append(f'{key}="{val}"\n'); found = True
    else:
        out.append(line)
if not found:
    if out and not out[-1].endswith('\n'):
        out.append('\n')
    out.append(f'{key}="{val}"\n')
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

MODEL="$(read_env OLLAMA_MODEL)"
if [[ -z "$MODEL" ]]; then
  MODEL="qwen3:1.7b"
  set_env OLLAMA_MODEL "$MODEL"
  echo "==> Set OLLAMA_MODEL to $MODEL"
else
  echo "==> Using OLLAMA_MODEL=$MODEL"
fi

if [[ -z "$(read_env OPENWEBUI_SECRET_KEY)" ]]; then
  echo "==> Generating Open WebUI session secret"
  set_env OPENWEBUI_SECRET_KEY "$(openssl rand -hex 32)"
else
  echo "==> Reusing existing OPENWEBUI_SECRET_KEY from .env"
fi

if ! docker ps --format '{{.Names}}' | grep -qx 'ollama'; then
  echo "==> Ollama container isn't running; start the stack then re-run this"
  echo "    script to pull the model. (01_setup.sh does this for you.)"
  exit 0
fi

echo "==> Waiting for Ollama to answer..."
for _ in $(seq 1 60); do
  if docker exec ollama ollama list >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

if ! docker exec ollama ollama list >/dev/null 2>&1; then
  echo "Ollama never became ready. Check: docker logs ollama" >&2
  exit 1
fi

if docker exec ollama ollama list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "$MODEL"; then
  echo "==> Model $MODEL already present"
else
  echo "==> Pulling model $MODEL (this can take a while on a Pi)"
  docker exec ollama ollama pull "$MODEL"
fi

echo ""
DOMAIN_BASE_VALUE="$(read_env DOMAIN_BASE)"
DOMAIN_BASE_VALUE="${DOMAIN_BASE_VALUE:-home.arpa}"
echo "AI assistant is ready."
echo "  chat   https://ai.${DOMAIN_BASE_VALUE}  (login via Authentik)"
echo "  model  $MODEL"
echo "  note   the first account to sign in becomes Open WebUI's admin."
