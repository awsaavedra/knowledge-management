# Scripts

## todo-summary.sh

PARA-structured scanner that finds open work items across the project and vault.

### What it scans

| Marker | PARA bucket | Meaning |
|---|---|---|
| `TODO:` `FIXME:` `HACK:` `XXX:` | **Projects** | Active work with a clear end goal |
| `- [ ]` (unchecked markdown tasks) | **Areas** | Ongoing responsibilities |
| `REVIEW:` | **Resources** | Items to evaluate or learn from |
| _(manual)_ | **Archive** | Completed items — move here during review |

Scans file types: `.md`, `.sh`, `.lua`, `.yml`, `.json`

### Usage

```bash
# Print summary to stdout
bash scripts/todo-summary.sh

# Write summary to inbox/todo-summary-YYYY-MM-DD.md
bash scripts/todo-summary.sh --output
```

### Directories scanned

1. `/home/aws/workspace/knowledge-management` (this project)
2. `$OBSIDIAN_VAULT` or `/home/aws/workspace/knowledge-management-system` (vault, if it exists)

### Scheduled runs

The script runs twice daily at **07:00** and **12:00**.

**Claude Code cron (session-scoped, auto-expires after 7 days):**

Set up at the start of each Claude Code session with:
```
CronCreate: "3 7 * * *"  — PARA TODO scan, 07:00 daily
CronCreate: "3 12 * * *" — PARA TODO scan, 12:00 daily
```

**System crontab (persistent across reboots):**

```bash
# Add with: crontab -e
3 7 * * * /usr/bin/bash /home/aws/workspace/knowledge-management/scripts/todo-summary.sh --output
3 12 * * * /usr/bin/bash /home/aws/workspace/knowledge-management/scripts/todo-summary.sh --output
```

### Output

Each run writes `inbox/todo-summary-YYYY-MM-DD.md` (overwrites same-day file). The file uses PARA structure:

```
## Projects    — TODO/FIXME/HACK/XXX markers
## Areas       — Unchecked markdown tasks (- [ ])
## Resources   — REVIEW markers
## Archive     — Manual section for completed items
```
