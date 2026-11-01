#!/usr/bin/env bash
# Runs under `op run --environment`, so the 1Password Environment's variables
# are in this process's environment next to everything the runner already
# had. A variable is the Environment's when its name is absent from the
# parent snapshot (OP_PARENT_ENV_DIGESTS, written by snapshot.sh) or its
# value's digest differs. Those are appended to GITHUB_ENV for the job's
# later steps, each line of each value masked first. Nothing else may be
# printed: the parent runs `op run --no-masking`.
set -euo pipefail

: "${OP_PARENT_ENV_DIGESTS:?action.yml passes the parent snapshot path}"
: "${GITHUB_ENV:?runs inside GitHub Actions}"

digest() {
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha256sum | cut -c1-64
  else
    printf '%s' "$1" | shasum -a 256 | cut -c1-64
  fi
}

# Names bash and the runner change between any parent and child.
skip() {
  case "$1" in
    _ | SHLVL | OLDPWD | PWD | OP_PARENT_ENV_DIGESTS | OP_EXPORT_PREFIXES) return 0 ;;
  esac
  return 1
}

wanted() {
  [ -z "${OP_EXPORT_PREFIXES:-}" ] && return 0
  local prefix
  for prefix in $OP_EXPORT_PREFIXES; do
    case "$1" in "$prefix"*) return 0 ;; esac
  done
  return 1
}

exported=0
for name in $(compgen -e); do
  skip "$name" && continue
  value="${!name}"
  if grep -qFx "${name} $(digest "$value")" "$OP_PARENT_ENV_DIGESTS"; then
    continue
  fi
  wanted "$name" || continue
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] && echo "::add-mask::$line"
  done <<<"$value"
  {
    echo "${name}<<__OP_ENVIRONMENT__"
    printf '%s\n' "$value"
    echo "__OP_ENVIRONMENT__"
  } >>"$GITHUB_ENV"
  exported=$((exported + 1))
done
echo "Exported $exported variable(s) from the 1Password Environment"
