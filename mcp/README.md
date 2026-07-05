# devmanager-mcp

MCP bridge for **DevManager** — lets AI tools (Claude Code, Codex, Cursor…) control your local dev processes.

DevManager runs a local control API on `127.0.0.1:39125`; this package exposes it as MCP tools over stdio.

## Use

Keep DevManager running, then register the bridge with your AI tool:

```bash
claude mcp add -s user devmanager -- npx --prefer-offline @labtool/devmanager-mcp@latest
codex  mcp add devmanager -- npx --prefer-offline @labtool/devmanager-mcp@latest
```

## Tools

`list_projects` · `start_project` · `stop_project` · `restart_project` · `create_project` · `delete_project` · `get_logs` · `list_ports` · `health` · `list_profiles` · `start_profile`

Override the API base with `DEVMANAGER_URL` if needed (default `http://127.0.0.1:39125`).
