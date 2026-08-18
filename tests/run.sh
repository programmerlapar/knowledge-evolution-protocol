#!/usr/bin/env bash
# KEP test runner.
#   bash tests/run.sh           -> Tier 1 + 2 (plumbing + contract, no LLM)
#   RUN_E2E=1 bash tests/run.sh  -> + Tier 3 real opencode session (needs model API)
set -euo pipefail
cd "$(dirname "$0")/.."

failures=0
run() {
  local name="$1"
  echo "==========================================================="
  echo "[suite] $name"
  echo "==========================================================="
  if bash "tests/$name.sh"; then
    echo
  else
    failures=$((failures+1))
  fi
}

run test_install
run test_search
run test_capture_reindex
run test_mcp_handshake
run test_contract

if [[ "${RUN_SLOW:-0}" == "1" ]]; then
  run test_semantic
else
  echo "==========================================================="
  echo "[skip] test_semantic (set RUN_SLOW=1 to run vsearch/hybrid recall; needs models)"
  echo "==========================================================="
fi

if [[ "${RUN_E2E:-0}" == "1" ]]; then
  run e2e_recurrence
else
  echo "==========================================================="
  echo "[skip] e2e_recurrence (set RUN_E2E=1 to run real opencode session)"
  echo "==========================================================="
fi

echo
if [[ $failures -eq 0 ]]; then
  echo "[done] all Tier 1 + 2 suites passed"
  exit 0
else
  echo "[done] $failures suite(s) FAILED"
  exit 1
fi