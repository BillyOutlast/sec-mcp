#!/usr/bin/env bash
set -euo pipefail

ok() { echo "[OK] $1"; }
warn() { echo "[WARN] $1"; }
fail() { echo "[FAIL] $1"; }

has_error=0

check_exists() {
  local path="$1"
  local message="$2"
  if [ -e "$path" ]; then
    ok "$message"
  else
    fail "$message"
    has_error=1
  fi
}

echo "[preflight] sec-mcp environment checks"
echo

if command -v podman >/dev/null 2>&1; then
  ok "podman is installed"
else
  fail "podman not found in PATH"
  echo "      Install Podman before continuing."
  has_error=1
fi

if podman compose version >/dev/null 2>&1; then
  ok "podman compose is available"
else
  fail "podman compose provider is unavailable"
  echo "      Install podman-compose or enable compose provider for Podman."
  has_error=1
fi

if podman info >/dev/null 2>&1; then
  ok "podman daemon/runtime is healthy"
else
  fail "podman info failed"
  echo "      Verify container runtime setup inside your Proxmox LXC."
  has_error=1
fi

check_exists "/dev/net/tun" "/dev/net/tun is present (required for Podman networking)"
check_exists "/dev/kfd" "/dev/kfd is present (ROCm device)"
check_exists "/dev/dri" "/dev/dri is present (DRM device)"

if [ -f "docker-compose.yml" ]; then
  ok "docker-compose.yml found"
else
  fail "docker-compose.yml not found in current directory"
  has_error=1
fi

if [ -f ".env" ]; then
  ok ".env found"
else
  warn ".env missing (copy from .env.example)"
fi

if [ "$has_error" -ne 0 ]; then
  echo
  echo "[preflight] One or more critical checks failed."
  echo "[preflight] For Proxmox LXC remediation, see OPENWEBUI_MCP_SETUP.md section '0) Proxmox LXC (ROCm) setup'."
  exit 1
fi

echo
ok "All critical checks passed"
echo "[preflight] You can now run: podman compose up -d --build"
