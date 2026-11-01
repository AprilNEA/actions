#!/usr/bin/env bash
# Prints one `NAME DIGEST` line per exported variable of the calling shell's
# environment, where DIGEST is the SHA-256 of the value. export.sh compares
# the child's environment against this to find what `op run` injected.
# Digests, not values: the parent's environment holds the service-account
# token.
set -euo pipefail

digest() {
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha256sum | cut -c1-64
  else
    printf '%s' "$1" | shasum -a 256 | cut -c1-64
  fi
}

for name in $(compgen -e); do
  printf '%s %s\n' "$name" "$(digest "${!name}")"
done
