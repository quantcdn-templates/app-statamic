#!/bin/bash
# Require generated application secrets. This file is sourced by
# /quant/entrypoints.sh, so `exit 1` stops the container.
#
# KNOWN_DEFAULT_SHA256 lists SHA-256 hashes of values that earlier template
# versions or examples shipped. A secret that is empty or matches a hash is refused.

KNOWN_DEFAULT_SHA256="
dcf77dec425c4ba25a2d8b1357d9f3b4044985624fbe299f15956c142b7ad740
3b9be04a556a3a285fd6f2969d2c5ca48ce714eb4bd9eddcc77ef0aa1ef68ef6
"

secret_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha256sum | cut -d' ' -f1
  else
    printf '%s' "$1" | shasum -a 256 | cut -d' ' -f1
  fi
}

is_known_default() {
  local hash
  hash=$(secret_sha256 "$1")
  case " $(echo $KNOWN_DEFAULT_SHA256) " in
    *" $hash "*) return 0 ;;
  esac
  return 1
}

require_secret() {
  local name="$1" value="${!1}"
  if [ -z "$value" ] || is_known_default "$value"; then
    echo "ERROR: $name is not set to a unique value. Set it as an application secret and redeploy." >&2
    exit 1
  fi
}

require_secret APP_KEY
