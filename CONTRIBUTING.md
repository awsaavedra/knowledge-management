# Contributing

Thanks for your interest. This is a small offline-first vault tool, so contributions are scoped tight: bug fixes, portability fixes, and the items listed under **Roadmap → In progress** in `README.md`. Items under **Roadmap → Deferred** are explicit non-goals — please open a discussion before working on those.

## Getting set up

```bash
git clone --recurse-submodules https://github.com/awsaavedra/knowledge-management.git
cd knowledge-management

bash setup-km.sh        # idempotent — installs deps and Python venv
source env.sh            # activate project environment
bash verify-km.sh       # confirm install
```

`tests/lib/` contains BATS submodules. If you cloned without `--recurse-submodules`, run `git submodule update --init --recursive` before running the test suite.

## Running tests

```bash
bash tests/run_all.sh                          # full BATS suite
bash tests/run_all.sh tests/okm_cli.bats       # one file
bash tests/run_all.sh --filter "okm today"     # filter by name
bash tests/run_all.sh --tap                    # CI-style output
```

Tests stub `EDITOR=true` and use a temporary `OBSIDIAN_VAULT`, so they don't touch your real vault.

## Pull requests

- Keep changes scoped — one logical change per PR.
- If you add or rename an `okm` subcommand, update the table in `README.md`.
- If you add a new env var, document it in the `env.sh` table in `README.md`.
- Add or update a `.bats` test for any behavioural change. CI (`.github/workflows/test.yml`) runs the full suite on every PR.
- Don't commit notes — `.gitignore` excludes `inbox/*.md` (templates excepted), `daily/*.md`, and `archive/*.md` for a reason.

## Reporting issues

Open a GitHub issue with:

- OS and version (Linux distro + apt-or-Flatpak details, or macOS + arch).
- The `okm` subcommand or script involved.
- For setup problems, the relevant lines from `~/.local/log/setup-km-*.log` (scrub paths if needed).
- Reproduction steps and what you expected vs. got.

## Style

- Bash: `set -euo pipefail`, quote variables, prefer `[[ ]]` over `[ ]`. Match the style of `bin/okm` and the existing scripts.
- Markdown: short sentences, tables for structured data, no filler.
- No new external runtime dependencies without discussion — offline-first is a hard constraint.
