# okm Test Plan

Manual verification plan for the media/capture commands, complementing the
automated BATS suite in `tests/`. Run the automated suite first:

```bash
bash tests/run_all.sh              # full suite (expect: all pass, a few env-gated skips)
bash tests/run_all.sh tests/okm_cli.bats tests/pod_distill.bats   # media commands only
```

> **Naming note:** there is no `okm weekly` command. The **weekly note** is
> produced by `okm today` (see §1). The media commands are `okm pod <link|file>`
> (§2) and `okm video <link|file>` (§3).

## Design invariants (must hold for every case below)

1. **We pull, we do not transcribe.** A transcript appears only when the source
   already publishes one (podcast RSS `<podcast:transcript>` or YouTube
   captions). okm never runs ASR/whisperX. No published transcript → scaffold.
2. **Filename convention:** `{format}-{Channel}-{Title}[-{episode}]-{YYYY-MM-DD}.md`
   - `format` = `podcast` (okm pod) or `video` (okm video)
   - fields are PascalCase; `episode` (digits) and `Channel` are omitted when unknown
   - date is the ISO publish date, last, so notes sort chronologically
3. **Never hard-fail.** Network/resolution failure → offline scaffold + a stderr
   note, not an error exit.

## Test hooks (keep manual runs hermetic / reproducible)

| Env var | Effect |
|---|---|
| `OKM_POD_OFFLINE=1` | `okm pod` skips all network → forces the offline-scaffold path |
| `OKM_POD_FEED_FILE=<path>` | `okm pod` parses this local RSS file instead of fetching one |
| `OKM_POD_EPISODE_MATCH=<substr>` | select the feed item whose title contains `<substr>` (default: newest) |
| `OKM_POD_TRANSCRIPT_FILE=<path>` | use a local file as the transcript instead of fetching the URL |
| `EDITOR=true` | stop the note opening in an editor after creation |
| `OBSIDIAN_VAULT=<dir>` | run against a throwaway vault |

Common preamble for manual runs:

```bash
export OBSIDIAN_VAULT="$(mktemp -d)" EDITOR=true KM_TRACK_NOTES=false
mkdir -p "$OBSIDIAN_VAULT/public/inbox" "$OBSIDIAN_VAULT/public/daily"
```

---

## §1. `okm today` — weekly note

| # | Steps | Expected |
|---|---|---|
| 1.1 | `okm today` in a fresh vault | Creates `public/daily/YYYY-MM-DD-weekly.md` where the date is **Monday** of the current week (Mon–Sun); opens it |
| 1.2 | Run `okm today` again same week | `Exists:` — same file, not overwritten |
| 1.3 | Leave an unchecked `- [ ]` task in last week's weekly note, then `okm today` in a later week | The unfinished `- [ ]` task is **carried forward** into the new week's note, deduplicated; checked `- [x]` tasks are not |
| 1.4 | `okm today -t focus` | Note created with `focus` merged into `tags` |
| 1.5 | `okm private today` | Same behaviour under `private/daily/` |

Automated coverage: `tests/okm_cli.bats` (today), `tests/weekly_tasks.bats`.

---

## §2. `okm pod <link|file>` — podcast capture

`okm pod` resolves a link to the show's RSS feed, extracts channel / title /
`itunes:episode` / `pubDate`, and embeds a transcript **only** when the feed has
`<podcast:transcript>`.

### 2a. Link resolution (live network)

| # | Input | Expected |
|---|---|---|
| 2.1 | Spotify episode URL (`https://open.spotify.com/episode/<id>?...`) | Resolves via Spotify embed → iTunes Search → feed; filename `podcast-{Show}-{Title}[-{ep}]-{date}.md`; `source_platform: spotify` |
| 2.2 | Apple Podcasts URL (`https://podcasts.apple.com/.../id123?i=456`) | Resolves via iTunes lookup; `source_platform: apple` |
| 2.3 | Direct RSS/`.xml` feed URL | Uses the feed directly; newest episode selected; `source_platform: rss` |
| 2.4 | Generic episode webpage (e.g. Simplecast) | RSS auto-discovered from the page `<link rel=alternate>` |
| 2.5 | An episode whose feed **has** `<podcast:transcript>` | `## Transcript` filled with `[MM:SS] …` lines |
| 2.6 | An episode whose feed has **no** transcript (e.g. Danielle Newnham Pod ep. 99) | Scaffold note; Transcript section explains none was published; `audio_url` still recorded in frontmatter |

