# Design Notes

Index of `N` (notes) and `B` (bugs/edge cases) codes referenced in `bin/okm` comments.
Each entry records the decision and why it exists, so the code comments stay terse.

## N codes — design decisions

| Code | Decision |
|------|----------|
| N6  | README dual-mode diagram (vault-inside vs vault-outside repo) — deferred to v1 |
| N7  | Log rotation, `sync -m`, `okm version`, decouple cron tests — deferred to v1 |
| N8  | `verify-km.sh` direnv check — deferred to v1 |
| N9  | `okm spot` metadata fetch + URL escape — deferred to v1 |
| N11 | `okm tag` on a file with no frontmatter prepends `---\ntags: []\n---` instead of refusing |
| N13 | YAML double-quoted scalars require backslash-first escaping: `\` → `\\`, then `"` → `\"` |
| N14 | `slugify` fails closed on slugs shorter than 2 chars — prevents creating `-.md` or similar |
| N15 | `okm sync` refuses if any vault symlink resolves outside the vault (leak-prevention) |
| N16 | Spotify IDs are exactly 22 base62 characters — reject anything that doesn't match |
| N17 | `okm tagged` uses exact-match via `grep -xF`, not regex — prevents `tagged source` matching `source/spotify` |
| N18 | Slugs are capped at 200 characters with trailing-hyphen trim |
| N19 | `okm open` validates vault boundary with `realpath -m` (allows non-existent paths for new notes) |
| N20 | `slugify` collapses `\n\r\t` to spaces before slugifying multi-line titles |
| N21 | `first_frontmatter` and `get_tags_line` stop at the second `---`, preventing body `---...---` blocks from being parsed as frontmatter |
| N22 | `grep -qxF -- "$tag"` — `--` prevents tags starting with `-` from being interpreted as flags |
| N23 | `validate_tag` whitelist: `[A-Za-z0-9_./+-]` only — rejects chars that break YAML or shell parsing |
| N26 | `yaml_escape_dq` escapes backslash before double-quote so the two passes don't interfere |
| N27 | `-t` flag validates every tag in the comma-separated list before accepting any of them |
| N28 | `resolve_note` validates vault boundary for existing files (complements N19 for open) |
| N30 | A lone leading `---` is a Markdown horizontal rule, not a frontmatter block — reject rather than silently prepend |
| N31 | `write_tags_line` preserves original file permissions via `stat -c '%a'` + `chmod` after atomic replace |

## B codes — bug/edge-case identifiers

| Code | Edge case |
|------|-----------|
| B2  | `okm tagged source` must NOT match `source/spotify` — exact tag comparison, not prefix/substring |
| B3  | Block-style YAML tags (`tags:\n  - foo`) are read-supported but write operations refuse them (v0); write support is a v1 item |
| B4  | Invalid characters in `-t` flag values (e.g. commas inside a tag, leading `-`) caught by `validate_tag` |

---

## v0 shipped — feature clusters and regression guard

| Cluster | Summary |
|---|---|
| **Tagging** | Boundary regex, injection-safe dedup, frontmatter-less handling, hierarchical tags; block-style YAML read (B3); HR false-positive guard (N30); permission-preserving write (N31) |
| **Privacy** | Vault `.gitignore`; `private/` exclusion; `okm audit`; fork-safety docs |
| **Path safety** | `okm open`/`sync` vault-boundary checks; `list_notes` excludes `.git/` |
| **Input validation** | YAML escaping; slug fail-closed; Spotify ID validation; `validate_tag` on flags |
| **Templates** | Single-source placeholder substitution across all note types |
| **Fuzz gate** | BATS property-test harness (Unicode/quotes/slashes/newlines/empty/long) |
| **Test/CI** | 280+ BATS tests isolated via `FAKE_VAULT_DIR`; CI green on main |

**Regression guard** — don't break these in v1+: 280+ BATS tests via `FAKE_VAULT_DIR` + fake `$HOME` · `scripts/lib/scan.sh` shared library · idempotent `scripts/setup-km.sh`/`okm new/today/spot` · `scripts/verify-km.sh` exit-code discipline · `docs/skills/`/`private/` privacy boundary · minimal correct CI.

---

## Core design principle: friction over prohibition

Safety mechanisms in this project are **speed bumps, not walls**. The goal is to make bad practice inconvenient enough that it doesn't happen by accident, while preserving the user's ability to make deliberate, informed decisions.

Concretely:
- Defaults are safe (private remotes, gitignored notes, `gh` visibility check before push).
- Every guard has an explicit override (`--no-verify`, `KM_FORCE_SYNC=1`, `KM_ALLOW_UPSTREAM_PUSH=1`).
- The override is intentionally awkward — it requires a conscious extra step, not just a confirmation prompt.

The user is always the final authority. One-off exceptions and deliberate bad practice are allowed; the system just ensures they require effort proportional to the risk.

---

## Fork-safety architecture (v1)

Structural goal: accidental pushes to upstream impossible. Two topologies under evaluation.

### Approach A — asymmetric remotes

`origin` → private user repo · `upstream` → public OSS (fetch-only, push URL `DISABLED`) · tracked pre-push guard (`scripts/hooks/pre-push`, activated via `core.hooksPath`) blocks vault content from leaving · `okm sync` refuses if `origin` matches upstream.

**`okm port <handle> [--public] [--no-push]`:** `gh` auth + `okm audit` → create private repo → rename/disable upstream → add new origin → activate guard → push.

*Pro:* minimal delta from v0. *Con:* vault shares git history with app; PRs need throwaway fork.

### Approach B — two-repo split

**B1 (submodule):** private repo contains public app as `app/` submodule; vault in `vault/`.
**B2 (side-by-side):** public repo for code; `OBSIDIAN_VAULT` env var points to separate private vault.

*Pro:* no shared history; clean fork/PR; B2 is near-zero code change. *Con:* must extract vault dirs; `okm sync` semantics change.

**Decision:** A if minimal change acceptable. B2 if structural impossibility preferred. Ship A first, evaluate B after real usage.

### Defense-in-depth (both)

`.gitignore`: `vault/ data/ notes/ personal/ *.pem *.key *.db *.sqlite *.env` · Gitleaks pre-commit hook (`gitleaks v8.18.0`) · GitHub server-side push protection (Settings → Code security).

Full spec + hook content: `tests/v1_spec.bats`.
