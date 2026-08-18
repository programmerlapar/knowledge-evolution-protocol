#!/usr/bin/env bash
# Tier 2 — the installed/live contract contains every mandatory section (regression guard).
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/lib.sh

AGENTS="$HOME/.config/opencode/AGENTS.md"
SKILL="$HOME/.config/opencode/skills/knowledge-evolution-protocol/SKILL.md"

# Allow overriding where to check (defaults to the live global install).
AGENTS="${KEP_TEST_AGENTS:-$AGENTS}"
SKILL="${KEP_TEST_SKILL:-$SKILL}"

assert_file "$AGENTS" "global AGENTS.md exists"
assert_file "$SKILL"  "skill SKILL.md exists"

AC="$(cat "$AGENTS")"
SC="$(cat "$SKILL")"

# Retrieve-before
assert_contains "$AC" "Retrieve before"          "AGENTS: retrieve-before section"
assert_contains "$AC" "[brain] searched"          "AGENTS: retrieval announcement"
assert_contains "$AC" "[brain] applied"           "AGENTS: applied announcement"
assert_contains "$AC" "top 1–3 hits"               "AGENTS: bounded retrieval"

# Capture-after
assert_contains "$AC" "Capture after"             "AGENTS: capture-after section"
assert_contains "$AC" "qmd update -c opencode"    "AGENTS: reindex update cmd"
assert_contains "$AC" "qmd embed -c opencode"     "AGENTS: reindex embed cmd"
assert_contains "$AC" "[brain] captured"           "AGENTS: capture announcement"

# Mandatory issue capture
assert_contains "$AC" "Mandatory issue capture"   "AGENTS: mandatory issue capture"
assert_contains "$AC" "issues/<domain>/<name>.md" "AGENTS: issues namespace path"
assert_contains "$AC" "exact error string"        "AGENTS: exact-error requirement"

# Session sweep
assert_contains "$AC" "Session sweep"             "AGENTS: session sweep"
assert_contains "$AC" "memory/YYYY-MM-DD.md"      "AGENTS: memory journal path"

# Guardrails
assert_contains "$AC" "Never"                     "AGENTS: guardrails present"
assert_contains "$AC" "secrets"                   "AGENTS: no-secrets guardrail"

# Env override
assert_contains "$AC" "KEP_BRAIN_DIR"             "AGENTS: env override documented"

# Skill mirrors the contract
assert_contains "$SC" "Mandatory issue capture"   "SKILL: mandatory issue capture"
assert_contains "$SC" "queries"                   "SKILL: queries format"
assert_contains "$SC" "qmd update -c opencode"    "SKILL: reindex update cmd"
assert_contains "$SC" "qmd embed -c opencode"     "SKILL: reindex embed cmd"
assert_contains "$SC" "KEP_BRAIN_DIR"             "SKILL: env override documented"

summary "tier2/contract"