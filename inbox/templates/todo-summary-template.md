<!--
Format Specification: todo-summary-template
Required frontmatter: title, created, year, tags=[todo-summary, para, automated]
Required sections: header callout, day sections (one per scan day, PARA-categorised), Archive
Producer: scripts/todo-summary.sh --output (cron: 07:00, 12:00, 15:00)
-->
---
title: "TODO Summary — {{YEAR}}"
created: "{{YEAR}}-01-01"
year: {{YEAR}}
tags: [todo-summary, para, automated]
---

# TODO Summary — {{YEAR}}

> Auto-generated yearly TODO scan. Each cron run replaces today's section.
> Unchecked items carry forward from previous days.
> Categorised by PARA: Projects (TODO/FIXME/HACK/XXX), Areas (`- [ ]` tasks), Resources (REVIEW).

---

### {{TODAY}}

#### Projects

- [ ] **Example TODO** (`path/to/file.md:42`) — TODO: refactor parser

#### Areas

- [ ] Example unchecked task — `path/to/note.md:7`

#### Resources

- [ ] **Example REVIEW** (`path/to/doc.md:15`) — REVIEW: evaluate new library

---

## Archive

<!-- User-curated notes survive across scans. Append manually as items roll off. -->
