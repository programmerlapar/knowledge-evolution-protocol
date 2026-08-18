#!/usr/bin/env bash
# Tier 1 — BM25 exact-term recall against a scratch brain (model-free, fast).
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib.sh
trap cleanup_scratch EXIT

S=$(new_scratch)
make_qmd_env "$S"
QMD="$(resolve_qmd)"

ERROR_STRING="ERR_SOCKET_TIMEOUT_997: connect ETIMEDOUT 192.168.1.50:8080"
BRAIN="$S/brain"
mkdir -p "$BRAIN/issues/network" "$BRAIN/patterns/network"

cat > "$BRAIN/issues/network/socket-timeout.md" <<EOF
---
topic: socket-timeout-fix
queries: ["ERR_SOCKET_TIMEOUT_997", "connect ETIMEDOUT", "increase http agent timeout"]
tags: [issue, network, node]
updated: 2026-08-18
---
# Symptom
Outbound HTTP requests die after 10s against slow endpoints.
# Exact error
$ERROR_STRING
# Root cause
Default undici httpAgent.connectTimeout is too short for the target.
# Fix steps
Raise connectTimeout to 30s in the fetch dispatcher.
EOF

cat > "$BRAIN/patterns/network/retry-backoff.md" <<EOF
---
topic: retry-backoff
queries: ["retry", "backoff", "transient network failure"]
tags: [pattern, network]
updated: 2026-08-18
---
Retry transient failures with exponential backoff + jitter, capped at 5 attempts.
EOF

"$QMD" collection add "$BRAIN" --name opencode >/dev/null 2>&1
"$QMD" update -c opencode >/dev/null 2>&1 || true

note "BM25 exact-term recall (search)"
OUT="$("$QMD" search "ERR_SOCKET_TIMEOUT_997" -c opencode 2>/dev/null)"
assert_contains "$OUT" "socket-timeout.md" "exact error string returns the issue doc"

note "BM25 finds by a keyword in queries frontmatter"
OUT="$("$QMD" search "increase http agent timeout" -c opencode 2>/dev/null)"
assert_contains "$OUT" "socket-timeout.md" "keyword from queries frontmatter is findable"

note "get retrieves full doc"
DOC="$("$QMD" get "qmd://opencode/issues/network/socket-timeout.md" 2>/dev/null || true)"
if [[ -z "$DOC" ]]; then
  DOC="$("$QMD" get "issues/network/socket-timeout.md" 2>/dev/null || true)"
fi
assert_contains "$DOC" "Root cause" "get returns full issue body"

summary "tier1/search"