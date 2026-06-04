# Contributing

Thanks for your interest. This is a small offline-first vault tool, so contributions are scoped tight: bug fixes, portability fixes, and the items listed under **Roadmap → In progress** in `README.md`. Items under **Roadmap → Deferred** are explicit non-goals — please open a discussion before working on those.

## Getting set up

```bash
git clone --recurse-submodules https://github.com/{your-handle}/knowledge-management.git
cd knowledge-management

bash scripts/setup-km.sh   # idempotent — installs deps and Python venv
source env.sh               # activate project environment
bash scripts/verify-km.sh  # confirm install
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
- Don't commit notes — `.gitignore` excludes vault notes under `public/` and `private/` (templates excepted), and a pre-push guard blocks any vault content from reaching the `knowledge-management` repo (see below).

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

## Contributing features from a personal fork

Forking for personal vault use creates tension with contributing back — your fork holds private notes, but PRs should only carry code changes.

| Approach | How it works | Trade-offs |
|---|---|---|
| **A — Contribution fork** | Create a second, code-only fork at `{handle}-km-contrib`. Clone it without vault data. Push feature branches there; PR to upstream. | Clean separation. Requires managing two forks. |
| **B — Throwaway branch** | In your personal fork, create a feature branch from upstream's `main` (no vault commits in history). Push it to a `contrib/` remote pointing at upstream. | One repo, but branch discipline required. |
| **C — `okm port` topology** (v1) | After `okm port`, `origin` = private vault fork, `upstream` = public OSS. Feature branches go to a third throwaway fork and PR to `upstream/main`. | Cleanest long-term; requires `okm port` to ship first. |
| **D — Codespace / devcontainer** | Contribute inside a GitHub Codespace that clones the public repo with no vault. `$OBSIDIAN_VAULT` points to an empty test vault. | No vault data ever leaves the machine. |

**Recommended workflow (today):**

```bash
git fetch upstream
git checkout -b feature/foo upstream/main
bash tests/run_all.sh
git remote add contrib git@github.com:{handle}-km-contrib/knowledge-management.git
git push contrib feature/foo
# PR: contrib/feature/foo → upstream/main
```

**Invariant:** no vault content — anything under `public/` or `private/` except inbox templates and `.gitkeep` placeholders — may appear in any commit pushed to the `knowledge-management` repo. This covers notes *and* attachments.

**How it's enforced.** A tracked pre-push hook (`scripts/hooks/pre-push`, activated by `scripts/setup-km.sh` via `core.hooksPath`) blocks any push of vault content to the `knowledge-management` repo. The rule is deterministic and offline: it keys on the destination repository *name* — `knowledge-management` is the public tool, `{handle}-knowledge-management` is your private vault. Run `okm audit --code-only` for the same check on demand. Both share one predicate, `km_path_is_vault_content` in `scripts/lib/privacy.sh`.

**Caveat — guardrail, not a hard wall.** The hook protects clones that have run `setup-km.sh`, and `git push --no-verify` bypasses it. There is no server-side CI enforcement, so still eyeball your PR's file list before opening it.
