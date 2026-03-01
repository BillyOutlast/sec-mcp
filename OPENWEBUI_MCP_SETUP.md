# Open WebUI MCP Setup Guide

This stack exposes MCP servers through `mcpo` as OpenAPI endpoints.

- `mcpo` URL from host: `http://localhost:8000`
- `mcpo` URL from inside Docker network (Open WebUI): `http://mcpo:8000`

## Preflight checklist (run before first launch)

Run these in the target runtime environment (inside your LXC if using Proxmox):

Preferred automated check:

```bash
chmod +x ./preflight.sh
./preflight.sh
```

Equivalent manual checks:

```bash
ls -l /dev/kfd
ls -l /dev/dri
docker info
docker compose config
docker compose up -d --build
```

Before running compose, ensure local build context exists:

```bash
test -d ./kali-mcp || git clone https://github.com/k3nn3dy-ai/kali-mcp.git kali-mcp
```

Expected outcomes:

- `/dev/kfd` and `/dev/dri` exist
- Docker daemon is healthy (`docker info` succeeds)
- Compose config parses cleanly (`docker compose config` succeeds)
- Stack starts without immediate container exits

### Quick failure mapping

| Failing check | Typical cause | Fast fix |
|---|---|---|
| `ls -l /dev/kfd` | GPU device not exposed to runtime | Verify host GPU/ROCm setup and LXC passthrough mounts |
| `ls -l /dev/dri` | DRM device not exposed | Re-check `/etc/pve/lxc/<CTID>.conf` bind for `/dev/dri` |
| `docker info` | Docker daemon not running / no permission | Start Docker service and verify LXC nesting/keyctl config |
| `docker compose config` | YAML/env interpolation error | Validate `.env` values and recent edits to `docker-compose.yml` |
| `docker compose up -d --build` | Service build/start failure | Check logs with `docker compose logs -f <service>` and fix first failing service |

## 0) Proxmox LXC (ROCm) setup

Use this section only when running the stack inside a Proxmox LXC container.

### A. Verify GPU devices on Proxmox host

On the Proxmox node:

```bash
ls -l /dev/kfd
ls -l /dev/dri
```

If these do not exist on the host, fix AMD/ROCm host setup first.

### B. Configure LXC for Docker + GPU passthrough

Edit `/etc/pve/lxc/<CTID>.conf` on the Proxmox host and add:

```ini
features: nesting=1,keyctl=1
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.cgroup2.devices.allow: c 226:* rwm
lxc.cgroup2.devices.allow: c 235:* rwm
lxc.mount.entry: /dev/net dev/net none bind,optional,create=dir
lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir
lxc.mount.entry: /dev/kfd dev/kfd none bind,optional,create=file
```

Important:

- Do **not** set `lxc.apparmor.profile: unconfined` unless you explicitly need it.
- If you already set it and see startup errors like `Failed to run autodev hooks` / `status 17`, remove that line first.

Then restart the container:

```bash
pct restart <CTID>
```

If startup still fails, stop the CT and test with this minimal reset:

```bash
pct stop <CTID>
# edit /etc/pve/lxc/<CTID>.conf and remove: lxc.apparmor.profile: unconfined
pct start <CTID>
```

### C. Validate inside the LXC container

Inside the container:

```bash
ls -l /dev/kfd
ls -l /dev/dri
docker info
```

If `docker info` fails, complete Docker installation/config in the LXC first.

### D. Continue with this guide

After device and Docker validation succeed, continue with step 1 below.

### E. Known caveats (LXC + Docker + ROCm)

- **Unprivileged LXC may block device access**  
  Symptom: `/dev/kfd` exists but Ollama fails to initialize ROCm.  
  Quick fix: test with a privileged container profile or ensure device cgroup + mount entries are applied exactly.

- **`docker info` fails inside LXC**  
  Symptom: Docker daemon unreachable or permission denied.  
  Quick fix: ensure Docker is installed/running inside the CT and `nesting=1,keyctl=1` is set in LXC config.

- **`/dev/dri` or `/dev/kfd` missing after restart**  
  Symptom: devices present on host but not in CT.  
  Quick fix: re-check `/etc/pve/lxc/<CTID>.conf`, then `pct restart <CTID>`.

- **Open WebUI can’t reach mcpo by service name**  
  Symptom: OpenAPI import errors when using `http://mcpo:8000/...`.  
  Quick fix: ensure Open WebUI and mcpo are in the same compose project/network; otherwise use host URL.

- **ROCm performance or init instability**  
  Symptom: model load failures or very slow startup.  
  Quick fix: verify host ROCm compatibility first, then test Ollama alone before bringing full stack up.

## 1) Start the stack

This deployment assumes a ROCm-capable Linux host for Ollama (`/dev/kfd` and `/dev/dri`).

Before starting, generate strong values for `ZAP_API_KEY` and `MCP_ZAP_API_KEY` in `.env`.

PowerShell:

```powershell
$zapKey = -join ((48..57 + 65..90 + 97..122) | Get-Random -Count 48 | ForEach-Object {[char]$_})
$mcpZapKey = -join ((48..57 + 65..90 + 97..122) | Get-Random -Count 48 | ForEach-Object {[char]$_})
Write-Host "ZAP_API_KEY=$zapKey"
Write-Host "MCP_ZAP_API_KEY=$mcpZapKey"
```

