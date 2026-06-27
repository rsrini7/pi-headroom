# pi-headroom

Headroom proxy extension for [pi-coding-agent](https://github.com/earendil-works/pi-coding-agent). Routes requests through a local [Headroom](https://github.com/headroom-ai/headroom) compression proxy for **30-60% token savings**.

## Features

- **Proxy routing** — Redirects `opencode-go` provider traffic through local Headroom proxy
- **CCR retrieval** — Registers `headroom_retrieve` tool for cache-compress-retrieve support
- **Auto-detection** — Checks if proxy is running, falls back to direct connection
- **Configurable** — Port, host, and feature flags via config file

## Installation

```bash
# From npm (when published)
pi install pi-headroom

# From local path
pi install ~/ws/pi-headroom

# Or just use directly
pi -e ~/ws/pi-headroom
```

## Quick Start

```bash
# 1. Start Headroom proxy
hpi

# 2. Use pi with headroom extension
pi -e ~/ws/pi-headroom

# Or combine with pi-rtk for maximum savings
pi -e ~/ws/pi-headroom -e pi-rtk
```

## Token Reduction Stack

```
Tool output  →  pi-rtk (60-90%)  →  pi context  →  Headroom (30-60%)  →  LLM
                  ↑ client-side                        ↑ proxy-side
```

| Layer | What | Where | Savings |
|-------|------|-------|---------|
| **pi-rtk** | Filters tool output (bash, read, grep) | Pi client | 60-90% |
| **pi-headroom** | Routes through compression proxy | Pi client | 30-60% |
| **Headroom** | Compresses full context window | Proxy :8787 | 30-60% |

## Configuration

Create `~/.pi/agent/headroom-config.json`:

```json
{
  "port": 8787,
  "host": "localhost",
  "registerRetrieveTool": true
}
```

Or project-local `.pi/headroom-config.json`.

## How It Works

1. **Session start**: Extension checks if Headroom proxy is running
2. **Provider override**: If running, overrides `opencode-go` baseUrl to `http://localhost:8787/v1`
3. **Tool registration**: Registers `headroom_retrieve` tool for CCR support
4. **CCR flow**: When LLM calls `headroom_retrieve`, tool proxies call to Headroom's `/v1/retrieve/tool_call` endpoint

## CCR (Cache-Compress-Retrieve)

Headroom's CCR makes compression reversible:

1. **Compress**: Headroom compresses tool outputs in context
2. **Cache**: Original content stored with hash
3. **Retrieve**: LLM can call `headroom_retrieve(hash, query)` to get original

This extension registers the tool so pi can handle these calls.

## Shell Function (hpi)

For convenience, use the `hpi` shell function:

```bash
# Source it
source ~/ws/Learnings/Scripts/hpi.sh

# Use it
hpi                          # interactive
hpi -p "fix the bug"         # one-shot
hpi --model claude-sonnet-4  # custom model
hpi --stop                   # kill proxy
```

## Troubleshooting

```bash
# Check proxy health
curl -s http://localhost:8787/health | jq .

# View proxy stats
curl -s http://localhost:8787/stats | jq .summary

# View proxy logs
cat ~/.pi/agent/headroom.log

# Force restart proxy
hpi --stop && hpi
```

## Files

| File | Purpose |
|------|---------|
| `index.ts` | Extension entry point |
| `package.json` | Package metadata |
| `tsconfig.json` | TypeScript config |

## Related

- [pi-rtk](https://github.com/mcowger/pi-rtk) — Client-side tool output filtering
- [Headroom](https://github.com/headroom-ai/headroom) — Context compression proxy

## License

MIT
