#!/usr/bin/env bash
# Fail when a compose service carries a literal or non-empty default value for a
# secret-like environment variable. Services with a quant.type label are
# platform-managed and out of scope.
# Usage: lint-compose-secrets.sh <compose-file>...
# Prints "file:line: VAR has a literal value" per violation to stdout.
# Exit 0 when clean, 1 when any violation is found, 2 on a usage error.

NAME_RE='(key|secret|password|pass|token|salt)'

lint_file() {
  awk -v file="$1" -v name_re="$NAME_RE" '
    function indent(s) { match(s, /^ */); return RLENGTH }
    function strip(v) { gsub(/^[ \t]+|[ \t]+$/, "", v); gsub(/^["\047]|["\047]$/, "", v); return v }
    function is_literal(v) {
      if (v == "") return 0
      if (v ~ /^\$\{[A-Za-z_][A-Za-z0-9_]*(:-)?\}$/) return 0
      if (v ~ /^\$\{[A-Za-z_][A-Za-z0-9_]*:?[?+]/) return 0
      if (v ~ /^\$[A-Za-z_][A-Za-z0-9_]*$/) return 0
      return 1
    }
    function flush(  i) {
      if (!managed) for (i = 1; i <= n; i++) { print file ":" ln[i] ": " nm[i] " has a literal value"; violations++ }
      n = 0; managed = 0
    }
    function record(lineno, name, value) {
      if (tolower(name) ~ name_re && is_literal(strip(value))) { n++; ln[n] = lineno; nm[n] = name }
    }
    function handle_env(line, lineno,  body, p, sep) {
      body = line; sub(/^ *(- +)?/, "", body)
      sep = (line ~ /^ *- /) ? "=" : ":"
      p = index(body, sep)
      if (p > 0) record(lineno, substr(body, 1, p - 1), substr(body, p + 1))
    }
    /^[ \t]*(#|$)/ { next }
    /^services:/ { in_services = 1; next }
    /^[^ ]/ { if (in_services) flush(); in_services = 0; env = 0; next }
    !in_services { next }
    indent($0) == 2 && /:[ \t]*$/ { flush(); env = 0; next }
    /quant\.type/ { managed = 1 }
    env && indent($0) <= env_indent { env = 0 }
    env { handle_env($0, NR); next }
    /^ *environment:[ \t]*$/ { env = 1; env_indent = indent($0) }
    END { flush(); exit (violations > 0) ? 1 : 0 }
  ' "$1"
}

main() {
  local rc=0 out f
  for f in "$@"; do
    out=$(lint_file "$f") || rc=1
    [ -z "$out" ] || printf '%s\n' "$out"
  done
  return "$rc"
}

[ "$#" -gt 0 ] || { echo "Usage: $0 <compose-file>..." >&2; exit 2; }
main "$@"
