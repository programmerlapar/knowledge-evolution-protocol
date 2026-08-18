#!/usr/bin/env bash
# Knowledge Evolution Protocol (KEP) — installer for opencode
# Idempotent. Run: bash scripts/install.sh
#
# Overrides (env):
#   KEP_OPENCODE_DIR  global opencode config dir  (default ~/.config/opencode)
#   KEP_BRAIN_DIR     brain root                  (default $KEP_OPENCODE_DIR/brain)
#   KEP_QMD_CMD       qmd command                 (default: qmd, or wrapper)
#   KEP_USE_WRAPPER   use an existing qmd wrapper  (default auto-detect)
#   KEP_NO_INSTALL    skip installing qmd         (set to 1 to skip)
set -euo pipefail

OPENCODE_DIR="${KEP_OPENCODE_DIR:-$HOME/.config/opencode}"
BRAIN_DIR="${KEP_BRAIN_DIR:-$OPENCODE_DIR/brain}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log()  { printf '\033[1;32m[KEP]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[KEP]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[KEP] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

mkdir -p "$OPENCODE_DIR"

# --- 1. Ensure qmd -----------------------------------------------------------
QMD_CMD="${KEP_QMD_CMD:-}"
if [[ -z "$QMD_CMD" ]]; then
  if [[ "${KEP_USE_WRAPPER:-}" == "1" && -x "$HOME/.openclaw/workspace/scripts/qmd-safe.sh" ]]; then
    QMD_CMD="$HOME/.openclaw/workspace/scripts/qmd-safe.sh"
    log "Using machine qmd wrapper (Node/CPU-forced): $QMD_CMD"
  elif command -v qmd >/dev/null 2>&1; then
    QMD_CMD="$(command -v qmd)"
    log "Using qmd: $QMD_CMD"
  else
    if [[ "${KEP_NO_INSTALL:-}" == "1" ]]; then
      die "qmd not found and KEP_NO_INSTALL=1. Install with: npm i -g qmd"
    fi
    log "qmd not found — installing globally via npm..."
    npm i -g qmd
    QMD_CMD="$(command -v qmd)"
  fi
fi

# --- 2. Create brain scaffold + primary collection ---------------------------
log "Creating brain scaffold at $BRAIN_DIR"
mkdir -p "$BRAIN_DIR"/{concepts,issues,patterns,references,toolbox,memory}
touch "$BRAIN_DIR/.gitkeep"

if ! "$QMD_CMD" collection list 2>/dev/null | grep -qw opencode; then
  "$QMD_CMD" collection add "$BRAIN_DIR" --name opencode
  log "Registered collection 'opencode' -> $BRAIN_DIR"
else
  log "Collection 'opencode' already registered."
fi

# --- 3. Auto-detect OpenClaw brain as secondary collection -------------------
OPENCLAW_BRAIN="${KEP_OPENCLAW_BRAIN:-$HOME/.openclaw/workspace/brain}"
if [[ -d "$OPENCLAW_BRAIN" ]]; then
  if grep -qF "$OPENCLAW_BRAIN" "$HOME/.config/qmd/index.yml" 2>/dev/null; then
    log "OpenClaw brain already registered ($OPENCLAW_BRAIN) — reusing existing collection."
  elif ! "$QMD_CMD" collection list 2>/dev/null | grep -qw openclaw; then
    "$QMD_CMD" collection add "$OPENCLAW_BRAIN" --name openclaw
    log "Auto-detected OpenClaw brain -> collection 'openclaw' ($OPENCLAW_BRAIN)"
  else
    log "Collection 'openclaw' already registered."
  fi
else
  warn "No OpenClaw brain found at $OPENCLAW_BRAIN — skipping secondary collection (optional)."
fi

# --- 4. Index the brain ------------------------------------------------------
log "Indexing brain (update + embed)..."
"$QMD_CMD" update -c opencode
"$QMD_CMD" embed -c opencode || warn "embed failed — embeddings will generate on next qmd embed"

# --- 5. AGENTS.md contract (merge, never clobber) ----------------------------
AGENTS="$OPENCODE_DIR/AGENTS.md"
KEP_BLOCK=$(cat "$REPO_DIR/AGENTS.md.template")
if [[ -f "$AGENTS" ]]; then
  if grep -q "Knowledge Evolution Protocol (KEP)" "$AGENTS"; then
    log "AGENTS.md already contains KEP block — leaving as-is."
  else
    cp "$AGENTS" "$AGENTS.kep.bak"
    printf '\n\n---\n\n%s\n' "$KEP_BLOCK" >> "$AGENTS"
    log "Appended KEP block to existing $AGENTS (backup: $AGENTS.kep.bak)"
  fi
else
  cp "$REPO_DIR/AGENTS.md.template" "$AGENTS"
  log "Created global contract at $AGENTS"
fi

# --- 6. Skill + command ------------------------------------------------------
mkdir -p "$OPENCODE_DIR/skills/knowledge-evolution-protocol" "$OPENCODE_DIR/command"
cp "$REPO_DIR/SKILL.md" "$OPENCODE_DIR/skills/knowledge-evolution-protocol/SKILL.md"
cp "$REPO_DIR/command/remember.md" "$OPENCODE_DIR/command/remember.md"
log "Installed skill 'knowledge-evolution-protocol' and command '/remember'"

# --- 7. Register qmd MCP in opencode.json(c) --------------------------------
CONFIG=""
[[ -f "$OPENCODE_DIR/opencode.json"  ]] && CONFIG="$OPENCODE_DIR/opencode.json"
[[ -f "$OPENCODE_DIR/opencode.jsonc" ]] && CONFIG="$OPENCODE_DIR/opencode.jsonc"
if [[ -n "$CONFIG" ]]; then
  if grep -q '"qmd"' "$CONFIG"; then
    log "qmd MCP already present in $CONFIG"
  else
    cp "$CONFIG" "$CONFIG.kep.bak"
    python3 - "$CONFIG" "$QMD_CMD" <<'PY'
import json, sys
cfg_path, qmd_cmd = sys.argv[1], sys.argv[2]
with open(cfg_path) as f:
    text = f.read()
try:
    cfg = json.loads(text)
except json.JSONDecodeError as e:
    print(f"[KEP] WARN: could not parse {cfg_path} as strict JSON ({e}). Add the qmd MCP entry manually.")
    sys.exit(0)
mcp = cfg.setdefault("mcp", {})
mcp["qmd"] = {"type": "local", "command": [qmd_cmd, "mcp"], "enabled": True}
with open(cfg_path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
print(f"[KEP] Added qmd MCP to {cfg_path} (backup: {cfg_path}.kep.bak)")
PY
  fi
else
  warn "No opencode.json(c) found at $OPENCODE_DIR — add this manually:"
  cat <<'JSON'
"mcp": { "qmd": { "type": "local", "command": ["qmd", "mcp"], "enabled": true } }
JSON
  echo
fi

log "Done. Restart opencode for changes to take effect."
log "Verify: qmd collection list  |  grep '\[brain\]' in any session"