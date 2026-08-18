#!/usr/bin/env bash
# Tier 1 — install.sh in an isolated sandbox.
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib.sh
trap cleanup_scratch EXIT

S=$(new_scratch)
make_qmd_env "$S"
export KEP_OPENCODE_DIR="$S/opencode"
export KEP_BRAIN_DIR="$S/opencode/brain"
export KEP_NO_INSTALL=1
export QMD="$(resolve_qmd)"

mkdir -p "$KEP_OPENCODE_DIR"
echo '{"$schema":"https://opencode.ai/config.json"}' > "$KEP_OPENCODE_DIR/opencode.json"

note "running install.sh into sandbox"
bash scripts/install.sh >/dev/null 2>&1 || bad "install.sh exited non-zero" || true
ok "install.sh exited 0"

assert_dir  "$KEP_BRAIN_DIR/concepts"      "brain/concepts created"
assert_dir  "$KEP_BRAIN_DIR/issues"        "brain/issues created"
assert_dir  "$KEP_BRAIN_DIR/patterns"      "brain/patterns created"
assert_dir  "$KEP_BRAIN_DIR/references"    "brain/references created"
assert_dir  "$KEP_BRAIN_DIR/toolbox"       "brain/toolbox created"
assert_dir  "$KEP_BRAIN_DIR/memory"        "brain/memory created"

AGENTS="$KEP_OPENCODE_DIR/AGENTS.md"
assert_file "$AGENTS"                                        "AGENTS.md created"
assert_contains "$(cat "$AGENTS")" "Knowledge Evolution Protocol" "contract header present"
assert_contains "$(cat "$AGENTS")" "Mandatory issue capture"      "mandatory issue capture section"
assert_contains "$(cat "$AGENTS")" "[brain] searched"              "retrieval announcement marker"
assert_contains "$(cat "$AGENTS")" "KEP_BRAIN_DIR"                 "env override documented"

assert_file "$KEP_OPENCODE_DIR/skills/knowledge-evolution-protocol/SKILL.md" "skill installed"
assert_file "$KEP_OPENCODE_DIR/command/remember.md"                          "command installed"

CFG="$KEP_OPENCODE_DIR/opencode.json"
assert_contains "$(cat "$CFG")" '"qmd"' "qmd MCP registered"
assert_contains "$(cat "$CFG")" '"mcp"' "mcp key present"

# Collection registered pointing at sandbox brain (isolated qmd env).
QCOLS="$("$QMD" collection list 2>/dev/null)"
assert_contains "$QCOLS" "opencode" "opencode collection registered"
assert_contains "$(cat "$XDG_CONFIG_HOME/qmd/index.yml")" "$KEP_BRAIN_DIR" "collection points at sandbox brain"

# Idempotency: second run must not clobber or fail.
bash scripts/install.sh >/dev/null 2>&1 && ok "second install (idempotent) exits 0" || bad "second install failed"

summary "tier1/install"