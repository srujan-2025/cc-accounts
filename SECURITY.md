# Security policy

## Supported versions

Only the latest release on `main` receives fixes.

## Reporting a vulnerability

Please **do not open a public issue** for security problems. Use GitHub's private vulnerability reporting:
**Security tab > Report a vulnerability** on this repository.

Include what you found, how to reproduce it, and the impact. You should get a first response within a week.

## Scope and what the tool touches

`cc-accounts` runs locally and makes no network requests. It reads and writes:

- `~/.config/cc-accounts/accounts` (the account list)
- `~/.claude*` config folders (symlinks, session copies in `handoff`)
- `~/.zshrc` (only via `install-shell.sh`, with a timestamped backup)
- `~/Applications/Claude Accounts/` (launcher apps it builds)

It never reads credential contents; it only reads the logged-in email field of each account's
`.claude.json` for display. Please report anything that could leak a login, overwrite user data, or run
unexpected commands from a crafted account name, path or registry entry.
