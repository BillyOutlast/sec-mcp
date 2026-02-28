# Open WebUI MCP Setup Guide

This stack exposes MCP servers through `mcpo` as OpenAPI endpoints.

- `mcpo` URL from host: `http://localhost:8000`
- `mcpo` URL from inside Docker network (Open WebUI): `http://mcpo:8000`

## 1) Start the stack

```powershell
docker compose up -d --build
```

For AMD GPU Ollama (Linux ROCm hosts):

```powershell
docker compose -f docker-compose.yml -f docker-compose.ollama-amd.yml up -d --build
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

## Troubleshooting

- OpenAPI URL fails in Open WebUI container:
  - Use `http://mcpo:8000/...` (not `localhost`) when Open WebUI runs in Docker.
- Empty tools after import:
  - Check `mcpo` logs: `docker compose logs -f mcpo`
- ZAP tools fail auth:
  - Verify `.env` values for `MCP_ZAP_API_KEY` and `ZAP_API_KEY`.
- Markdown file retrieval blocked:
  - Verify `MD_SHARE_DIR` in `.env` and ensure files are in that directory.
