#!/usr/bin/env bash
# KEP test helpers. Source from test scripts.
set -euo pipefail

PASS=0
FAIL=0
FAILED_NAMES=()

note()   { printf '\033[1;36m[test]\033[0m %s\n' "$*"; }
ok()     { PASS=$((PASS+1)); printf '  \033[32m✓\033[0m %s\n' "$*"; }
bad()    { FAIL=$((FAIL+1)); FAILED_NAMES+=("$1"); printf '  \033[31m✗\033[0m %s\n' "$*"; }

assert_contains() { # $1: haystack, $2: needle, $3: test name
  if [[ "$1" == *"$2"* ]]; then ok "$3"; else bad "$3"; note "  expected substring: $2"; fi
}

assert_file() { # $1: path, $2: test name
  if [[ -f "$1" ]]; then ok "$2"; else bad "$2"; note "  missing file: $1"; fi
}

assert_dir() { # $1: path, $2: test name
  if [[ -d "$1" ]]; then ok "$2"; else bad "$2"; note "  missing dir: $1"; fi
}

assert_eq() { # $1: actual, $2: expected, $3: test name
  if [[ "$1" == "$2" ]]; then ok "$3"; else bad "$3"; note "  expected: $2"; note "  actual:   $1"; fi
}

# Resolve a working qmd command (Node-24/CPU wrapper preferred if present).
resolve_qmd() {
  if [[ -n "${QMD:-}" ]]; then echo "$QMD"; return; fi
  if [[ -x "$HOME/.openclaw/workspace/scripts/qmd-safe.sh" ]]; then
    echo "$HOME/.openclaw/workspace/scripts/qmd-safe.sh"
  else
    echo "qmd"
  fi
}

# Isolated qmd environment: fresh config + data under $1.
make_qmd_env() { # $1: scratch root
  export XDG_CONFIG_HOME="$1/qmd-config"
  export XDG_DATA_HOME="$1/qmd-data"
  mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME"
}

# Scratch helpers (trap-based cleanup).
declare -a SCRATCH_DIRS=()
new_scratch() {
  local d
  d="$(mktemp -d /tmp/kep-test.XXXXXX)"
  SCRATCH_DIRS+=("$d")
  echo "$d"
}
cleanup_scratch() {
  for d in "${SCRATCH_DIRS[@]:-}"; do rm -rf "$d" 2>/dev/null || true; done
}

summary() { # $1: suite name
  echo
  if [[ $FAIL -eq 0 ]]; then
    printf '\033[1;32m[pass]\033[0m %s — %d passed, 0 failed\n' "$1" "$PASS"
    exit 0
  else
    printf '\033[1;31m[fail]\033[0m %s — %d passed, %d failed: %s\n' "$1" "$PASS" "$FAIL" "${FAILED_NAMES[*]}"
    exit 1
  fi
}