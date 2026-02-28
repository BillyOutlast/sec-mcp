#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if [ ! -e "/dev/net/tun" ]; then
  echo "[bootstrap] ERROR: /dev/net/tun is missing."
  echo "[bootstrap] In Proxmox LXC, enable container networking features before Podman builds."
  exit 1
fi

if [ ! -e "/dev/kfd" ] || [ ! -e "/dev/dri" ]; then
  echo "[bootstrap] ERROR: ROCm devices are missing (/dev/kfd or /dev/dri)."
  echo "[bootstrap] Apply Proxmox LXC passthrough settings from OPENWEBUI_MCP_SETUP.md and restart CT."
  exit 1
fi

echo "[bootstrap] Cleaning previous sec-mcp containers (if any)..."
podman compose down --remove-orphans >/dev/null 2>&1 || true

stale_containers=$(podman ps -a --format '{{.Names}}' | grep '^sec-mcp_' || true)
if [ -n "$stale_containers" ]; then
  echo "$stale_containers" | xargs -r podman rm -f >/dev/null
fi

echo "[bootstrap] Starting stack with Podman Compose..."
podman compose up --build

echo "[bootstrap] Done."
echo "  Open WebUI: http://localhost:3030"
echo "  MCPO docs:  http://localhost:8000/docs"
echo "  Ollama API: http://localhost:11434"
