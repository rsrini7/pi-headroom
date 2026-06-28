# pi-headroom

Headroom proxy extension for [pi-coding-agent](https://github.com/earendil-works/pi-coding-agent). Routes requests through a local [Headroom](https://github.com/headroom-ai/headroom) compression proxy for **30-60% token savings**.

## Features

- **Proxy routing** — Redirects `opencode-go` provider traffic through local Headroom proxy
- **CCR retrieval** — Registers `headroom_retrieve` tool for cache-compress-retrieve support
- **Auto-detection** — Checks if proxy is running, falls back to direct connection
- **Configurable** — Port, host, and feature flags via config file

## Installation

### Prerequisites

1. Install [pi-coding-agent](https://github.com/earendil-works/pi-coding-agent)
2. Install [uv](https://docs.astral.sh/uv/getting-started/installation/) (for running headroom)

### Install pi-headroom

```bash
# Option 1: Install via pi (recommended)
pi install npm:@rsrini/pi-headroom

# Option 2: Add to ~/.pi/agent/settings.json
{
  "packages": ["npm:@rsrini/pi-headroom"]
}
```

## Quick Start

### Option A: Use the `hpi` wrapper script (recommended)

The easiest way to use both plugins together:

```bash
# Download the hpi script
curl -O https://raw.githubusercontent.com/rsrini7/pi-headroom/main/hpi.sh
chmod +x hpi.sh

# Add to your shell
echo 'source /path/to/hpi.sh' >> ~/.zshrc
source ~/.zshrc

# Start pi with both extensions
hpi
```

### Option B: Manual setup

```bash
# 1. Start Headroom proxy
uvx --python 3.12 --from 'headroom-ai[proxy,ml,code]==0.27.0' \
  headroom proxy --port 8787 --memory --code-aware

# 2. In another terminal, start pi with the extension
pi -e npm:@rsrini/pi-headroom
```

### Option C: Configure in settings.json

```bash
# Install both plugins
pi install npm:@rsrini/pi-rtk
pi install npm:@rsrini/pi-headroom

# They're now active for all pi sessions
pi
```

## Token Reduction Stack

```
Tool output  →  pi-rtk (60-90%)  →  Pi context  →  Headroom (30-60%)  →  LLM
                  ↑ client-side                        ↑ proxy-side
```

| Layer | What | Where | Savings |
|-------|------|-------|---------|
| **pi-rtk** | Filters tool output (bash, read, grep) | Pi client | 60-90% |
| **pi-headroom** | Routes through compression proxy | Pi client | 30-60% |
| **Headroom** | Compresses full context window | Proxy :8787 | 30-60% |

**Combined savings: 70-95%** depending on content type.

## Configuration

Create `~/.pi/agent/headroom-config.json`:

```json
{
  "enabled": true,
  "proxy": {
    "host": "localhost",
    "port": 8787
  },
  "features": {
    "compression": true,
    "caching": true,
    "retrieval": true
  }
}
```

## Commands

| Command | Description |
|---------|-------------|
| `/headroom-stats` | Show compression statistics |
| `/headroom-on` | Enable proxy routing |
| `/headroom-off` | Disable proxy routing |
| `/headroom-status` | Check proxy connection status |

## Agent Tool

The `headroom_retrieve` tool allows the AI agent to retrieve cached context when needed.

## The `hpi` Wrapper Script

The `hpi` script provides a seamless experience:

```bash
# Start with both plugins (local dev mode)
hpi

# Use npm published packages
hpi --npm

# Use specific model
hpi --npm --model openrouter/claude-sonnet-4

# One-shot mode
hpi --npm -p "fix the bug"

# Stop the proxy
hpi --stop
```

### Flags

| Flag | Description |
|------|-------------|
| `--npm` | Use npm published packages |
| `--local` | Use local workspace paths (default) |
| `--no-rtk` | Skip rtk extension (headroom only) |
| `--stop` | Kill the headroom proxy |
| `--model` | Override model |
| `--thinking` | Override thinking level |

## Combining with pi-rtk

For maximum savings, install both:

```bash
pi install npm:@rsrini/pi-rtk
pi install npm:@rsrini/pi-headroom
```

Or use the `hpi` wrapper which handles both automatically.

## Troubleshooting

### Proxy not starting

```bash
# Check if port is in use
lsof -i :8787

# Kill existing processes
hpi --stop

# Check logs
cat ~/.pi/agent/headroom.log
```

### Extension not loading

```bash
# Verify installation
pi list

# Check settings
cat ~/.pi/agent/settings.json

# Test with verbose output
pi -e npm:@rsrini/pi-headroom --verbose
```

## License

MIT
