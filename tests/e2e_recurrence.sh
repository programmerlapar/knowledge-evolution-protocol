#!/usr/bin/env bash
# Tier 3 — END-TO-END: a real headless opencode session on a fixture Node project.
# Proves: retrieve-before ([brain] markers), mandatory issue capture, and reuse on recurrence.
# Gated: only runs when RUN_E2E=1. Requires a configured model provider; costs tokens.
#
# Isolation: temporarily re-points the real qmd 'opencode' collection to a SCRATCH brain,
# sets KEP_BRAIN_DIR=scratch, then RESTORES index.yml on exit. Your real brain is never
# written to.
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib.sh

: "${RUN_E2E:?RUN_E2E=1 is required to run this suite}"
command -v opencode >/dev/null 2>&1 || { echo "opencode not found"; exit 1; }

S=$(new_scratch)
make_qmd_env "$S"
QMD="$(resolve_qmd)"
BRAIN="$S/brain"
PROJ="$S/project"
INDEX="$HOME/.config/qmd/index.yml"
INDEX_BAK="$S/index.yml.bak"

OPENCODE="$(command -v opencode)"
OPENCODE="opencode"

note "preparing scratch brain + fixture project"
mkdir -p "$BRAIN/references/fixture" "$BRAIN/issues"
cp -r tests/fixtures/buggy-node-app "$PROJ"

# Seed a reference note so session 1 has something to retrieve.
cat > "$BRAIN/references/fixture/buggy-node-app.md" <<'EOF'
---
topic: buggy-node-app-config
queries: ["APP_CONFIG_ERROR", "missing server.port in config.json", "buggy-node-app won't start"]
tags: [reference, fixture, node]
updated: 2026-08-18
---
# What
A tiny Node ESM server. On startup it reads config.json and throws
`APP_CONFIG_ERROR: missing server.port in config.json` when `config.server.port` is absent.
# Fix
Add a `server` object with a numeric `port` to config.json, e.g.
`"server": { "port": 8080 }`.
EOF

# Temporarily re-point the real qmd 'opencode' collection at the scratch brain.
cp "$INDEX" "$INDEX_BAK"
restore_index() {
  cp "$INDEX_BAK" "$INDEX"
  "$QMD" update -c opencode >/dev/null 2>&1 || true
  echo "  [e2e] restored qmd index.yml"
}
trap restore_index EXIT

python3 - "$INDEX" "$BRAIN" <<'PY'
import sys
p, brain = sys.argv[1], sys.argv[2]
lines = open(p).read().splitlines(keepends=True)
out, in_opencode, wrote = [], False, False
for ln in lines:
    if ln.startswith("  opencode:"):
        in_opencode = True
        out.append(ln)
        continue
    if in_opencode and ln.startswith("    path:"):
        out.append(f"    path: {brain}\n")
        in_opencode, wrote = False, True
        continue
    out.append(ln)
if not wrote:
    raise SystemExit("could not locate opencode collection path in index.yml")
open(p, "w").writelines(out)
print("  [e2e] re-pointed opencode collection ->", brain)
PY

"$QMD" update -c opencode >/dev/null 2>&1
"$QMD" embed -c opencode >/dev/null 2>&1 || true
note "scratch brain seeded + indexed"

run_session() { # $1: label, $2: prompt, $3: outfile
  note "openode run: $1"
  ( cd "$PROJ" && KEP_BRAIN_DIR="$BRAIN" timeout 420 "$OPENCODE" run --print-logs "$2" ) > "$3" 2>&1 || true
}

SESSION1="$S/session1.log"
run_session "session 1 (first fix)" \
  "The app crashes at startup. Run it, diagnose the failure, fix it, and confirm it starts. Follow the brain-first protocol." \
  "$SESSION1"

note "verifying session 1"
assert_contains "$(cat "$SESSION1")" "[brain]" "session 1 emitted a [brain] marker"

( cd "$PROJ" && node index.js >/dev/null 2>&1 ) && ok "session 1 fixed the app (node starts)" \
  || bad "session 1 did not fix the app"

ISSUES=$(find "$BRAIN/issues" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
if [[ "$ISSUES" -ge 1 ]]; then
  ok "session 1 captured at least one issue note ($ISSUES)"
else
  bad "session 1 produced no issue capture"
fi

# Reintroduce the bug for the recurrence pass.
printf '{\n  "logLevel": "info"\n}\n' > "$PROJ/config.json"

SESSION2="$S/session2.log"
run_session "session 2 (recurrence, rephrased)" \
  "The server won't boot again after a config change — the healthcheck keeps failing at startup. Fix it. Follow the brain-first protocol and reuse prior knowledge." \
  "$SESSION2"

note "verifying session 2"
( cd "$PROJ" && node index.js >/dev/null 2>&1 ) && ok "session 2 fixed the app again" \
  || bad "session 2 did not fix the app"

if grep -q "\[brain\] applied" "$SESSION2" || grep -qi "APP_CONFIG_ERROR" "$SESSION2"; then
  ok "session 2 reused prior knowledge"
else
  bad "session 2 did not visibly reuse prior knowledge"
fi

restore_index
trap - EXIT
summary "tier3/e2e_recurrence"