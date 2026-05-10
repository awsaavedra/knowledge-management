<!--
Format Specification: weekly-template
Required frontmatter: title, created, week_start, week_end, tags=[weekly-tasks, para, automated]
Required sections: header callout, day sections (one per day, PARA-categorised tasks)
Producer: scripts/weekly-tasks.sh --output (cron: 07:00, 12:00, 15:00)
-->
---
title: "Weekly Tasks — {{WEEK_START}} to {{WEEK_END}}"
created: "{{WEEK_START}}"
week_start: "{{WEEK_START}}"
week_end: "{{WEEK_END}}"
tags: [weekly-tasks, para, automated]
---

# Weekly Tasks — {{WEEK_START}} to {{WEEK_END}}

> Auto-generated weekly task file. Each cron run adds/updates the day's section.
> Unchecked items carry forward from the previous day or prior week.
> Check off items as you complete them — they stay as a record.

---

### {{DATE}} {{DAY_NAME}}

#### Projects

- [ ] **Example TODO** (`path/to/file.sh:42`) — TODO: refactor parser

#### Areas

- [ ] **Daily note** (`daily/2026-01-05.md:7`) — Review weekly goals

#### Resources

- [ ] **Example REVIEW** (`path/to/doc.md:15`) — REVIEW: evaluate new library

---
