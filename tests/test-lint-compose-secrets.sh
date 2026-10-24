#!/usr/bin/env bash
# Tests for scripts/lint-compose-secrets.sh
cd "$(dirname "$0")/.." || exit 1
LINT=scripts/lint-compose-secrets.sh
FAILS=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

check() { # name expected_rc actual_rc
  if [ "$2" = "$3" ]; then echo "PASS: $1"; else echo "FAIL: $1 (expected $2, got $3)"; FAILS=$((FAILS + 1)); fi
}

git show 6abc3f17b7607c8337b9a96ec4c0e1b5b6495bf7:docker-compose.yml > "$TMP/old.yml"
bash "$LINT" "$TMP/old.yml" >/dev/null 2>&1; check "old compose is rejected" 1 $?

bash "$LINT" docker-compose.yml >/dev/null 2>&1; check "new compose passes" 0 $?

cat > "$TMP/empty.yml" <<'YML'
services:
  app:
    environment:
      - API_TOKEN=${API_TOKEN:-}
      - OTHER_SECRET=${OTHER_SECRET}
      - SOME_PASS=
YML
bash "$LINT" "$TMP/empty.yml" >/dev/null 2>&1; check "empty defaults pass" 0 $?

cat > "$TMP/managed.yml" <<'YML'
services:
  db:
    labels:
      quant.type: database
    environment:
      - MYSQL_PASSWORD=${X:-y}
YML
bash "$LINT" "$TMP/managed.yml" >/dev/null 2>&1; check "quant.type service is out of scope" 0 $?

cat > "$TMP/map.yml" <<'YML'
services:
  app:
    environment:
      SESSION_SECRET: literal
YML
OUT=$(bash "$LINT" "$TMP/map.yml" 2>&1); check "map form literal is rejected" 1 $?
case "$OUT" in *"map.yml:4: SESSION_SECRET has a literal value"*) echo "PASS: message format";; *) echo "FAIL: message format"; FAILS=$((FAILS + 1));; esac

[ "$FAILS" = 0 ] || { echo "$FAILS test(s) failed"; exit 1; }
echo "All tests passed"
