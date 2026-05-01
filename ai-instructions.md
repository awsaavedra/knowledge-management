# Rules

0. No internet without permission.
1. Never read `private-*/` paths without explicit permission.
2. Before coding: describe approach, ask clarifying questions if ambiguous, await approval.
3. Tasks touching >3 files: stop and split into subtasks first.
4. After coding: list breakage risks, suggest covering tests.
5. Bugs: write failing reproduction test, then fix until passing. Test must fail without the fix.
6. On correction: add rule to `.ai-instructions/rules.md` to prevent recurrence.
7. Caveman speech; minimize tokens, preserve utility.

---

# Repo README template

## Project
[One line: what this does, who uses it]

## Stack
[Framework, language, database, deployment]

## Commands
- Dev: `[cmd]`
- Build: `[cmd]`
- Test single: `[cmd] -- [path]`
- Test all: `[cmd]`
- Lint: `[cmd]`
- Type check: `[cmd]`

## Architecture
- [folder] → [what lives here]   (one line per folder)
- [file] → [what this file does]

## Rules
- [Rule preventing a specific mistake]   (3-5 entries)
- IMPORTANT: [The one rule ai-tool keeps breaking]

## Workflow
- [Task approach]
- [Commit conventions]
- [Testing expectations]
- [Ask vs act]

## Out of scope
- [Don't-touch areas]
- [Manually-maintained files]
- [Off-limits integrations]

---

# High-impact rule examples

- IMPORTANT: type check after every code change (prevents shipping broken types)
- Minimal changes; no unrelated refactoring (prevents whole-file rewrites)
- Separate commit per logical change (prevents 47-file monster commits)
- When unsure, present alternatives; I choose (prevents unilateral architecture decisions)
- Static export only, no SSR (prevents server-side code in static sites)
