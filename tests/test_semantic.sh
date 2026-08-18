#!/usr/bin/env bash
# Tier 1 (slow, optional) — semantic (vsearch) + hybrid (query) recall.
# Requires embedding/query-expansion models; first run may download GGUF weights.
# Gated: only runs when RUN_SLOW=1.
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib.sh
trap cleanup_scratch EXIT

: "${RUN_SLOW:?RUN_SLOW=1 is required to run this suite}"
S=$(new_scratch)
make_qmd_env "$S"
QMD="$(resolve_qmd)"

BRAIN="$S/brain"
mkdir -p "$BRAIN/issues/network"
cat > "$BRAIN/issues/network/socket-timeout.md" <<'EOF'
---
topic: socket-timeout-fix
queries: ["ERR_SOCKET_TIMEOUT_997", "connect ETIMEDOUT", "increase http agent timeout"]
tags: [issue, network, node]
updated: 2026-08-18
---
# Symptom
Outbound HTTP requests die after 10 seconds against slow endpoints.
# Root cause
Default http agent connect timeout is too short for the target.
# Fix steps
Raise connectTimeout to 30 seconds in the fetch dispatcher.
EOF

"$QMD" collection add "$BRAIN" --name opencode >/dev/null 2>&1
"$QMD" update -c opencode >/dev/null 2>&1
"$QMD" embed -c opencode >/dev/null 2>&1 || true

note "semantic recall (vsearch)"
OUT="$("$QMD" vsearch "http requests to a slow host keep timing out" -c opencode 2>/dev/null)"
assert_contains "$OUT" "socket-timeout.md" "paraphrased description finds issue doc"

note "hybrid recall (query)"
OUT="$("$QMD" query 'lex:connect ETIMEDOUT\nvec:http request times out on slow server' -c opencode 2>/dev/null)"
assert_contains "$OUT" "socket-timeout.md" "hybrid query finds issue doc"

summary "tier1/semantic"