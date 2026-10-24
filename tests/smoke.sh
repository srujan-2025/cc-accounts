#!/usr/bin/env bash
# Smoke test: runs the CLI against a throwaway HOME. No real accounts are touched.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP"
unset CC_ACCOUNTS_REGISTRY
CLI="$ROOT/cc-accounts.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }
check() { local what="$1"; shift; if "$@"; then echo "ok   $what"; else fail "$what"; fi; }

mkdir -p "$HOME/.claude" "$HOME/.claude-demo"

"$CLI" scan </dev/null >/dev/null
check "scan registers default and demo" bash -c "'$CLI' list | grep -q demo && '$CLI' list | grep -q default"

"$CLI" add team-a --short ta </dev/null >/dev/null
check "add creates the config dir" test -d "$HOME/.claude-team-a"
check "list shows the short name" bash -c "'$CLI' list | grep -q 'team-a *ta'"

out="$("$CLI" shell-init)"
check "shell-init defines cc-ta" grep -q 'function cc-ta ' <<<"$out"
check "shell-init defines ccd-ta" grep -q 'function ccd-ta ' <<<"$out"
check "shell-init defines cch and cc-list" bash -c "grep -q 'function cch ' <<<'$out' && grep -q 'function cc-list ' <<<'$out'"
check "shell-init never defines plain cc" bash -c "! grep -q 'function cc ' <<<'$out'"

"$CLI" desktop-off team-a >/dev/null
check "desktop-off drops ccd-ta" bash -c "! '$CLI' shell-init | grep -q 'ccd-ta'"
"$CLI" hide default >/dev/null
check "hide drops cc-default" bash -c "! '$CLI' shell-init | grep -q 'cc-default'"
"$CLI" unhide default >/dev/null
check "unhide brings it back" bash -c "'$CLI' shell-init | grep -q 'cc-default'"

if "$CLI" short team-a demo </dev/null 2>/dev/null; then fail "duplicate short name was accepted"; fi
echo "ok   duplicate short name rejected"

"$CLI" link team-a >/dev/null 2>&1 || true
printf 'x' > "$HOME/.claude/CLAUDE.md"
"$CLI" link team-a >/dev/null
check "link symlinks CLAUDE.md" test -L "$HOME/.claude-team-a/CLAUDE.md"

"$CLI" remove team-a >/dev/null
check "remove keeps the folder" test -d "$HOME/.claude-team-a"
check "remove unregisters" bash -c "! '$CLI' list | grep -q team-a"

echo "all smoke tests passed"
