# sec-mcp Stack

Security-focused MCP stack routed through `mcpo`, with Open WebUI + Ollama included.

This stack is **ROCm-only** for Ollama.

## Included MCP servers

- `triv3/mcp-kali-server`
- `k3nn3dy-ai/kali-mcp`
- `GH05TCREW/MetasploitMCP`
- `socteam-ai/nvd-cve-mcp-server`
- `dtkmn/mcp-zap-server`
- `zcaceres/markdownify-mcp`

## Files

- `docker-compose.yml` - Main stack (Ollama runs with ROCm)
- `mcpo-config.template.json` - Templated `mcpo` multi-server config
- `.env.example` - Environment variable template
- `OPENWEBUI_MCP_SETUP.md` - Step-by-step MCP setup inside Open WebUI

## Quick start

Prerequisites for Ollama on ROCm hosts:

- Linux host with ROCm-compatible AMD GPU
- Device access available for `/dev/kfd` and `/dev/dri`

Running in Proxmox LXC?

- Follow the dedicated LXC section in `OPENWEBUI_MCP_SETUP.md` before launching (includes known caveats and quick fixes).

1. Create env file:

```powershell
Copy-Item .env.example .env
```

Generate strong API keys for ZAP + MCP-ZAP and set them in `.env`:

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

Then copy those values into `.env`:

```dotenv
ZAP_API_KEY=<paste-generated-zap-key>
MCP_ZAP_API_KEY=<paste-generated-mcp-zap-key>
```

2. Start base stack:

```powershell
docker compose up -d --build
```

Recommended for Podman/LXC first:

```bash
chmod +x ./preflight.sh
./preflight.sh
```

Podman users:

```bash
podman compose up -d --build
```

Or use the bootstrap helper:

```bash
chmod +x ./preflight.sh
./preflight.sh
chmod +x ./bootstrap.sh
./bootstrap.sh
```

The bootstrap script runs preflight checks for `/dev/net/tun`, `/dev/kfd`, and `/dev/dri` before starting Podman Compose.
It also removes stale `sec-mcp_*` containers to avoid Podman name-collision errors on reruns.

3. Open services:

- Open WebUI: `http://localhost:3000`
- MCPO docs: `http://localhost:8000/docs`
- Ollama API: `http://localhost:11434`

## MCPO routes

Each MCP server is exposed by `mcpo` under its own path:

- `http://localhost:8000/triv3-kali-server/docs`
- `http://localhost:8000/k3nn3dy-kali-mcp/docs`
- `http://localhost:8000/metasploit-mcp/docs`
- `http://localhost:8000/mcp-zap-server/docs`
- `http://localhost:8000/nvd-cve-mcp-server/docs`
- `http://localhost:8000/markdownify-mcp/docs`

## Open WebUI MCP setup

Follow the full guide in:

- `OPENWEBUI_MCP_SETUP.md`

This includes:

- UI steps for adding OpenAPI servers
- Correct internal Docker URL usage (`http://mcpo:8000/...`)
- Auth header guidance for `MCPO_API_KEY`
- Validation and troubleshooting steps
- A first-success test flow (section 6) to quickly verify MCP tool calls end-to-end

## Notes

- First startup is slower because dependencies are built/installed.
- `markdownify-mcp` is built at `mcpo` container startup.
- `mcp-zap-server` auth values are injected via `.env` into `mcpo-config.template.json` at runtime.
- `MD_SHARE_DIR` controls markdown file access scope for `markdownify-mcp`.
