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

# Write summary to inbox/todo-summary-YYYY.md (yearly living doc)
bash scripts/todo-summary.sh --output
```

### Directories scanned

1. Project root (this repo)
2. `$OBSIDIAN_VAULT` (vault, if it exists)

### Scheduled runs

The script runs three times daily at **07:00**, **12:00**, and **15:00**.

**Claude Code cron (session-scoped, auto-expires after 7 days):**

Set up at the start of each Claude Code session with:
```
CronCreate: "3 7 * * *"  — PARA TODO scan, 07:00 daily
CronCreate: "3 12 * * *" — PARA TODO scan, 12:00 daily
CronCreate: "3 15 * * *" — PARA TODO scan, 15:00 daily
```

**System crontab (persistent across reboots):**

```bash
# Add with: crontab -e (replace $KM with your project path)
3 7 * * * /usr/bin/bash $KM/scripts/todo-summary.sh --output
3 12 * * * /usr/bin/bash $KM/scripts/todo-summary.sh --output
3 15 * * * /usr/bin/bash $KM/scripts/todo-summary.sh --output
```

### Output

Each year gets a single file `inbox/todo-summary-YYYY.md`. Each cron run prepends a timestamped scan section (newest at top). Checked-off items stay as accomplishment records. The file uses PARA structure:

```
## Projects    — TODO/FIXME/HACK/XXX markers
## Areas       — Unchecked markdown tasks (- [ ])
## Resources   — REVIEW markers
## Archive     — Manual section for completed items
```

---

## compress-images.py

Converts PNG, JPG, JPEG, and static GIF images in `attachments/` to WebP. Updates `![[wikilinks]]` in vault notes so Obsidian embeds don't break. Animated GIFs are skipped.

### Usage

```bash
# Convert all images in attachments/
python3 scripts/compress-images.py

# Preview what would change (no writes)
python3 scripts/compress-images.py --dry-run

# Convert but keep original files alongside .webp
python3 scripts/compress-images.py --keep
```

### Scheduled run

Runs daily at **17:00** to compress screenshots and images captured during the day.

**System crontab (persistent):**

```bash
# Add with: crontab -e (replace $KM with your project path)
0 17 * * * $KM/venv/bin/python $KM/scripts/compress-images.py
```

### Dependencies

- Pillow (installed in project venv by `setup-kms.sh`)
- `OBSIDIAN_VAULT` env var (or defaults to sibling `../knowledge-management-system`)
