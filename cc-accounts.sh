#!/usr/bin/env bash
# cc-accounts: run Claude Code under several accounts, one config dir each.
# Each account = a CLAUDE_CONFIG_DIR holding its own login, settings, history, memory.
# Unofficial community tool, not affiliated with or endorsed by Anthropic. MIT licensed.
set -euo pipefail

REGISTRY="${CC_ACCOUNTS_REGISTRY:-$HOME/.config/cc-accounts/accounts}"
# one-time migration from the tool's earlier name
if [ -z "${CC_ACCOUNTS_REGISTRY:-}" ] && [ ! -f "$REGISTRY" ] && [ -f "$HOME/.config/claude-accounts/accounts" ]; then
  mkdir -p "$(dirname "$REGISTRY")" && cp "$HOME/.config/claude-accounts/accounts" "$REGISTRY"
fi
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

die() { echo "error: $*" >&2; exit 1; }

interactive() { [ -t 0 ]; }
ask() { # ask PROMPT [DEFAULT]: read an answer from the terminal; empty answer = default
  local ans; printf '%s%s: ' "$1" "${2:+ [$2]}" >&2; read -r ans || ans=""
  printf '%s' "${ans:-${2:-}}"
}
yes() { [[ "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" == y* ]]; }

valid_name() { [[ "$1" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || die "name must be lowercase letters, digits, - or _ (got '$1')"; }

dir_of() { # print dir for account name, or fail
  [ -f "$REGISTRY" ] || return 1
  awk -F'\t' -v n="$1" '$1==n {print $2; found=1} END{exit !found}' "$REGISTRY"
}

short_of() { # short name of an account (falls back to the account name)
  awk -F'\t' -v n="$1" '$1==n {print ($3==""?$1:$3); found=1} END{exit !found}' "$REGISTRY"
}

register() { # name dir [short]
  mkdir -p "$(dirname "$REGISTRY")"; touch "$REGISTRY"
  if dir_of "$1" >/dev/null 2>&1; then die "account '$1' already exists"; fi
  printf '%s\t%s\t%s\n' "$1" "$2" "${3:-$1}" >> "$REGISTRY"
}

cmd_short() { # short [NAME [SHORT]]: set the short name used in cc-SHORT / ccd-SHORT (asks if omitted)
  if [ $# -lt 2 ] && interactive; then
    [ $# -ge 1 ] || { cmd_list; set -- "$(ask "Which account (NAME)")"; }
    set -- "$1" "$(ask "New short name for '$1'" "$(short_of "$1")")"
  fi
  [ $# -eq 2 ] || die "usage: short NAME SHORT"
  dir_of "$1" >/dev/null || die "unknown account '$1'"
  valid_name "$2"
  local n d s
  while IFS=$'\t' read -r n d s; do
    [ "$n" = "$1" ] && continue
    [ "$n" = "$2" ] || [ "${s:-$n}" = "$2" ] && die "'$2' is already used by account '$n'"
  done < "$REGISTRY"
  local tmp; tmp="$(mktemp)"
  awk -F'\t' -v OFS='\t' -v n="$1" -v s="$2" '$1==n {$3=s} {print}' "$REGISTRY" > "$tmp" && mv "$tmp" "$REGISTRY"
  echo "'$1' is now cc-$2 (terminal) and ccd-$2 (desktop)"
}

has_flag() { [[ ",$1," == *",$2,"* ]]; }

cmd_flag() { # flag NAME FLAG on|off   (FLAG: nodesktop | hidden)
  local tmp; tmp="$(mktemp)"
  dir_of "$1" >/dev/null || die "unknown account '$1'"
  awk -F'\t' -v OFS='\t' -v n="$1" -v f="$2" -v on="$([ "$3" = on ] && echo 1 || echo 0)" '
    $1==n { if ($3=="") $3=$1
            m=split($4,a,","); out=""
            for(i=1;i<=m;i++) if(a[i]!=f && a[i]!="") out=out (out==""?"":",") a[i]
            if(on) out=out (out==""?"":",") f
            $4=out }
    {print}' "$REGISTRY" > "$tmp" && mv "$tmp" "$REGISTRY"
}

cmd_desktop_flag() { # desktop-off NAME | desktop-on NAME
  [ $# -eq 2 ] || die "usage: desktop-off NAME | desktop-on NAME"
  cmd_flag "$2" nodesktop "$([ "$1" = off ] && echo on || echo off)"
  echo "'$2': desktop launcher $1 (the Claude-$2 profile data was not touched)"
}

cmd_hide() { # hide NAME | unhide NAME: keep the account registered but drop its cc-/ccd- commands, apps and cch entry
  [ $# -eq 2 ] || die "usage: hide NAME | unhide NAME"
  cmd_flag "$2" hidden "$([ "$1" = hide ] && echo on || echo off)"
  echo "'$2': $1 (the account and its folder are untouched; re-run make-launchers.py and open a new terminal)"
}

cmd_desktop() { # desktop NAME: open that account's Claude Desktop profile
  [ $# -ge 1 ] || die "usage: desktop NAME"
  dir_of "$1" >/dev/null || die "unknown account '$1'"
  if [ "$1" = default ]; then open -a Claude
  else open -n -a Claude --args --user-data-dir="$HOME/Library/Application Support/Claude-$1" >/dev/null 2>&1; fi
}

email_of() { # config dir -> logged-in email or "not logged in"
  local f="$1/.claude.json"
  [ "$1" = "$HOME/.claude" ] && f="$HOME/.claude.json"
  if [ -f "$f" ] && command -v jq >/dev/null; then
    jq -r '.oauthAccount.emailAddress // "not logged in"' "$f" 2>/dev/null || echo "unreadable"
  else
    echo "not logged in"
  fi
}

cmd_add() { # add [NAME] [DIR] [--short SHORT]   (asks for what is missing when run in a terminal)
  local args=() short="" desk=y
  while [ $# -gt 0 ]; do
    case "$1" in --short) short="${2:-}"; shift 2 ;; *) args+=("$1"); shift ;; esac
  done
  if [ ${#args[@]} -eq 0 ]; then
    interactive || die "usage: add NAME [DIR] [--short SHORT]"
    args[0]="$(ask "Account name (folder will be ~/.claude-NAME), e.g. work")"
  fi
  valid_name "${args[0]}"
  if [ -z "$short" ] && interactive; then
    short="$(ask "Short name for the commands (cc-<short>, ccd-<short>)" "${args[0]}")"
  fi
  short="${short:-${args[0]}}"; valid_name "$short"
  if interactive; then desk="$(ask "Also create a Claude Desktop launcher (ccd-$short)? y/n" y)"; fi
  local dir="${args[1]:-$HOME/.claude-${args[0]}}"
  [ "${args[0]}" = "default" ] && dir="${args[1]:-$HOME/.claude}"
  mkdir -p "$dir"
  register "${args[0]}" "$dir" "$short"
  yes "$desk" || cmd_flag "${args[0]}" nodesktop on
  echo "added '${args[0]}' -> $dir  (cc-$short$(yes "$desk" && echo " / ccd-$short"))"
  if interactive && yes "$(ask "Rebuild the app launchers now? y/n" y)"; then
    python3 -I "$(dirname "$SELF")/make-launchers.py" 2>&1 | grep -v 'replacing existing' | tail -3 || true
  fi
  echo "next: run install-shell.sh once if you have not, open a new terminal, run cc-$short, then /login"
}

cmd_scan() { # register existing ~/.claude and ~/.claude-* dirs not yet registered
  local d name n=0
  if [ -d "$HOME/.claude" ] && ! dir_of default >/dev/null 2>&1; then
    register default "$HOME/.claude"; n=$((n+1))
    if interactive && yes "$(ask "Hide 'default' (~/.claude) from the cc-/ccd- commands and apps? It stays registered. y/n" y)"; then cmd_flag default hidden on; fi
  fi
  for d in "$HOME"/.claude-*; do
    [ -d "$d" ] || continue
    name="${d##*/.claude-}"
    [[ "$name" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || continue
    if ! dir_of "$name" >/dev/null 2>&1; then
      register "$name" "$d"; n=$((n+1))
      if interactive; then cmd_short "$name" "$(ask "Short name for '$name' (cc-<short>)" "$name")" >/dev/null || true; fi
    fi
  done
  echo "registered $n existing account dir(s)"
}

cmd_list() {
  [ -s "$REGISTRY" ] || { echo "no accounts yet. try: scan  or  add NAME"; return; }
  printf '%-18s %-10s %-34s %s\n' NAME SHORT DIR LOGIN
  while IFS=$'\t' read -r n d sh fl; do
    printf '%-18s %-10s %-34s %s%s\n' "$n" "${sh:-$n}" "${d/#$HOME/~}" "$(email_of "$d")" "${fl:+  [$fl]}"
  done < "$REGISTRY"
}

cmd_run() { # run NAME [claude args...]
  [ $# -ge 1 ] || die "usage: run NAME [claude args]"
  local name="$1"; shift
  local dir; dir="$(dir_of "$name")" || die "unknown account '$name' (see: list)"
  [ -d "$dir" ] || die "config dir missing: $dir"
  [ -z "${ANTHROPIC_API_KEY:-}" ] || echo "warning: ANTHROPIC_API_KEY is set and can override the account login" >&2
  CLAUDE_CONFIG_DIR="$dir" exec claude "$@"
}

# What accounts share vs keep separate (see `policy`):
#   SHARED   = symlinked to the source account, so one edit reaches every account
#   ISOLATED = never touched: login, history, memory, plugins, settings.json, skills
SHARED_ITEMS="CLAUDE.md scripts worktree-ledger.md"

cmd_link() { # link NAME [FROM]: symlink SHARED_ITEMS from FROM (default: 'default')
  [ $# -ge 1 ] || die "usage: link NAME [FROM]"
  local to from f t stamp
  to="$(dir_of "$1")" || die "unknown account '$1'"
  from="$(dir_of "${2:-default}")" || die "unknown source account '${2:-default}'"
  [ "$to" != "$from" ] || die "source and target are the same"
  stamp="$(date +%Y%m%d-%H%M%S)"
  for f in $SHARED_ITEMS; do
    t="$to/$f"
    [ -e "$from/$f" ] || { echo "  $f: not in source, skipped"; continue; }
    if [ -L "$t" ] && [ "$(readlink "$t")" = "$from/$f" ]; then echo "  $f: already linked"; continue; fi
    if [ -e "$t" ] || [ -L "$t" ]; then
      if [ -f "$t" ] && [ ! -L "$t" ] && [ "$(tr -d '[:space:]' < "$t" | wc -c)" -gt 0 ] && ! cmp -s "$t" "$from/$f"; then
        mkdir -p "$to/backups/pre-link-$stamp"; mv "$t" "$to/backups/pre-link-$stamp/$f"
        echo "  $f: had its own content -> backed up to backups/pre-link-$stamp/"
      elif [ -d "$t" ] && [ ! -L "$t" ]; then
        mkdir -p "$to/backups/pre-link-$stamp"; mv "$t" "$to/backups/pre-link-$stamp/$f"
        echo "  $f: directory backed up to backups/pre-link-$stamp/"
      else
        rm "$t"
      fi
    fi
    ln -s "$from/$f" "$t"; echo "  $f: linked"
  done
}

cmd_link_all() { # link every non-source account
  local src="${1:-default}" n d
  while IFS=$'\t' read -r n d _; do
    [ "$n" = "$src" ] && continue
    echo "[$n]"; cmd_link "$n" "$src"
  done < "$REGISTRY"
}

cmd_policy() {
  cat <<EOF
SHARED (symlinked from 'default'):  $SHARED_ITEMS
  CLAUDE.md          global working rules, same in every account
  scripts/           worktrees.sh etc.
  worktree-ledger.md one ledger, because worktrees are machine-wide
ISOLATED (never linked):
  .claude.json       the login — must stay per account
  projects/ history.jsonl sessions/ file-history/ paste-cache/   history and memory
  settings.json      plugins, model, permissions, hooks differ per account
  plugins/ skills/   installed plugins and skills differ per account
  cache/ telemetry/ state/ shell-snapshots/ ide/ backups/        machine/account state
EOF
}

cmd_handoff() { # handoff FROM TO [DIR] [--all] [--dry-run]: copy a project's latest session(s) + memory to another account
  local all=0 dry=0 args=() a
  for a in "$@"; do case "$a" in --all) all=1 ;; --dry-run) dry=1 ;; *) args+=("$a") ;; esac; done
  [ ${#args[@]} -ge 2 ] || die "usage: handoff FROM TO [DIR] [--all] [--dry-run]"
  local from to proj key sp tp f n=0
  from="$(dir_of "${args[0]}")" || die "unknown account '${args[0]}'"
  to="$(dir_of "${args[1]}")" || die "unknown account '${args[1]}'"
  [ "$from" != "$to" ] || die "FROM and TO are the same account"
  proj="$(cd "${args[2]:-$PWD}" && pwd -P)"
  key="$(printf '%s' "$proj" | sed 's/[^a-zA-Z0-9]/-/g')"
  sp="$from/projects/$key"; tp="$to/projects/$key"
  [ -d "$sp" ] || die "no sessions for $proj in account '${args[0]}' ($sp)"
  echo "project: $proj"
  echo "note: this copies conversation transcripts and memory between accounts. Only do it where" >&2
  echo "      both accounts belong to you and your employer/client data policies allow it." >&2
  local files=()
  while IFS= read -r f; do [ -n "$f" ] && files+=("$f"); done < <(
    if [ "$all" = 1 ]; then ls -t "$sp"/*.jsonl 2>/dev/null; else ls -t "$sp"/*.jsonl 2>/dev/null | head -1; fi)
  [ ${#files[@]} -ge 1 ] || die "no session files in $sp"
  [ "$dry" = 1 ] || mkdir -p "$tp"
  for f in "${files[@]}"; do
    n=$((n+1)); local id; id="$(basename "$f" .jsonl)"
    if [ -e "$tp/$id.jsonl" ]; then
      # same session already there: update only if the target is an unchanged older prefix of the source
      if head -c "$(stat -f%z "$tp/$id.jsonl")" "$f" | cmp -s - "$tp/$id.jsonl" && [ "$(stat -f%z "$f")" -gt "$(stat -f%z "$tp/$id.jsonl")" ]; then
        echo "  session $id: newer in '${args[0]}', updating"
      else
        echo "  session $id: '${args[1]}' already has it (same or diverged), skipped"; continue
      fi
    fi
    echo "  session $id: copy ($(du -h "$f" | cut -f1))"
    [ "$dry" = 1 ] || { cp -p "$f" "$tp/$id.jsonl"; [ -d "$sp/$id" ] && cp -Rp "$sp/$id" "$tp/$id"; }
  done
  if [ -d "$sp/memory" ]; then
    echo "  memory: merge (existing files in '${args[1]}' are kept)"
    [ "$dry" = 1 ] || rsync -a --ignore-existing "$sp/memory/" "$tp/memory/"
  fi
  [ "$dry" = 1 ] && echo "(dry run: nothing copied)" || echo "now: cd \"$proj\" && cc-$(short_of "${args[1]}") --resume   (pick the session)"
}

cmd_go() { # go [TO]: hand off this folder's newest session to TO (menu or name prefix) and resume there
  local proj key n d f best="" bestm=0 m src to="" pick i=0 names=() shorts=() dirs=() mode="" asked=0 sh
  case "${1:-}" in -t) mode=t; shift ;; -d) mode=d; shift ;; -b) mode=b; shift ;; esac
  proj="$(pwd -P)"; key="$(printf '%s' "$proj" | sed 's/[^a-zA-Z0-9]/-/g')"
  [ -s "$REGISTRY" ] || die "no accounts yet (run: scan)"
  while IFS=$'\t' read -r n d _; do
    f="$(ls -t "$d/projects/$key"/*.jsonl 2>/dev/null | head -1 || true)"; [ -n "$f" ] || continue
    m="$(stat -f%m "$f")"; if [ "$m" -gt "$bestm" ]; then bestm="$m"; best="$f"; src="$n"; fi
  done < "$REGISTRY"
  [ -n "$best" ] || die "no Claude session found for $proj in any account"
  while IFS=$'\t' read -r n d sh fl; do
    has_flag "${fl:-}" hidden && continue
    [ "$n" = "$src" ] || { names+=("$n"); dirs+=("$d"); shorts+=("${sh:-$n}"); }
  done < "$REGISTRY"
  [ ${#names[@]} -gt 0 ] || die "no other account to hand off to"
  pick="${1:-}"
  if [ -z "$pick" ]; then
    echo "newest session here is in '$src'. Hand off to:"
    for i in "${!names[@]}"; do printf '  %d) cc-%-12s %s\n' "$((i+1))" "${shorts[$i]}" "$(email_of "${dirs[$i]}")"; done
    printf 'number or name: '; read -r pick </dev/tty; asked=1
  fi
  if [[ "$pick" =~ ^[0-9]+$ ]]; then
    [ "$pick" -ge 1 ] && [ "$pick" -le ${#names[@]} ] || die "no such number"
    to="${names[$((pick-1))]}"
  else
    local hits=() want="${pick#cc-}"
    for i in "${!names[@]}"; do
      if [ "${names[$i]}" = "$want" ] || [ "${shorts[$i]}" = "$want" ]; then hits=("${names[$i]}"); break; fi
      if [[ "${names[$i]}" == "$want"* ]] || [[ "${shorts[$i]}" == "$want"* ]]; then hits+=("${names[$i]}"); fi
    done
    [ ${#hits[@]} -eq 1 ] || die "'$pick' matches ${#hits[@]} accounts: ${hits[*]:-none}"
    to="${hits[0]}"
  fi
  if [ -z "$mode" ] && [ "$asked" = 1 ]; then
    printf 'open in: [t]erminal (default), [d]esktop app, [b]oth: '; read -r mode </dev/tty
  fi
  mode="${mode:-t}"
  echo "'$src' -> '$to'"
  cmd_handoff "$src" "$to" "$proj"
  if [ "$mode" = d ] || [ "$mode" = b ]; then
    cmd_desktop "$to"
    echo "opened Claude Desktop for '$to' (the desktop app can't resume this terminal session)"
  fi
  [ "$mode" = d ] || cmd_run "$to" --resume "$(basename "$best" .jsonl)"
}

cmd_remove() { # unregister only; never deletes the directory
  [ $# -ge 1 ] || die "usage: remove NAME"
  dir_of "$1" >/dev/null || die "unknown account '$1'"
  local tmp; tmp="$(mktemp)"
  awk -F'\t' -v n="$1" '$1!=n' "$REGISTRY" > "$tmp" && mv "$tmp" "$REGISTRY"
  echo "unregistered '$1' (its directory and login were left untouched)"
}

cmd_shell_init() { # print shell functions: cc-SHORT (terminal), ccd-SHORT (desktop), cc-list, cch
  cat <<EOF
function cc-list { "$SELF" list; }
function cch { "$SELF" go "\$@"; }
EOF
  local n d sh fl
  [ -s "$REGISTRY" ] || return 0
  while IFS=$'\t' read -r n d sh fl; do
    sh="${sh:-$n}"
    [[ "$n" =~ ^[a-z0-9][a-z0-9_-]*$ ]] && [[ "$sh" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || continue
    has_flag "$fl" hidden && continue
    printf 'function cc-%s { "%s" run %s "$@"; }\n' "$sh" "$SELF" "$n"
    has_flag "$fl" nodesktop || printf 'function ccd-%s { "%s" desktop %s; }\n' "$sh" "$SELF" "$n"
  done < "$REGISTRY"
}

usage() {
  cat <<EOF
cc-accounts — several Claude accounts, one config dir each

  scan                register existing ~/.claude and ~/.claude-* dirs
  add [NAME] [DIR] [--short S]
                      create + register an account; asks for name, short name and desktop launcher
  short NAME SHORT    set the short name: cc-SHORT (terminal) and ccd-SHORT (desktop)
  desktop NAME        open that account's Claude Desktop profile
  desktop-off NAME    drop that account's ccd-SHORT command and app (desktop-on brings it back)
  hide NAME           drop an account's cc-/ccd- commands, apps and cch entry, keep it registered (unhide undoes)
  list                show accounts and who is logged in
  run NAME [args]     start Claude as that account (then /login the first time)
  link NAME [FROM]    share CLAUDE.md, scripts, worktree-ledger from FROM (default: 'default')
  link-all [FROM]     link every other account to FROM
  go [-t|-d|-b] [TO]  in a project folder: pick an account (menu, number or name prefix), hand off and resume
                      -t terminal (default)  -d desktop app only  -b both
  handoff FROM TO [DIR] [--all] [--dry-run]
                      copy a project's latest session + memory to another account, then resume it there
  policy              what is shared vs isolated
  remove NAME         unregister (never deletes the directory)
  shell-init          print shell functions: cc-SHORT, ccd-SHORT per account, cc-list, cch

Setup: run install-shell.sh once (it adds this to ~/.zshrc), then use cc-work, ccd-work, cc-list, cch
  eval "\$($SELF shell-init)"
EOF
}

case "${1:-}" in
  add) shift; cmd_add "$@" ;;
  short) shift; cmd_short "$@" ;;
  desktop) shift; cmd_desktop "$@" ;;
  desktop-off) shift; cmd_desktop_flag off "$@" ;;
  hide) shift; cmd_hide hide "$@" ;;
  unhide) shift; cmd_hide unhide "$@" ;;
  desktop-on) shift; cmd_desktop_flag on "$@" ;;
  scan) cmd_scan ;;
  list|ls) cmd_list ;;
  run) shift; cmd_run "$@" ;;
  link) shift; cmd_link "$@" ;;
  link-all) shift; cmd_link_all "$@" ;;
  handoff) shift; cmd_handoff "$@" ;;
  go) shift; cmd_go "$@" ;;
  policy) cmd_policy ;;
  remove|rm) shift; cmd_remove "$@" ;;
  shell-init) cmd_shell_init ;;
  ""|-h|--help|help) usage ;;
  *) usage; exit 1 ;;
esac
