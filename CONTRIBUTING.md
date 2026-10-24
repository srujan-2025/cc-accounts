# Contributing

Thanks for helping. This is a small shell + Python tool; keep changes small and focused.

## Ground rules

- Open an issue first for anything larger than a bug fix or doc tweak.
- Never include real account names, emails, customer or employer names, or paths from your own machine in
  code, docs, tests, issues or screenshots. Use generic names (`work`, `personal`, `client-a`).
- The tool must stay non-destructive: back up before replacing, never delete a user's config folder or login.

## Development

Requirements: macOS, `bash`, `jq`, `rsync`, [`shellcheck`](https://www.shellcheck.net/), `python3`.

```
shellcheck -S warning cc-accounts.sh install-shell.sh tests/smoke.sh
python3 -m py_compile make-launchers.py
bash tests/smoke.sh        # runs against a throwaway HOME, touches no real accounts
```

All three run in CI on every pull request.

## Pull requests

1. Fork, then branch from `main` (`fix/...`, `feat/...`, `docs/...`).
2. Add or update a check in `tests/smoke.sh` for behavior you change.
3. Update `README.md` and `CHANGELOG.md` when behavior or commands change.
4. Keep commits focused and the PR description short: what changed and why.

By contributing you agree your work is released under the project's [MIT license](LICENSE).
