#!/usr/bin/env zsh
# ──────────────────────────────────────────────────────────────────────────────
# hpi — Pi coding agent through Headroom compression proxy + RTK filtering
#
# Reduces LLM token costs by 60-90% with two layers:
#   1. pi-rtk: wraps bash commands with external rtk binary (60-90% savings)
#   2. pi-headroom: routes through Headroom proxy (30-60% savings)
#
# Install:
#   curl -O https://raw.githubusercontent.com/rsrini7/pi-headroom/main/hpi.sh
#   chmod +x hpi.sh
#   echo 'source /path/to/hpi.sh' >> ~/.zshrc
#
# Prerequisites:
#   - pi-coding-agent: https://github.com/earendil-works/pi-coding-agent
#   - uv: https://docs.astral.sh/uv/getting-started/installation/
#   - rtk (optional): brew install rtk-ai/tap/rtk
#
# Usage:
#   hpi                          # interactive, use settings.json packages
#   hpi --npm                    # force npm packages
#   hpi -p "fix the bug"         # one-shot print mode
#   hpi --model openrouter/claude-sonnet-4
#   hpi --thinking xhigh         # override thinking level
#   hpi --stop                   # kill the headroom proxy
#   hpi --no-rtk                 # skip rtk extension (headroom only)
# ──────────────────────────────────────────────────────────────────────────────

hpi() {
  local port=8787
  local target="https://opencode.ai/zen/go/v1"
  local pidfile="$HOME/.pi/agent/headroom.pid"
  local logfile="$HOME/.pi/agent/headroom.log"
  local use_rtk=1
  local use_npm=0
  local headroom_ext="npm:@rsrini/pi-headroom"
  local rtk_ext="npm:@rsrini/pi-rtk"

  # ── Parse flags ───────────────────────────────────────────────────────────
  local -a passthrough_args=()
  for arg in "$@"; do
    case "$arg" in
      --stop)     ;; # handled below
      --no-rtk)   use_rtk=0 ;;
      --npm)      use_npm=1 ;;
      *)          passthrough_args+=("$arg") ;;
    esac
  done

  # ── Stop command ──────────────────────────────────────────────────────────
  if [[ "${1:-}" == "--stop" ]]; then
    if [[ -f "$pidfile" ]]; then
      local pid
      pid=$(<"$pidfile")
      if kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null
        echo "🛑 Stopped Headroom proxy (PID $pid)" >&2
      fi
      rm -f "$pidfile"
    fi
    # Fallback: kill by port
    local pids
    pids=$(lsof -ti :"$port" 2>/dev/null)
    if [[ -n "$pids" ]]; then
      echo "$pids" | xargs kill 2>/dev/null
      echo "🛑 Killed processes on :$port" >&2
    fi
    return 0
  fi

  # ── Check prerequisites ──────────────────────────────────────────────────
  if ! command -v uvx &>/dev/null; then
    echo "❌ uv not found. Install: https://docs.astral.sh/uv/getting-started/installation/" >&2
    return 1
  fi

  if ! command -v pi &>/dev/null; then
    echo "❌ pi not found. Install: https://github.com/earendil-works/pi-coding-agent" >&2
    return 1
  fi

  # ── Install plugins if not present ───────────────────────────────────────
  if ! pi list 2>/dev/null | grep -q "@rsrini/pi-headroom"; then
    echo "📦 Installing @rsrini/pi-headroom..." >&2
    pi install npm:@rsrini/pi-headroom
  fi

  if (( use_rtk )) && ! pi list 2>/dev/null | grep -q "@rsrini/pi-rtk"; then
    echo "📦 Installing @rsrini/pi-rtk..." >&2
    pi install npm:@rsrini/pi-rtk
  fi

  # ── Start Headroom proxy if not running ───────────────────────────────────
  if ! lsof -i :"$port" -sTCP:listen &>/dev/null; then
    echo "▶  Starting Headroom proxy on :$port → $target" >&2

    # Detect Apple Silicon for MPS embedder
    local extras="proxy,ml,code"
    if [[ "$(uname)" == "Darwin" && "$(uname -m)" == "arm64" ]]; then
      extras="$extras,pytorch-mps"
      export HEADROOM_EMBEDDER_RUNTIME=pytorch_mps
    fi

    # Launch headroom via uvx in background
    export HEADROOM_OUTPUT_SHAPER=1
    export HEADROOM_VERBOSITY_LEVEL=2
    export HEADROOM_VERBOSITY_AUTOTUNE=1
    export HEADROOM_OUTPUT_HOLDOUT=0.1
    PYTHONUNBUFFERED=1 OPENAI_TARGET_API_URL="$target" nohup uvx \
      --python 3.12 \
      --from 'headroom-ai['"$extras"']==0.27.0' \
      headroom proxy \
        --port "$port" \
        --memory --code-aware \
      > "$logfile" 2>&1 &
    local pid=$!
    echo "$pid" > "$pidfile"

    # Wait for readiness (cold start can be slow with model download)
    local retries=0
    while ! lsof -i :"$port" -sTCP:listen &>/dev/null; do
      sleep 1
      ((retries++))
      if ((retries > 60)); then
        echo "❌ Headroom proxy failed to start. Check: $logfile" >&2
        rm -f "$pidfile"
        return 1
      fi
    done

    # Verify health
    if curl -sf "http://localhost:$port/health" >/dev/null 2>&1; then
      echo "✅ Headroom proxy ready on :$port (PID $pid)" >&2
    else
      echo "⚠️  Proxy listening but health check failed (may still be warming up)" >&2
    fi
  fi

  # ── Build pi args — inject defaults if not specified ──────────────────────
  local -a pi_args=()
  local has_provider=0 has_model=0 has_thinking=0

  for arg in "${passthrough_args[@]}"; do
    case "$arg" in
      --provider) has_provider=1 ;;
      --model)    has_model=1 ;;
      --thinking) has_thinking=1 ;;
    esac
  done

  # Defaults: opencode-go / mimo-v2.5-pro / high
  (( ! has_provider )) && pi_args+=(--provider opencode-go)
  (( ! has_model ))    && pi_args+=(--model mimo-v2.5-pro)
  (( ! has_thinking )) && pi_args+=(--thinking high)

  # ── Build extension args ──────────────────────────────────────────────────
  local -a ext_args=()
  ext_args+=(--extension "$headroom_ext")
  (( use_rtk )) && ext_args+=(--extension "$rtk_ext")

  # ── Summary ───────────────────────────────────────────────────────────────
  local ext_list="headroom"
  (( use_rtk )) && ext_list+="+rtk"
  echo "🧩 Extensions: $ext_list" >&2

  # ── Launch pi ─────────────────────────────────────────────────────────────
  command pi -ne "${ext_args[@]}" "${pi_args[@]}" "${passthrough_args[@]}"
}
