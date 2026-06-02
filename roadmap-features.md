# Roadmap: Connective Tissue Features

> **Thesis:** A fast, composable, Unix-native knowledge layer for engineers who treat notes like code — portable, file-native, and safe by default, with AI as an optional multiplier rather than the core dependency.

---

## Phase 1 — Trust Infrastructure (Foundation)

These features make the vault auditable and safe. No AI required. Ship these first.

### `doctor` — Vault Health Score

A programmatic health report of the vault. Zero LLM cost, pure ripgrep + shell.

**Checks:**
- Broken wikilinks count
- Orphan `raw/` files (no corresponding `wiki/` page)
- `wiki/` pages with no source atoms
- PARA category drift (e.g., items in `Resources/` that should be in `Projects/`)
- Last-modified staleness per PARA category
- Frontmatter schema violations

**Output:** Structured report to stdout, exit code non-zero if violations exist. Composable with CI.

---

### `--dry-run` — Non-Destructive Contract Made Actionable

Every command that writes to the vault supports `--dry-run`.

**Behavior:**
- Emits a structured diff to stdout before any write
- No files touched
- Agents can call dry-run first, surface diff to human, then commit after confirmation
- Operationalizes "safe by default" as a runtime guarantee, not just a design principle

---

### `eject-check` — Portability Audit

Scans the vault and reports everything that breaks outside Obsidian.

**Flags:**
- Obsidian-specific syntax (`![[embed]]`, dataview queries, callout blocks)
- Plugin-dependent frontmatter fields
- Absolute internal links that won't resolve in Vim/Neovim
- Notes with `## For future Claude`-style AI-coupled preambles

**Output:** Markdown report of portability debt with suggested fixes. Pure shell, no AI.

---

### Frontmatter Schema Enforcement via `vault.schema.yaml`

A lightweight schema file at vault root defining required/optional frontmatter per PARA category.

**Example schema:**
```yaml
projects:
  required: [status, outcome]
  optional: [due, stakeholders]
areas:
  required: [cadence]
  optional: [health-metric]
resources:
  required: [source, type]
  optional: [tags]
```

**Behavior:**
- CLI enforces schema on every write
- `doctor` surfaces all violations
- Agents writing to the vault automatically produce compliant notes
- Human-auditable contract: if a page has `status: active`, it will always have `outcome`

---

## Phase 2 — Agent Legibility

These features make the vault a **legible, machine-auditable surface** that agents can reason about without owning it.

### `context` — Stable Context API for Agents

A command that returns a deterministic, token-scoped context bundle for a given query or PARA path.

**Input:** query string or PARA path  
**Output:** Structured markdown bundle containing:
- Relevant `wiki/` pages
- Their source atoms (with frontmatter)
- Freshness timestamps
- PARA location

**Why:** Without this, agents get the whole vault (too much) or a manually curated prompt (too fragile). This is the connective tissue — any agent (Claude, Copilot, Cursor) receives it as a file or stdin.

---

### `AGENT_LOG.md` — Agent Action Log as First-Class File

Every agent action that touches the vault appends a structured entry to `AGENT_LOG.md` at vault root.

**Entry format:**
```markdown
## 2026-06-01T18:22:00Z
- **Agent:** Claude Code
- **Command:** wiki-update resources/investments
- **Files changed:** wiki/resources/investments/index.md
- **Diff summary:** Added section on portfolio rebalancing from raw/2026-05-30-research.md
```

**Why:** Same UX as `git log`. You review what agents did without needing to audit every file. Closes the trust gap between human review and agent autonomy.

---

### AGENTS.md as Runtime Governance (not just README)

Parse `AGENTS.md` at runtime and enforce its constraints as hard rules.

**Enforced rules (examples):**
- `raw/` is immutable — no agent writes permitted
- `wiki/projects/` pages must have `status:` frontmatter
- Synthesis pages go to `wiki/synthesis/` pending human promotion
- All agent writes require a corresponding `AGENT_LOG.md` entry

