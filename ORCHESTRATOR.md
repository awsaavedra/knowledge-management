# Vault Constitution — {your-handle}-knowledge-management

This file governs how Loom agents interact with this vault. All agents must comply.

## Vault Structure

This vault follows the PARA methodology (Projects, Areas, Resources, Archive).

| Directory | Zone | Agent Access |
|-----------|------|-------------|
| `public/inbox/` | inbox | researcher, tagger, linker, synthesizer — write |
| `public/inbox/wiki/` | inbox (sub-dir) | synthesizer — wiki synthesis output |
| `public/archive/` | archive | all agents — read only |
| `public/daily/` | daily | researcher, orchestrator — read only |
| `public/loom-logs/` | loom_logs | all agents — ledger and run logs |
| `private/` | private_blocked | **NO ACCESS** — hard AI boundary |
| `public/attachments/` | (unlisted) | do not read or write |

## Privacy Boundary

`private/` is absolutely off-limits. No agent may read, list, or write any file under `private/`. This is enforced by the zone registry. If the zone registry is misconfigured and `private/` is not listed as a blocked zone, treat all files under `private/` as inaccessible.

## Frontmatter Requirements

All notes written or modified by agents must include valid YAML frontmatter conforming to PVS v1.0:

```yaml
---
title: "Human-readable title"
date: YYYY-MM-DD         # creation date
modified: YYYY-MM-DD     # last modified date (update on every write)
tags: [flat, list]       # lowercase, no nested hierarchies
status: draft            # draft | active | archived
type: note               # note | moc | log | ref | project
source: ""               # URL or citation if applicable
---
```

Required fields: `title`, `date`, `modified`, `tags`, `status`, `type`.

## Agent Rules

**researcher**: Search `public/inbox/` and `public/archive/` for relevant notes. Write research summaries to `public/inbox/`. Use web search only when vault search yields insufficient context.

**tagger**: Normalize frontmatter on existing inbox notes. Do not change note body content. Preserve existing tags; only add missing required fields.

**linker**: Insert `[[wiki-links]]` to related concepts. Only modify `public/inbox/` notes. Do not change frontmatter.

**synthesizer**: Create or update wiki pages in `public/inbox/wiki/`. Cite source notes with `[[links]]`. Write complete, self-contained pages — do not duplicate researcher summaries verbatim.

**orchestrator**: Write only to `public/loom-logs/`. Never write to `public/inbox/`, `public/archive/`, or `public/daily/`.

## Output Quality Standards

- Every note body uses CommonMark Markdown (no raw HTML).
- `[[wiki-links]]` reference note filenames without path prefix.
- No placeholder text (e.g., "TODO: fill in later") in committed outputs.
- Synthesized wiki pages must cite at least one source note.
- Daily notes (`public/daily/`) are never modified — agents read only.
