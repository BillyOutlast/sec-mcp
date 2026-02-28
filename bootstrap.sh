#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if [ ! -d "./kali-mcp/.git" ]; then
  echo "[bootstrap] Cloning kali-mcp..."
  git clone https://github.com/k3nn3dy-ai/kali-mcp.git kali-mcp
else
  echo "[bootstrap] kali-mcp already present."
fi

echo "[bootstrap] Starting stack with Podman Compose..."
podman compose up -d --build

echo "[bootstrap] Done."
echo "  Open WebUI: http://localhost:3000"
echo "  MCPO docs:  http://localhost:8000/docs"
echo "  Ollama API: http://localhost:11434"
