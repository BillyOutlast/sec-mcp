#!/usr/bin/env bash
set -euo pipefail

ok() { echo "[OK]   $1"; }
info() { echo "[INFO] $1"; }
warn() { echo "[WARN] $1"; }
fail() { echo "[FAIL] $1"; }

has_fail=0

section() {
  echo
  echo "== $1 =="
}

require_cmd() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "'$cmd' is installed"
  else
    fail "'$cmd' is not installed"
    has_fail=1
  fi
}

resolve_group_name() {
  local gid="$1"
  if command -v getent >/dev/null 2>&1; then
    getent group "$gid" | cut -d: -f1 || true
  fi
}

show_device_owner() {
  local device="$1"
  if [ -e "$device" ]; then
    local gid owner mode gname
    gid="$(stat -c '%g' "$device")"
    owner="$(stat -c '%U:%G' "$device")"
    mode="$(stat -c '%a' "$device")"
    gname="$(resolve_group_name "$gid")"
    ok "$device present (owner=$owner mode=$mode gid=$gid${gname:+ group=$gname})"
  else
    fail "$device missing"
    has_fail=1
  fi
}

find_ollama_container() {
  local cid
  cid="$(podman ps --filter name=sec-mcp_ollama_1 --format '{{.ID}}' | head -n1 || true)"
  if [ -n "$cid" ]; then
    echo "$cid"
    return 0
  fi

  cid="$(podman ps --filter ancestor=ollama/ollama:rocm --format '{{.ID}}' | head -n1 || true)"
  if [ -n "$cid" ]; then
    echo "$cid"
    return 0
  fi

  return 1
}

echo "[gpu-diagnose] sec-mcp ROCm/Ollama diagnostic"

section "Host checks"
require_cmd podman

if command -v lspci >/dev/null 2>&1; then
  info "PCI display adapters:"
  lspci | grep -Ei 'vga|3d|display|amd|ati' || true
else
  warn "lspci not available; skipping PCI adapter probe"
fi

show_device_owner "/dev/kfd"
show_device_owner "/dev/dri"

if [ -d /dev/dri ]; then
  info "DRM nodes:"
  ls -l /dev/dri || true
fi

section "Host kernel log analysis"
if command -v dmesg >/dev/null 2>&1; then
  dmesg_tail="$(dmesg 2>/dev/null | grep -Ei 'amdgpu|kfd|drm|gfx|mes' | tail -n 200 || true)"

  if [ -z "$dmesg_tail" ]; then
    warn "No recent amdgpu/kfd/drm lines found in dmesg"
  else
    info "Recent amdgpu/kfd/drm lines detected"
  fi

  if echo "$dmesg_tail" | grep -Eqi 'MES failed to respond|GPU reset begin|device lost from bus|ASIC reset failed|Failed to quiesce KFD|evicting device resources failed|failed to suspend gangs'; then
    fail "Host dmesg shows critical AMDGPU/KFD instability (GPU reset or queue failures)"
    echo "      This is a host-side driver/runtime issue and will force Ollama CPU fallback."
    has_fail=1
  fi
else
  warn "dmesg command unavailable; skipping kernel log analysis"
fi

section "Container checks"

if ! podman info >/dev/null 2>&1; then
  fail "podman runtime is not healthy (podman info failed)"
  has_fail=1
fi

if ollama_cid="$(find_ollama_container)"; then
  ollama_name="$(podman inspect --format '{{.Name}}' "$ollama_cid" | sed 's#^/##')"
  ok "found running ollama container: $ollama_name ($ollama_cid)"
else
  fail "no running ollama container found (expected sec-mcp_ollama_1 or ollama/ollama:rocm)"
  echo "      Start it with: podman compose up -d ollama"
  has_fail=1
fi

if [ "${ollama_cid:-}" != "" ]; then
  info "Container device visibility:"
  podman exec "$ollama_cid" sh -lc 'ls -l /dev/kfd /dev/dri 2>/dev/null; [ -d /dev/dri ] && ls -l /dev/dri || true' || true

  info "Container runtime identity:"
  podman exec "$ollama_cid" sh -lc 'id' || true

  info "Container ROCm-related env vars:"
  podman exec "$ollama_cid" sh -lc 'env | grep -E "OLLAMA_LLM_LIBRARY|HSA_|HIP_|ROCR_" || true' || true

  info "ROCm backend library presence in container:"
  podman exec "$ollama_cid" sh -lc 'ls /usr/lib/ollama/libggml-rocm* 2>/dev/null || echo "(no libggml-rocm files found)"' || true

  section "Ollama log analysis"
  logs="$(podman logs --tail 300 "$ollama_cid" 2>&1 || true)"

  if echo "$logs" | grep -Eqi 'inference compute.*(id=gpu|library=rocm|library=hip)'; then
    ok "Ollama reports GPU inference backend"
  else
    warn "No explicit GPU inference backend reported in recent logs"
  fi

  if echo "$logs" | grep -Eqi 'offloaded [1-9][0-9]*/[0-9]+ layers to GPU'; then
    ok "Model layers are being offloaded to GPU"
  elif echo "$logs" | grep -Eqi 'offloaded 0/[0-9]+ layers to GPU'; then
    fail "Ollama reports zero GPU layer offload (CPU fallback)"
    has_fail=1
  fi

  if echo "$logs" | grep -Eqi 'total_vram="0 B"|inference compute.*id=cpu|library=cpu'; then
    fail "Logs indicate CPU-only inference (VRAM unavailable to Ollama)"
    has_fail=1
  fi

  if echo "$logs" | grep -Eqi 'amdgpu|kfd|rocm|hip'; then
    info "Recent ROCm/AMD-related log lines found"
  else
    warn "No ROCm/AMD-related lines found in recent Ollama logs"
  fi
fi

section "Result"
if [ "$has_fail" -ne 0 ]; then
  echo "[gpu-diagnose] One or more critical checks failed."
  echo "[gpu-diagnose] Likely causes now: host ROCm/GPU compatibility, LXC passthrough policy, or driver stack mismatch."
  echo "[gpu-diagnose] Next host checks:"
  echo "  - dmesg | grep -Ei 'amdgpu|kfd|drm|gfx' | tail -n 120"
  echo "  - lspci | grep -Ei 'vga|3d|display|amd'"
  exit 1
fi

ok "GPU diagnostics passed"
echo "[gpu-diagnose] Ollama appears ready for GPU inference."
