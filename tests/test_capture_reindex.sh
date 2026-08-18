#!/usr/bin/env bash
# Tier 1 — capture -> reindex -> immediately findable by the exact error string (BM25, fast).
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib.sh
trap cleanup_scratch EXIT

S=$(new_scratch)
make_qmd_env "$S"
QMD="$(resolve_qmd)"
BRAIN="$S/brain"
mkdir -p "$BRAIN/issues/db"
"$QMD" collection add "$BRAIN" --name opencode >/dev/null 2>&1

ERROR="TypeError: Cannot read properties of undefined (reading 'cursor')"

note "writing a new issue capture then reindexing"
cat > "$BRAIN/issues/db/pg-cursor.md" <<EOF
---
topic: pg-cursor-undefined
queries: ["Cannot read properties of undefined (reading 'cursor')", "pg query cursor undefined"]
tags: [issue, db]
updated: 2026-08-18
---
# Symptom
Cursor is undefined after a failed pg query.
# Exact error
$ERROR
# Root cause
Query threw before assigning result.
# Fix steps
Check query error before reading result.cursor.
EOF

"$QMD" update -c opencode >/dev/null 2>&1

note "searching by exact error string immediately after capture"
OUT="$("$QMD" search "$ERROR" -c opencode 2>/dev/null)"
assert_contains "$OUT" "pg-cursor.md" "captured issue is findable by exact error"

note "findable by a term from queries frontmatter"
OUT="$("$QMD" search "pg query cursor undefined" -c opencode 2>/dev/null)"
assert_contains "$OUT" "pg-cursor.md" "captured issue findable via queries keyword"

summary "tier1/capture_reindex"