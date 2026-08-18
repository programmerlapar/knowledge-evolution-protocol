#!/usr/bin/env bash
# Tier 1 — qmd MCP server handshake exposes the expected tools and collections.
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib.sh
trap cleanup_scratch EXIT

S=$(new_scratch)
make_qmd_env "$S"
QMD="$(resolve_qmd)"
BRAIN="$S/brain"
mkdir -p "$BRAIN/patterns/example"
printf -- '---\ntopic: x\nqueries: ["x"]\ntags: [x]\nupdated: 2026-08-18\n---\nbody\n' > "$BRAIN/patterns/example/x.md"
"$QMD" collection add "$BRAIN" --name opencode >/dev/null 2>&1
"$QMD" update -c opencode >/dev/null 2>&1

note "spawning qmd MCP server and running handshake"
REQ=$'{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"t","version":"1"}}}\n{"jsonrpc":"2.0","method":"notifications/initialized"}\n{"jsonrpc":"2.0","id":2,"method":"tools/list"}\n'
RESP="$(printf '%s' "$REQ" | timeout 15 "$QMD" mcp 2>/dev/null | tail -1)"

assert_contains "$RESP" '"query"'     "MCP exposes query tool"
assert_contains "$RESP" '"get"'       "MCP exposes get tool"
assert_contains "$RESP" 'tools'       "tools/list returned a result"

summary "tier1/mcp_handshake"