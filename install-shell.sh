#!/usr/bin/env bash
# One-time shell setup: load the account commands in every new terminal.
#  - backs up ~/.zshrc
#  - removes old `alias cc-SHORT=...` / `alias ccd-SHORT=...` lines that collide with a registered
#    account (an alias breaks the function of the same name in zsh)
#  - appends the shell-init line if it is not there yet
# Override the file for testing:  ZSHRC=/tmp/test-zshrc ./install-shell.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RC="${ZSHRC:-$HOME/.zshrc}"
REGISTRY="${CC_ACCOUNTS_REGISTRY:-$HOME/.config/cc-accounts/accounts}"
LOAD="eval \"\$($HERE/cc-accounts.sh shell-init)\""

touch "$RC"
bak="$RC.bak-$(date +%Y%m%d-%H%M%S)"
cp "$RC" "$bak"
echo "backup: $bak"

if [ -s "$REGISTRY" ]; then
  while IFS=$'\t' read -r name _ short; do
    short="${short:-$name}"
    for fn in "cc-$short" "ccd-$short"; do
      if grep -qE "^alias $fn=" "$RC"; then
        grep -vE "^alias $fn=" "$RC" > "$RC.tmp" && mv "$RC.tmp" "$RC"
        echo "removed old alias: $fn"
      fi
    done
  done < "$REGISTRY"
fi

# drop a load line left by the tool's earlier name (claude-accounts.sh), if any
if grep -qF "claude-accounts.sh shell-init" "$RC"; then
  grep -vF "claude-accounts.sh shell-init" "$RC" > "$RC.tmp" && mv "$RC.tmp" "$RC"
  echo "removed load line from the earlier tool name"
fi

if grep -qF "cc-accounts.sh shell-init" "$RC"; then
  echo "load line already present"
else
  printf '%s\n' "$LOAD" >> "$RC"
  echo "added load line"
fi
echo "now run: source $RC"
