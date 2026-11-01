#!/usr/bin/env bash
# Exercises snapshot.sh + export.sh the way action.yml runs them, with a
# stand-in `op` that injects variables instead of reading 1Password.
# Checks: only injected or changed variables are exported, prefixes filter,
# multi-line values survive, each value line is masked, nothing else prints.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cat >"$work/op" <<'EOF'
#!/usr/bin/env bash
# op run --no-masking --environment ID -- cmd...
shift 4
APPLE_ID='from-environment@example.com' \
  GITHUB_APP_PRIVATE_KEY=$'line1\nline2' \
  SHADOWED='new value' \
  exec "$@"
EOF
chmod +x "$work/op"

run_case() { # run_case <prefixes> <expected names, space separated>
	local prefixes="$1" expected="$2"
	: >"$work/github_env"
	(
		export PATH="$work:$PATH" GITHUB_ENV="$work/github_env" RUNNER_TEMP="$work"
		export OP_SERVICE_ACCOUNT_TOKEN=token OP_ENVIRONMENT_ID=envid ACTION_PATH="$here"
		export OP_EXPORT_PREFIXES="$prefixes"
		export CARGO_REGISTRY_TOKEN=already-in-runner-env SHADOWED='old value'
		OP_PARENT_ENV_DIGESTS="$(mktemp)"
		export OP_PARENT_ENV_DIGESTS
		bash "$here/snapshot.sh" >"$OP_PARENT_ENV_DIGESTS"
		op run --no-masking --environment "$OP_ENVIRONMENT_ID" -- bash "$here/export.sh"
	) >"$work/stdout"
	local got
	got="$(grep -o '^[A-Z_]*<<' "$work/github_env" | tr -d '<' | sort | tr '\n' ' ' | sed 's/ $//')"
	if [ "$got" != "$expected" ]; then
		echo "prefixes='$prefixes': exported '$got', expected '$expected'" >&2
		exit 1
	fi
}

run_case "" "APPLE_ID GITHUB_APP_PRIVATE_KEY SHADOWED"
run_case "GITHUB_APP_ CARGO_" "GITHUB_APP_PRIVATE_KEY"

# The last run's details: the multi-line key and the masks.
grep -qx 'line2' "$work/github_env"
grep -qx '::add-mask::line1' "$work/stdout"
grep -qx '::add-mask::line2' "$work/stdout"
if grep -v '^::add-mask::' "$work/stdout" | grep -qv '^Exported '; then
	echo "unexpected stdout:" >&2
	cat "$work/stdout" >&2
	exit 1
fi
echo "op-environment self-test passed"