Golden case (2.6 target filename):
`podcast-DanielleNewnhamPodcast-RivaTezOnGeniusManiaAndTheImpactOfCancelCulture-99-2024-01-01.md`

### 2b. Hermetic / offline (no network needed)

| # | Steps | Expected |
|---|---|---|
| 2.7 | Build a fixture feed with one `<item>` + a local `.vtt` in `<podcast:transcript>`, then `OKM_POD_FEED_FILE=feed.xml okm pod <any-url>` | PascalCase filename from feed metadata; transcript embedded as `[MM:SS]` lines |
| 2.8 | `OKM_POD_OFFLINE=1 okm pod <spotify-url>` | Exit 0; deterministic `podcast-Podcast<id>-<today>.md` scaffold; stderr warns metadata couldn't be fetched |
| 2.9 | `okm pod <local.srt> "My Talk"` | Imports the SRT verbatim as `[MM:SS]` lines into `podcast-MyTalk-<today>.md` |
| 2.10 | `okm pod <local.mp3>` | Metadata scaffold only (no ASR); Transcript note says okm does not transcribe |
| 2.11 | `okm pod "not-a-link"` | Fails: `Not a link or a readable file` |
| 2.12 | `okm pod` (no arg) | Fails: `Podcast link or file required` |
| 2.13 | `okm pod <url> -t favorite` (offline) | `tags: [source/podcast, favorite]` |
| 2.14 | Re-run any successful case | `Exists:` — idempotent, no overwrite |

Transcript formats to spot-check in 2.7 (all should render as `[MM:SS] text`):
VTT, SRT (incl. `HH:MM:SS`), Podcast Index JSON (`segments[].startTime/body`).

Automated coverage: `tests/okm_cli.bats` (okm pod §), `tests/pod_distill.bats`,
`tests/tagging.bats`, `tests/fuzz.bats`, `tests/v1_spec.bats` (N9/F2).

---

## §3. `okm video <link|file>` — video / lecture capture

`okm video` pulls YouTube metadata via `yt-dlp` and captions via
`youtube-transcript-api` (install into the venv: `pip install youtube-transcript-api`).

| # | Input | Expected |
|---|---|---|
| 3.1 | YouTube watch/`youtu.be`/`shorts` URL | `video-{Channel}-{Title}-{date}.md`; `source_type: video`, `source_platform: youtube`, canonical `source_url`, `video_id` |
| 3.2 | Video whose channel publishes **captions** | `## Transcript` filled with `[MM:SS] …` lines |
| 3.3 | Video with **no** captions (or `youtube-transcript-api` not installed) | Scaffold; Transcript note says okm does not transcribe |
| 3.4 | Offline / `yt-dlp` absent | Falls back to `video-YouTube<id>-<today>.md`; still valid note |
| 3.5 | `okm video "https://vimeo.com/123"` | Fails: `Not a supported video link` |
| 3.6 | `okm video "https://www.youtube.com/watch?v=short"` | Fails: `could not extract an 11-char video ID` |
| 3.7 | `okm video` (no arg) | Fails: `Video link or file required` |
| 3.8 | `okm video <local.mp4> "Lecture 1"` | Metadata scaffold `video-Lecture1-<today>.md` (no ASR) |

Real end-to-end check already observed in the vault:
`video-AIEngineer-DontShipSkillsWithoutEvalsPhilippSchmidGoogleDeepMind-2026-07-14.md`
(correct convention from a live YouTube URL; transcript blank until
`youtube-transcript-api` is installed).

Automated coverage: `tests/okm_cli.bats` (okm video §), `tests/fuzz.bats`.

---

## Sign-off checklist

- [ ] `bash tests/run_all.sh` — all pass (only env-gated skips)
- [ ] §1 weekly note: create, idempotent, task roll-forward
- [ ] §2 pod: at least one live link per platform (Spotify / Apple / RSS), plus 2.6–2.14 hermetic cases
- [ ] §3 video: live YouTube with and without captions, plus rejections
- [ ] Every produced filename matches the convention in "Design invariants"
- [ ] No note contains a transcript that the source did not publish