Linux/macOS shell:

```bash
echo "ZAP_API_KEY=$(openssl rand -hex 24)"
echo "MCP_ZAP_API_KEY=$(openssl rand -hex 24)"
```

Set those values in your `.env` file and keep them identical to what your running stack uses.

```powershell
docker compose up -d --build
```

## 2) Open Open WebUI

- Open: `http://localhost:3000`
- Create/sign in to your admin account.

## 3) Add MCP tools via OpenAPI servers

In Open WebUI, navigate to the OpenAPI server management screen (label can vary by version, typically under Admin/Settings/Tools/Integrations).

Add one OpenAPI server per MCP route from `mcpo`.

Suggested entries:

- Name: `triv3-kali-server`
  - OpenAPI URL: `http://mcpo:8000/triv3-kali-server/openapi.json`
- Name: `k3nn3dy-kali-mcp`
  - OpenAPI URL: `http://mcpo:8000/k3nn3dy-kali-mcp/openapi.json`
- Name: `metasploit-mcp`
  - OpenAPI URL: `http://mcpo:8000/metasploit-mcp/openapi.json`
- Name: `mcp-zap-server`
  - OpenAPI URL: `http://mcpo:8000/mcp-zap-server/openapi.json`
- Name: `nvd-cve-mcp-server`
  - OpenAPI URL: `http://mcpo:8000/nvd-cve-mcp-server/openapi.json`
- Name: `markdownify-mcp`
  - OpenAPI URL: `http://mcpo:8000/markdownify-mcp/openapi.json`

If your Open WebUI is outside Docker, use `http://localhost:8000/.../openapi.json` instead.

## 4) Authentication (if enabled)

`mcpo` is configured with API key auth (`MCPO_API_KEY`).

If Open WebUI asks for headers for an OpenAPI server, add:

- Header: `Authorization`
- Value: `Bearer <MCPO_API_KEY>`

or

- Header: `X-API-Key`
- Value: `<MCPO_API_KEY>`

Use whichever your Open WebUI version expects for OpenAPI auth headers.

## 5) Validate each server

From host browser:

- `http://localhost:8000/docs`
- `http://localhost:8000/triv3-kali-server/docs`
- `http://localhost:8000/k3nn3dy-kali-mcp/docs`
- `http://localhost:8000/metasploit-mcp/docs`
- `http://localhost:8000/mcp-zap-server/docs`
- `http://localhost:8000/nvd-cve-mcp-server/docs`
- `http://localhost:8000/markdownify-mcp/docs`

If these are reachable, Open WebUI can import them.

## 6) First successful test flow (3 prompts)

Run these in Open WebUI after your OpenAPI servers are connected.

1. **CVE lookup path (`nvd-cve-mcp-server`)**

Prompt:

```text
Use the nvd-cve-mcp-server tools to search CVEs for "OpenSSL" and return the top 3 with CVE ID, severity, and published date.
```

2. **Web conversion path (`markdownify-mcp`)**

Prompt:

```text
Use markdownify-mcp to convert https://example.com to markdown and summarize it in 5 bullet points.
```

3. **Security scan tool path (`mcp-zap-server`)**

Prompt:

```text
Use mcp-zap-server tools to list available scan-related tools and explain which one to run first for a baseline web assessment.
```

Expected result:

- Tool calls execute without auth/network errors.
- You get structured output from at least 2 different MCP backends.
- Open WebUI can repeatedly call the same server without reconnecting/importing again.

## Troubleshooting

- OpenAPI URL fails in Open WebUI container:
  - Use `http://mcpo:8000/...` (not `localhost`) when Open WebUI runs in Docker.
- Empty tools after import:
  - Check `mcpo` logs: `docker compose logs -f mcpo`
- ZAP tools fail auth:
  - Verify `.env` values for `MCP_ZAP_API_KEY` and `ZAP_API_KEY`.
- Markdown file retrieval blocked:
  - Verify `MD_SHARE_DIR` in `.env` and ensure files are in that directory.

### Runtime failure mapping

| Symptom | Likely cause | Fast fix |
|---|---|---|
| Open WebUI fails to import OpenAPI URL | Wrong base URL for deployment context | Use `http://mcpo:8000/...` when Open WebUI is in Docker, `http://localhost:8000/...` when outside |
| OpenAPI import succeeds but tools fail at call time | Missing/incorrect mcpo auth header | Add `Authorization: Bearer <MCPO_API_KEY>` (or `X-API-Key`) in OpenAPI server settings |
| `mcp-zap-server` tools return auth errors | `MCP_ZAP_API_KEY`/`ZAP_API_KEY` mismatch | Recheck `.env`, restart stack, confirm rendered config in mcpo logs |
| No tools visible for one server route | Upstream MCP server failed to start | `docker compose logs -f <service>` and fix startup error first |
| Open WebUI works but no local models in chat | Ollama reachable but model not pulled | Run `docker compose exec ollama ollama pull llama3.2` |
| Ollama requests fail or time out | ROCm/device/runtime issue | Verify `/dev/kfd` and `/dev/dri`, then test Ollama container health and logs |
| Markdownify `get-markdown-file` rejects paths | File outside allowed share directory | Place file under `MD_SHARE_DIR` path and retry |
