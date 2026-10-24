# cc-accounts

[![CI](https://github.com/srujan-2025/cc-accounts/actions/workflows/ci.yml/badge.svg)](https://github.com/srujan-2025/cc-accounts/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Run **Claude Code** (terminal) and **Claude Desktop** under several accounts on one Mac, and hand a
project's session from one of your accounts to another.

> **Unofficial.** This is an independent community tool. It is not affiliated with, endorsed by, or
> supported by Anthropic. "Claude" and "Claude Code" are trademarks of Anthropic, PBC.

Each account gets its own config folder (`~/.claude-NAME`), selected with the `CLAUDE_CONFIG_DIR`
environment variable that Claude Code supports. Nothing here modifies the Claude install itself.

## Features

- Short, readable commands per account: `cc-work`, `cc-personal`, `ccd-work` (desktop)
- A clear split between what accounts **share** (global `CLAUDE.md`, scripts) and what stays **isolated** (login, history, memory, plugins)
- `cch`: carry a project's latest session and memory to another account and resume it there
- Double-clickable `.app` launchers with a distinct icon per account (terminal-style icon for CLI, Claude-logo icon for Desktop)
- Prompts for names when you add an account; every prompt also has a flag, so it scripts cleanly
- Nothing is ever deleted: linking backs up files first, `remove` only unregisters

## Responsible use

- Use only accounts that **you own or are authorized to use**.
- Follow Anthropic's [terms and usage policies](https://www.anthropic.com/legal). This tool is for keeping
  separate identities apart (for example work and personal). It is **not** meant to get around usage
  limits or to share one account between people.
- `cch` / `handoff` copy conversation transcripts and memory between accounts. Don't use it across
  accounts when your employer's or a client's data policy forbids moving that content.

## Requirements

macOS, the `claude` CLI, `bash`, `jq`, `rsync`. Optional: `python3` with Pillow (`pip3 install pillow`) and
`/Applications/Claude.app`, only for the app launchers.

## Install

```
git clone https://github.com/srujan-2025/cc-accounts.git
cd cc-accounts
./cc-accounts.sh scan        # registers ~/.claude and any ~/.claude-NAME folders, asks for short names
./install-shell.sh           # adds one line to ~/.zshrc (backs it up first)
source ~/.zshrc
```

## Quick start

```
./cc-accounts.sh add         # asks: account name, short name, desktop launcher?
cc-work                      # start Claude Code as that account, then /login (once per account)
cc-list                      # accounts, short names, logged-in emails
./cc-accounts.sh link-all    # share CLAUDE.md, scripts/, worktree-ledger.md from the default account
python3 make-launchers.py    # optional: build ~/Applications/Claude Accounts/*.app
```

Or without prompts: `./cc-accounts.sh add client-a --short ca`.

## Commands

| You type | What happens |
|---|---|
| `cc-SHORT [args]` | Claude Code (terminal) as that account, e.g. `cc-work -c` |
| `ccd-SHORT` | Claude Desktop for that account (its own profile) |
| `cc-list` | List accounts and who is logged in |
| `cch [-t\|-d\|-b] [SHORT]` | Hand this folder's newest session to another account (menu, number, or name prefix) |
| `claude` | Your default account, unchanged |

`cc` is deliberately **not** defined: it is the C compiler.

<details>
<summary>All <code>cc-accounts.sh</code> subcommands</summary>

```
scan                                  register existing ~/.claude and ~/.claude-* folders
add [NAME] [DIR] [--short S]          create and register an account (asks for what is missing)
short [NAME [SHORT]]                  set the short name used by cc-SHORT / ccd-SHORT
list                                  accounts, short names, logged-in emails
run NAME [args]                       start Claude as NAME
desktop NAME                          open that account's Claude Desktop profile
desktop-off NAME | desktop-on NAME    drop / restore that account's ccd-SHORT command and app
hide NAME | unhide NAME               drop / restore all cc-/ccd- commands and apps, keep it registered
link NAME [FROM]                      share CLAUDE.md, scripts, worktree-ledger from FROM (default: 'default')
link-all [FROM]                       same for every other account
handoff FROM TO [DIR] [--all] [--dry-run]   copy a project's latest session + memory to another account
go [-t|-d|-b] [TO]                    what cch runs
policy                                what is shared vs isolated
remove NAME                           unregister (never deletes the folder)
shell-init                            print the shell functions
```
</details>

## Switching accounts mid-project: `cch`

Run it inside the project folder, in a normal terminal, after the old session has finished:

```
cd ~/path/to/project
cch            # menu: pick a number or type part of a name
cch work       # name prefix; an ambiguous prefix lists the matches
cch -d work    # open Claude Desktop for that account instead
```

It finds the account with the newest session for this folder, copies that session and the project's
memory to the target account (the original is never touched), then runs `--resume` there. Claude Desktop
cannot resume a terminal session; it only opens that account's own profile. Commit and push before you
switch so the next account sees the code as well as the conversation.

## What is shared and what is isolated

`./cc-accounts.sh policy` prints this.

- **Shared (symlinked from the default account):** `CLAUDE.md`, `scripts/`, `worktree-ledger.md`
- **Isolated, never linked:** the login (`.claude.json`); history and memory (`projects/`, `history.jsonl`,
  `sessions/`, `file-history/`); `settings.json`; `plugins/` and `skills/`

History and memory stay separate on purpose: two sessions writing one history file can corrupt it, and
accounts should not leak into each other. Use `cch` to move one session deliberately.

## Files

| File | Purpose |
|---|---|
| `cc-accounts.sh` | The CLI |
| `install-shell.sh` | One-time `~/.zshrc` setup (backs up first, removes aliases that collide) |
| `make-launchers.py` | Builds the `.app` launchers and icons |
| `tests/smoke.sh` | Smoke tests; run against a throwaway `HOME` |

The account list lives in `~/.config/cc-accounts/accounts` (tab-separated: name, folder, short name, flags).

## Troubleshooting

- **`parse error near ()` when sourcing `~/.zshrc`:** an old `alias cc-NAME=...` collides with a function of
  the same name. `./install-shell.sh` removes colliding aliases.
- **`cch` says no session found:** run it from the project root; sessions match the exact folder.
- **"not logged in":** run `cc-SHORT`, then `/login`.
- **Desktop launcher opens a second window:** it uses `open -n`, so each click starts a new instance. Each
  Desktop profile also keeps its own VM image (about 10 GB) once agent features are used.
- **`ANTHROPIC_API_KEY` is set:** it can override the account login. `run` warns when it is set.

## Undo / uninstall

- Shell setup: restore the `~/.zshrc.bak-<time>` that `install-shell.sh` printed.
- `link` moves a non-empty file to `~/.claude-NAME/backups/pre-link-<time>/` before replacing it.
- `remove NAME` only unregisters; folders and logins stay.
- Launchers: delete `~/Applications/Claude Accounts/`.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Please read the [Code of Conduct](CODE_OF_CONDUCT.md). Report
security issues privately as described in [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE)