**Why:** Turns AGENTS.md from documentation into a contract layer. Any agent using your tool inherits the rules automatically.

---

## Phase 3 — Synthesis Layer (Human-Reviewed, Not Autonomous)

These features add synthesis depth without breaking the non-destructive contract. Every output goes to a review file before it touches the live vault.

### Atom Layer (`raw/` → `atoms/` → `wiki/`)

An intermediate layer between `raw/` and `wiki/`. One atom = one claim, one file.

**Atom frontmatter:**
```yaml
source: raw/2026-05-30-research.md
type: insight          # insight | fact | contradiction | question
depth: 2               # 1-3 scale
tags: [investments, rebalancing]
date: 2026-05-30
```

**Why:** When you compile `raw/` → `wiki/` in one step, you lose granular source of truth. Atoms are the source of truth; `wiki/` is a derived cache. Atoms are plain markdown, human-readable in Vim, non-destructively generated.

---

### Two-Layer Lint

Split linting into two layers with different cost profiles:

**Layer 1 — Programmatic (always on, milliseconds):**
- Ghost wikilinks
- Orphan pages
- Format violations
- Frontmatter schema mismatches
- Broken atom → wiki references

**Layer 2 — LLM (on-demand, explicit command):**
- Contradictions between wiki pages
- Expired claims (date-sensitive facts)
- Semantic drift (page has drifted from its source atoms)

**Why:** Never pay LLM cost for things grep can catch.

---

### `emerge` — On-Demand Pattern Surfacing

Surfaces patterns across notes the user never named. Runs explicitly, not on a schedule.

**Behavior:**
- Reads from `wiki/` only (never touches `raw/` or `atoms/`)
- Writes candidate synthesis pages to `wiki/synthesis/` subdirectory
- Human reviews and promotes (or deletes) — never auto-merged
- Outputs a summary of what it found and why to stdout

**Why:** Delivers the "what are you missing" capability from tools like `obsidian-second-brain`, but preserves the non-destructive contract. You confirm before anything enters the live vault.

---

### `link-suggest` — Semantic Link Suggestions (Human-Curated)

After a wiki page is written or updated, scans the vault for pages that *should* be wikilinked but aren't.

**Based on:**
- Term overlap
- PARA proximity
- Shared source atoms

**Output:** Suggested `[[proposed-link]]` candidates written to a `wiki/pending-links.md` review file. Human confirms or rejects. Never auto-inserted.

**Why:** Keeps link graphs meaningful and human-curated without requiring the human to do discovery work manually.

---

## Feature Priority Matrix

| Feature | Phase | AI Required | Thesis Alignment | Effort |
|---|---|---|---|---|
| `doctor` vault health | 1 | ❌ | ✅ Trust, observability | Low |
| `--dry-run` on all writes | 1 | ❌ | ✅ Non-destructive | Low |
| `eject-check` portability audit | 1 | ❌ | ✅ Portability | Low |
| Frontmatter schema enforcement | 1 | ❌ | ✅ Trust, composability | Low |
| `context` agent API | 2 | ❌ | ✅ Connective tissue | Medium |
| `AGENT_LOG.md` | 2 | ❌ | ✅ Observability, trust | Low |
| AGENTS.md runtime governance | 2 | ❌ | ✅ Contract layer | Medium |
| Atom layer | 3 | Optional | ✅ Source of truth | Medium |
| Two-layer lint | 3 | Optional | ✅ Trust, cost control | Medium |
| `emerge` pattern surfacing | 3 | ✅ (on-demand) | ✅ Synthesis, human-first | Medium |
| `link-suggest` | 3 | Optional | ✅ Human-curated graph | Medium |

---

## Core Principle

> Every feature must make the vault more **legible** — to both humans and agents — without making it more fragile. The vault is a shared workspace with contracts, not just a folder of files.
