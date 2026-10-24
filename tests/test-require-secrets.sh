#!/usr/bin/env bash
# Tests for quant/entrypoints/05-require-secrets.sh
cd "$(dirname "$0")/.." || exit 1
BASE=6abc3f17b7607c8337b9a96ec4c0e1b5b6495bf7  # last commit that shipped the old defaults
GUARD=quant/entrypoints/05-require-secrets.sh
FAILS=0
ERR=$(mktemp)

run_guard() { # args: env assignments passed through `env`
  env -u APP_KEY "$@" bash -c ". $GUARD" >/dev/null 2>"$ERR"
}

check() { # name expected_rc actual_rc
  if [ "$2" = "$3" ]; then echo "PASS: $1"; else echo "FAIL: $1 (expected $2, got $3)"; FAILS=$((FAILS + 1)); fi
}

run_guard; check "empty is refused" 1 $?
grep -q APP_KEY "$ERR" && echo "PASS: message names APP_KEY" || { echo "FAIL: message names APP_KEY"; FAILS=$((FAILS + 1)); }

# Old default goes from git straight into the environment of a subprocess; never printed.
OLD=$(git show "$BASE":docker-compose.yml | grep -E '^\s*- APP_KEY' | sed -E 's/.*:-(.*)\}$/\1/')
env APP_KEY="$OLD" bash -c ". $GUARD" >/dev/null 2>"$ERR"; check "known default is refused" 1 $?
unset OLD

run_guard APP_KEY='base64:your-generated-key-here'; check "placeholder is refused" 1 $?
run_guard APP_KEY="$(openssl rand -hex 16)"; check "unique value is accepted" 0 $?
run_guard APP_KEY='a$b&c#d e'; check "special characters are accepted" 0 $?

rm -f "$ERR"
[ "$FAILS" = 0 ] || { echo "$FAILS test(s) failed"; exit 1; }
echo "All tests passed"
