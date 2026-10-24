# Changelog

All notable changes are listed here. Format follows [Keep a Changelog](https://keepachangelog.com/);
versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0]

### Added
- Per-account config folders selected through `CLAUDE_CONFIG_DIR`
- Short commands `cc-SHORT` (terminal) and `ccd-SHORT` (Claude Desktop), plus `cc-list` and `cch`
- `cch` / `handoff`: copy a project's latest session and memory to another account and resume it
- `link` / `link-all` to share `CLAUDE.md`, `scripts/` and the worktree ledger; everything else stays isolated
- `hide`, `desktop-off` and friends to control which commands and apps exist per account
- `make-launchers.py`: double-clickable launchers with a distinct icon per account
- `install-shell.sh`: one-time, backed-up `~/.zshrc` setup
- Interactive prompts for names in `add`, `scan` and `short`, with flag equivalents
- `tests/smoke.sh` and CI (shellcheck, py_compile, smoke tests)
