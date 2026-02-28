# sec-mcp Stack

Security-focused MCP stack routed through `mcpo`, with Open WebUI + Ollama included.

## Included MCP servers

- `triv3/mcp-kali-server`
- `k3nn3dy-ai/kali-mcp`
- `GH05TCREW/MetasploitMCP`
- `socteam-ai/nvd-cve-mcp-server`
- `dtkmn/mcp-zap-server`
- `zcaceres/markdownify-mcp`

## Files

- `docker-compose.yml` - AMD ROCm override for Ollama
- `mcpo-config.template.json` - Templated `mcpo` multi-server config
- `.env.example` - Environment variable template
- `OPENWEBUI_MCP_SETUP.md` - Step-by-step MCP setup inside Open WebUI

## Quick start

1. Create env file:

```powershell
Copy-Item .env.example .env
```

2. Start base stack:

```powershell
docker compose up -d --build
```

3. Open services:

- Open WebUI: `http://localhost:3000`
- MCPO docs: `http://localhost:8000/docs`
- Ollama API: `http://localhost:11434`

## AMD GPU (Ollama ROCm)

Use this only on Linux hosts with `/dev/kfd` and `/dev/dri` available:

```powershell
docker compose -f docker-compose.yml -f docker-compose.ollama-amd.yml up -d --build
```

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

## Notes

- First startup is slower because dependencies are built/installed.
- `markdownify-mcp` is built at `mcpo` container startup.
- `mcp-zap-server` auth values are injected via `.env` into `mcpo-config.template.json` at runtime.
- `MD_SHARE_DIR` controls markdown file access scope for `markdownify-mcp`.
