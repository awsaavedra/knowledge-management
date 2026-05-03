# Roadmap

> **Companion to [README.md](README.md).** This file holds the full critique, the v0/v1/v2 scope table, every numbered finding (B-, F-, N-series), the recommended ship plan, and the planned-feature list. The README links here from its **Roadmap** section.

Status reflects the current shipping state of the project. v0 is **yellow, not green**, even *after* the original B1–B5 / F3–F4 fixes land. Four rounds of review have cumulatively surfaced:

1. **First pass** (static read): B1–B5, F1–F7, polish — bugs visible on inspection.
2. **Second pass** (re-read against the v0 plan): N1–N5 — conflicts between roadmap items, plus deferred N6–N9.
3. **Third pass** (running the code with realistic inputs): N10–N15 — runtime bugs the static reviews missed, including a privacy leak in the CLI itself.
4. **Fourth pass** (adversarial inputs — what users actually type): N16–N24 — input-validation bugs, including a path traversal in `okm open` and silent data corruption in `okm tag` on notes containing horizontal rules.

Estimate: **~2 days of work** to ship-green, including tests. (Originally estimated as half a day; corrected after each subsequent pass found more.) The rate-of-discovery has not yet slowed: every pass finds bugs the previous pass missed. **Strong recommendation:** before tagging v0, add a fuzz/property-test harness over `bin/okm` covering Unicode/quotes/slashes/newlines/empty/long inputs to all subcommands. Otherwise this is whack-a-mole.

**Current state note:** Suite is green (292 tests, 0 failures) as of this writing. [N25](#fourth-pass-findings) is now resolved — `install_direnv` is implemented in `setup-km.sh` and `tests/direnv.bats` passes. The "EDITOR is set to nvim" test was rewritten so it no longer breaks when the parent shell exports `EDITOR=vim` (the previous version asserted on `EDITOR == nvim` after sourcing `env.sh`, which by design preserves a pre-set `EDITOR`). Roadmap items below are still open; this note tracks only suite health.

## Scope by Version

Active planning horizon. Anything beyond v2 is intentionally undefined — focus is on getting v0 out.

| Item | v0 (ship-green) | v1 (post-ship cleanup) | v2 (next feature wave) |
|---|---|---|---|
| **B1** wikilink rewriter substring bug ([details](#pre-v0-blockers)) | ✅ required | | |
| **B2** `okm tagged` partial-match bug ([details](#pre-v0-blockers)) | ✅ required | | |
| **B3** block-style YAML tags hard-fail ([details](#pre-v0-blockers)) | ✅ required (hard-fail) | read support | |
| **B4** tag-name validation ([details](#pre-v0-blockers)) | ✅ required | | |
| **B5** vault `.gitignore` covers secrets ([details](#pre-v0-blockers)) | ✅ required | `okm sync` confirms uncommon extensions | |
| **F3** `okm today` ↔ `daily-template.md` alignment ([details](#known-bugs)) | ✅ required | | |
| **F4** WSL2 registry/font disclosure + flag gate ([details](#known-bugs)) | ✅ required | | |
| **N1** templates → inline YAML so B3 doesn't fire on demo dataset ([details](#second-pass-findings)) | ✅ required | block-style read support | |
| **N2** Format Specification drift across 4 producers ([details](#second-pass-findings)) | ✅ required (broaden F3) | | |
| **N3** vault `.gitignore` template ignores `private-*/*.md` when `KM_TRACK_NOTES=false` ([details](#second-pass-findings)) | ✅ required | | |
| **N4** README platform-support row says "Debian/Ubuntu" not "Linux" ([details](#second-pass-findings)) | ✅ required (1-line doc) | | |
| **N5** `gitignore.bats` test updated for F5 dead-rule removal ([details](#second-pass-findings)) | ✅ required (paired with F5) | | |
| **N10** `okm tag` sed-delimiter break on hierarchical tags (`source/podcast`) ([details](#third-pass-findings)) | ✅ required | | |
| **N11** `okm tag` silent success on frontmatter-less files ([details](#third-pass-findings)) | ✅ required | | |
| **N12** privacy leak — `okm grep`/`tags`/`files`/`tagged`/`recent` read `private-*/` ([details](#third-pass-findings)) | ✅ required | richer `okm private <subcmd>` namespace | |
| **N13** `okm new` corrupts YAML when title contains `"` ([details](#third-pass-findings)) | ✅ required | | |
| **N14** `slugify` strips non-ASCII to empty/colliding strings ([details](#third-pass-findings)) | ✅ required (validate, not transliterate) | transliteration via `iconv` | |
| **N15** `okm sync` follows symlinks; commits paths to `/etc/passwd` etc. ([details](#third-pass-findings)) | ✅ required | | |
| **N16** `okm spot` with truncated URL produces polluted note instead of erroring ([details](#fourth-pass-findings)) | ✅ required | | |
| **N17** `okm tagged <regex>` is regex injection (`okm tagged ".*"` matches all) ([details](#fourth-pass-findings)) | ✅ required (folds into B2) | | |
| **N18** `okm new` with overly long title hits `File name too long` ([details](#fourth-pass-findings)) | ✅ required | | |
| **N19** `okm open` allows path traversal — opens any path on the filesystem ([details](#fourth-pass-findings)) | ✅ required | | |
| **N20** `okm new` with newline in title creates a file with embedded newlines in its name ([details](#fourth-pass-findings)) | ✅ required | | |
| **N21** `get_tags_line` matches `tags:` inside body `---...---` blocks → corruption ([details](#fourth-pass-findings)) | ✅ required | | |
| **N22** tag dedup uses `grep -qxF "$t"` — flag injection on tags starting with `-` ([details](#fourth-pass-findings)) | ✅ required (1-line) | | |
| **N23** `okm tag` accepts `]` and writes invalid YAML — confirms B4 is currently unguarded ([details](#fourth-pass-findings)) | ✅ required (folds into B4) | | |
| **N24** `okm files <pattern>` is substring grep, not glob — `okm files "*.md"` returns nothing ([details](#fourth-pass-findings)) | ✅ required (1-line doc or glob impl) | | |
| **N25** CI red — `tests/direnv.bats` tests unimplemented `install_direnv()` ([details](#fourth-pass-findings)) | ✅ required (decide implement vs delete) | | |
| Fuzz/property-test harness over `bin/okm` (final gate before v0 tag) ([details](#fourth-pass-findings)) | ✅ required | | |
| **F1** `okm spot` metadata fetch (use `spotdl meta` or `yt-dlp`) | | ✅ | |
| **F2** Offline Mode table notes `okm spot` networked | | ✅ | |
| **F5** drop dead `inbox/*-template.md` negation in `.gitignore` | | ✅ | |
| **F6** `KM_TRACK_NOTES` default unified to `true` everywhere | | ✅ | |
| **F7** decouple cron tests from README strings | | ✅ | |
| **Tagging** `okm rename-tag <old> <new>` | | ✅ | |
| **Tagging** `-t` flag on `okm today` (symmetry) | | ✅ | |
| **Tagging** `okm tags --json` | | ✅ | |
| **Tagging** block-style YAML read support | | ✅ | |
| **Polish** setup log rotation (keep-last-N) | | ✅ | |
| **Polish** `okm sync -m "msg"` flag form | | ✅ | |
| **Polish** `LC_ALL=C` in test runner to silence warnings | | ✅ | |
| **Polish** `verify-km.sh` banner-vs-exit-code note in README | | ✅ | |
| **Polish** README architecture diagram covers dual-mode (project=vault when same name) ([details](#second-pass-findings)) | | ✅ | |
| **Polish** `okm version` / `--version` flag ([details](#second-pass-findings)) | | ✅ | |
| **Polish** `verify-km.sh` reports direnv / `.envrc` state ([details](#second-pass-findings)) | | ✅ | |
| **Polish** `okm spot` URL injection hardening for markdown link interpolation ([details](#second-pass-findings)) | | ✅ | |
| macOS support (Homebrew paths in `setup-km.sh`) | | ✅ | |
| git-crypt initialisation (`okm crypt init`) | | ✅ | |
| `okm yt` — YouTube transcript + metadata → note | | | ✅ |
| `okm pod` — local audio → whisperX → note | | | ✅ |
| `okm distill` — AI summary (Claude + Ollama backends) | | | ✅ |
| `okm online` / `okm offline` toggle | | | ✅ |
| HuggingFace token for pyannote (speaker diarization) | | | ✅ |
| Private PARA mirror folder | | | ✅ |
| fzf-based tag picker | | | ✅ |
| `#inline-tags` body scanning (Obsidian-style) | | | ✅ |
| Tag aliasing | | | ✅ |
| Hierarchical tags (`source/spotify`) — already work via convention; promote to first-class | | | ✅ |

**v0 exit criteria:** every row marked ✅ under v0 is checked off, full BATS suite green, CI green on `main`.

## Second-pass findings

Discovered on a deeper re-review of the codebase against the v0 roadmap. These are gaps the first critique missed — adding them to v0 because they either invalidate other v0 fixes or mislead users on day one.

- [ ] **N1. Templates use block-style YAML that B3's hard-fail will reject.**

  4 of 10 first-party templates ship with multi-line YAML tag lists:
  ```yaml
  tags:
    - source/youtube
    - topic/your-topic
  ```
  Files: `inbox/templates/yt-template.md`, `inbox/templates/podcast-template.md`, `inbox/templates/spotify-episode-template.md`, `inbox/templates/spotify-track-template.md`.

  Once [B3](#pre-v0-blockers) lands, `okm tag <demo-yt-example.md> foo` immediately hard-fails — and the README's quickstart literally instructs users to open `inbox/demo-yt-example.md` as their first verification step. The CLI rejects the project's own seed data.

  **Minimal fix:** rewrite all 4 templates to inline-array form (`tags: [source/youtube, topic/your-topic]`). Zero CLI changes needed. v1 can add block-style read support and a `--migrate-tags` command.

- [ ] **N2. Format Specification drift across 4 producers — the contract is a lie in 4 places.**

  The `<!-- Format Specification: ... -->` block on each template documents the sections the producer is supposed to emit. Today, four producers don't honour it:

  | Producer | Template requires | CLI emits | Missing |
  |---|---|---|---|
  | `okm today` | Captures, Notes, Tasks, Reflection | Tasks, Notes | Captures, Reflection |
  | `okm new` | Context, Notes, Links | (no sections) | Context, Notes, Links |
  | `okm spot` (track/album/playlist) | Player, Notes, Why I saved this | Player, Notes | Why I saved this |
  | `okm spot` (episode) | Player, Summary, Actionable Insights, Sources Cited, Follow-ups, Structured Data, Key Quotes, Transcript | Player, Summary, Key Quotes, Transcript | Actionable Insights, Sources Cited, Follow-ups, Structured Data |

  [F3](#known-bugs) only covered `okm today`. It needs to be widened to all four producers.

  **Minimal fix (preferred):** have each producer render its template with placeholder substitution (the same `{{TITLE}}` / `{{CREATED}}` mechanism `seed-demo.sh` already uses). Tests under `tests/templates.bats` already enforce template structure; aligning the CLI makes templates load-bearing instead of decorative.

  **Alternative:** shrink each template's `Required sections:` line to match what the CLI emits today. Cheaper but loses the "rich note" intent of the Format Specifications.

- [ ] **N3. Vault `.gitignore` doesn't ignore `private-*/*.md` even when `KM_TRACK_NOTES=false`.**

  `setup-km.sh:ensure_gitignore` writes:
  ```
  daily/*.md
  inbox/*.md
  archive/*.md
  ```
  …but never `private-daily/*.md`, `private-inbox/*.md`, `private-archive/*.md`, `private-attachments/*`. The README sells `private-*/` as "off-limits to AI assistants" and pairs it visually with red banners — users will reasonably infer "private = local-only". Today, `okm sync` happily commits everything under `private-*/`.

  **Minimal fix:** in both [B5](#pre-v0-blockers)'s gitignore extension and the `KM_TRACK_NOTES=false` branch, also append:
  ```
  private-daily/*.md
  private-inbox/*.md
  private-archive/*.md
  private-attachments/*
  ```
  Plus a one-liner in the README's **Rules** section: "Private folders are local-by-default. Opt them into git by removing the `private-*/*.md` lines from the vault `.gitignore`."

- [ ] **N4. Platform support row says "Linux (apt + Flatpak)" but `setup-km.sh` is Debian/Ubuntu-only.**

  `install_apt_packages` calls `dpkg -s` and `sudo apt update`. Fedora/Arch/openSUSE users hit hard failure on the first install step. The README's stack table reads as if any Linux is supported.

  **Minimal fix:** change `**Platform support:** Linux (apt + Flatpak)` to `**Platform support:** Debian/Ubuntu (apt + Flatpak)`. Add a one-line note pointing non-Debian Linux users to the macOS-support roadmap row as a tracking issue.

- [ ] **N5. `gitignore.bats` couples to the dead `!inbox/*-template.md` rule that [F5](#known-bugs) removes.**

  ```
  @test "template files are exempted from inbox ignore" {
      grep -q '!inbox/\*-template.md' "$GITIGNORE"
  }
  ```
  Templates moved to `inbox/templates/*.md` long ago; this exemption no longer matches anything. F5 removes the rule but the test still asserts on it. Drop the test (or rewrite to assert that `inbox/templates/*.md` files are tracked) when F5 lands.

### Bumped to v1 (out of scope for v0)

- [ ] **N6. README architecture diagram doesn't disclose dual-mode (project = vault).** When the repo is cloned as `knowledge-management/`, the project root and the vault are the same directory. `env.sh` handles this correctly, but the architecture diagram only shows the sibling-vault layout. New users will be confused about where `daily/` actually lives.

- [ ] **N7. No `okm version` / `--version`.** Once forks exist, knowing what's installed matters for bug reports. Trivial — emit a constant pinned to a tag.

- [ ] **N8. `verify-km.sh` doesn't check `.envrc` / direnv state.** `tests/skills_phase3.bats` enforces `.envrc`'s presence at the project level, but the user-facing health check is silent on whether direnv is hooked or `direnv allow .` was run.

- [ ] **N9. `okm spot` interpolates the raw URL into a markdown link without escaping.** `[Listen on Spotify](${url})` with a URL containing `)` or backticks could break the link. The Spotify ID extraction regex prevents iframe injection, but the markdown link itself is unguarded. Low-severity — Spotify URLs don't naturally contain those characters — but worth hardening for robustness.

## Third-pass findings

These were not visible from reading the code alone — they only surface when you run the CLI with the kind of inputs real users actually type. Reproductions performed against the current `bin/okm` in this repo.

- [ ] **N10. `okm tag <note> source/podcast` errors silently with `sed: unknown option to 's'`.**

  Reproduction:
  ```
  $ okm tag inbox/note.md source/podcast
  sed: -e expression #1, char 54: unknown option to `s'
  Tagged: note.md -> tags: [existing, source/podcast]   # lie — file unchanged
  ```
  Root cause: `add_tags` builds `new_yaml="tags: [existing, source/podcast]"` and runs `sed -i "/^---$/,/^---$/{s/^tags:.*$/${new_yaml}/;}" "$file"`. The `/` inside `new_yaml` terminates the s-command early. The CLI then prints "Tagged:" regardless because the function checks no error.

  Why it matters: hierarchical tags (`source/podcast`, `source/youtube`, `topic/foo`) are exactly what `okm spot` writes natively, and what the README's tag conventions promote ("Hierarchical tags — already work via convention"). Any user who tries to add one through the CLI sees a confusing sed error followed by a fake success message.

  **Minimal fix:** use a sed delimiter that doesn't appear in tag values (e.g. `s|^tags:.*$|${new_yaml}|` with `|`), and drop the `|` from the validated tag-character set in [B4](#pre-v0-blockers). Same change applies to `remove_tags`.

- [ ] **N11. `okm tag` on a file with no YAML frontmatter prints success but does nothing.**

  Reproduction:
  ```
  $ echo "Just plain text" > inbox/plain.md
  $ okm tag inbox/plain.md newtag
  Tagged: plain.md -> tags: [newtag]   # lie
  $ cat inbox/plain.md
  Just plain text                       # unchanged
  ```
  Root cause: the no-frontmatter branch in `add_tags` runs `sed -i "0,/^---$/!{0,/^---$/s/^---$/${new_yaml}\n---/}" "$file"`. With no `---` in the file the regex never matches, sed exits 0, the script prints success, and the file is silently unchanged. Capture notes, scratch files, and externally-imported markdown are exactly the population that won't have frontmatter.

  **Minimal fix:** detect the no-frontmatter case explicitly (`! grep -q '^---$' "$file"`) and either (a) prepend a frontmatter block, or (b) refuse with a clear error pointing at `okm new` for note creation.

- [ ] **N12. `okm grep`, `okm tags`, `okm files`, `okm tagged`, and `okm recent` all read `private-*/` indiscriminately.**

  Reproduction:
  ```
  $ cat > private-inbox/secret.md <<EOF
  ---
  tags: [therapy, abusive-boss-name]
  ---
  EOF
  $ okm tags
  1    therapy
  1    abusive-boss-name
  $ okm grep abusive
  /vault/private-inbox/secret.md:2:tags: [therapy, abusive-boss-name]
  ```
  The README sells `private-*/` as the project's privacy primitive ("off-limits to AI assistants", red banners in editor) and users will reasonably read it as "private = isolated". But the CLI itself ignores the boundary: every read command walks the entire vault, including `private-*/`. Running `okm grep secret` over a coffee shop screen-share leaks private content the user thought was siloed. This is the privacy issue the project is designed *not* to have.

  **Minimal fix (v0):** every read-side helper (`grep_vault`, `files_vault`, `list_notes`, `list_tags`, `list_tagged`, `recent_notes`) gains a default exclude `--glob '!private-*/'`. Add an `okm --include-private <subcmd>` flag (or a `okm private <subcmd>` subnamespace in v1) for the explicit opt-in case. Document the new default in the **Rules** section.

- [ ] **N13. `okm new "..."` with a double-quoted title produces invalid YAML.**

  Reproduction:
  ```
  $ okm new 'My "Quoted" Note'
  $ head -3 inbox/my-quoted-note.md
  ---
  title: "My "Quoted" Note"   # YAML parser sees three strings
  ```
  This naturally hits anyone titling a note `Lessons from "The Manager"` or `Notes on Joel's "Smart and Gets Things Done"`. Any downstream YAML consumer (Obsidian's metadata, `parse_tags`, `get_title`) sees corrupt frontmatter. Same bug in `okm spot` for artist names containing quotes.

  **Minimal fix:** in every heredoc that interpolates user strings into YAML, escape `"` to `\"` (or render as a single-quoted YAML scalar with `'` doubled). One-line shell function: `yaml_quote() { printf '%s' "${1//\"/\\\"}"; }`.

- [ ] **N14. `slugify` strips non-ASCII characters to empty, producing collisions and zero-length filenames.**

  Reproduction:
  ```
  $ okm new 'Café'
  $ ls inbox/
  caf.md                    # the é is dropped
  $ okm new '☕'
  Title required            # actually fine — would have been ".md"
  $ okm new '   leading'    # whitespace-only or punctuation-only edge cases vary
  ```
  Two failure modes: silent collisions (`Café` and `Cafe` both produce `cafe.md` after the trailing `-` strip) and degenerate slugs (a Japanese title slugifies to empty, producing `inbox/.md`). Tests don't cover this.

  **Minimal fix (v0, conservative):** if `slugify` returns empty or fewer than 2 chars, exit non-zero with "Title produces empty slug — use ASCII letters/digits or pass `--slug <explicit>`". v1 can add `iconv -f UTF-8 -t ASCII//TRANSLIT` for transliteration.

- [ ] **N15. `okm sync` follows symlinks; a symlink in the vault to `/etc/passwd` (or any external file) is committed to git history.**

  Reproduction:
  ```
  $ ln -s /etc/passwd inbox/oops-passwd.md
  $ okm sync
  ...
  create mode 120000 inbox/oops-passwd.md   # the path leaks; if pushed, the
                                            # symlink target is now public on the remote
  ```
  This is broader than [B5](#pre-v0-blockers) (which only blocked filename patterns). Users sometimes symlink files into the vault to read them in Obsidian (a habit the project's "everything is plain markdown" framing encourages). One stray symlink and `okm sync` exfiltrates a target path on the next push.

  **Minimal fix:** in `setup-km.sh:ensure_git_repo`, `git -C "$VAULT" config core.symlinks false`. In `bin/okm:sync_git`, before staging, refuse if `find "$VAULT" -type l -not -path '*/.git/*'` returns anything that resolves outside the vault, with a clear error.

## Fourth-pass findings

Adversarial-input round. Reproductions performed against the current `bin/okm` in this repo. The pattern: every pass finds bugs the previous pass missed, so this list closes with a recommendation to add a fuzz harness before tagging v0.

- [ ] **N16. `okm spot https://open.spotify.com/track/` (no ID) and `okm spot https://open.spotify.com/` create polluted notes instead of erroring.**

  Reproduction:
  ```
  $ okm spot 'https://open.spotify.com/track/'
  Created: /vault/inbox/https-open-spotify-com-track.md
  $ okm spot 'https://open.spotify.com/'
  Created: /vault/inbox/https-open-spotify-com.md
  ```
  Both pass the `*open.spotify.com/*` URL validator. Spot-ID extraction silently produces an empty/wrong value, then the title-fallback regex inverts the URL into the title slug, yielding garbage filenames and broken iframe `src` URLs. Anyone fat-fingering a copy-paste lands an unusable note in `inbox/`.

  **Minimal fix:** after the spot_id regex, validate `[ -n "$spot_id" ] && [[ "$spot_id" =~ ^[a-zA-Z0-9]{20,}$ ]]`. Refuse with a clear error otherwise.

- [ ] **N17. `okm tagged <pattern>` interpolates the tag name into a ripgrep regex unescaped — regex injection.**

  Reproduction:
  ```
  $ okm tagged '.*'
  daily/2026-05-02.md
  inbox/everything-else.md
  ...                          # returns every tagged file
  $ okm tagged 'foo|bar'       # OR-search, not literal tag named "foo|bar"
  ```
  Folds into [B2](#pre-v0-blockers)'s scope: replacing the regex search with parsed-tag equality fixes both the boundary bug (B2) and the injection (N17) in one rewrite.

- [ ] **N18. `okm new "<very-long-title>"` aborts with `File name too long` from the OS.**

  Reproduction (4096-char title):
  ```
  $ okm new "$(python3 -c 'print("a"*4096)')"
  /home/.../bin/okm: line 263: .../inbox/aaaa...aaa.md: File name too long
  ```
  No graceful handling — the user sees a raw bash error with the full slug pasted into the message. ext4 caps filenames at 255 bytes; ZFS at 255; older filesystems shorter. The CLI silently assumes "any title fits".

  **Minimal fix:** after `slug=$(slugify "$title")`, if `${#slug} -gt 200`, exit non-zero with "Title slug too long (${#slug} chars; max 200) — use `--slug <short>`".

- [ ] **N19. `okm open <relative-or-absolute-path>` allows path traversal — opens any file on the filesystem.**

  Reproduction:
  ```
  $ okm open ../../etc/passwd
  # exec $EDITOR ../../etc/passwd  -- runs your real editor on /etc/passwd
  $ okm open /home/user/.ssh/id_ed25519
  # exec $EDITOR /home/user/.ssh/id_ed25519
  ```
  `open_note` does:
  ```
  if [ -e "$target" ]; then
      exec "$EDITOR_CMD" "$target"
  else
      exec "$EDITOR_CMD" "$VAULT/$target"
  fi
  ```
  No check that `realpath(target)` lives inside `realpath(VAULT)`. The README implies `okm` is vault-scoped; users will pipe filenames in from scripts (`okm open "$(some_command)"`) and not expect arbitrary-path edit.

  **Minimal fix:** before exec, resolve `realpath(target)` and verify it is a prefix of `realpath(VAULT)`. Refuse otherwise. Add `--external` flag for the rare opt-out case.

- [ ] **N20. `okm new "$(printf 'multi\\nline\\ntitle')"` creates a file with embedded newlines in its name.**

  Reproduction:
  ```
  $ okm new $'multi\nline\ntitle'
  $ ls inbox/
  multi
  line
  title.md             # one filename containing \n characters, ls breaks it across rows
  ```
  Slugify processes line-by-line via `sed`, so each line slugifies independently and the resulting `slug` retains the original `\n` characters. The created file has an unusable name; subsequent `find`, `okm files`, and `okm sync` all behave erratically.

  **Minimal fix:** in `slugify`, prepend `tr '\n\r\t' '   '` to collapse vertical whitespace before substitution. Or: validate that `$title` is a single line and refuse otherwise.

- [ ] **N21. `get_tags_line` matches `tags:` inside body `---...---` blocks — silent data corruption when adding/removing tags on notes with horizontal rules.**

  Reproduction:
  ```
  $ cat inbox/note.md
  ---
  tags: [real-tag]
  ---
  # Note
  Some text
  ---
  An example showing someone else's frontmatter:
  tags: [example-tag]
  ---
  $ okm tags inbox/note.md
  real-tag
  example-tag                  # body content read as frontmatter
  $ okm tag inbox/note.md newtag
  # the body's `tags: [example-tag]` line ALSO gets rewritten
  ```
  The sed range `/^---$/,/^---$/` matches *every* `---...---` block, not just the first. Any user note that quotes someone else's frontmatter, demonstrates YAML, or uses `---` as a horizontal rule (a common Markdown idiom) gets its body silently rewritten on `okm tag`/`untag`.

  **Minimal fix:** restrict frontmatter parsing to the very first `---...---` block. Use `awk '/^---$/{c++; if (c>2) exit; next} c==1' "$file"` or equivalent. Update `get_tags_line`, `add_tags`, and `remove_tags` to share that helper.

- [ ] **N22. Tag dedup uses `grep -qxF "$t"` — `grep` interprets a tag starting with `-` as a flag.**

  Reproduction:
  ```
  $ okm tag inbox/note.md '-malicious'
  grep: invalid max count
  Tagged: note.md -> tags: [-malicious]
  ```
  The dedup loop runs `echo "$merged" | grep -qxF "$t"`. With `t='-malicious'`, `grep -qxF -malicious` is parsed as flags. The error doesn't stop the script (because of `||` semantics) and the tag is added anyway — but with diagnostic noise leaking into stderr and a corrupt YAML output.

  **Minimal fix:** `grep -qxF -- "$t"` (use `--` to terminate option parsing). One-character change.

- [ ] **N23. `okm tag` accepts `]` in tag values, producing invalid YAML — live confirmation that [B4](#pre-v0-blockers) is currently unguarded.**

  Reproduction:
  ```
  $ okm tag inbox/note.md 'evil]'
  Tagged: note.md -> tags: [existing, evil]]
  $ cat inbox/note.md
  ---
  tags: [existing, evil]]
  ---
  ```
  The reject pattern in B4 must include `]`, `[`, `,`, `:`, `"`, and whitespace. This is also why N17/B2's "use parsed equality, not regex" fix is necessary — a tag containing `]` would also break a literal regex match.

- [ ] **N24. `okm files <pattern>` is substring grep, not glob — `okm files "*.md"` returns nothing.**

  Reproduction:
  ```
  $ okm files "*.md"
                       # empty
  $ okm files ".md"
  inbox/note.md
  daily/2026-05-02.md  # works because .md is a substring
  ```
  `files_vault` does `list_notes | grep -i -- "$pattern"`, which is literal substring match. The README's CLI table calls it "List all `.md` paths, optionally filtered" — users will type globs (`*.md`, `inbox/*`) and silently get zero results.

  **Minimal fix (cheapest):** rewrite the README row to say "filtered by literal substring (case-insensitive)". **Better:** accept globs via `find -name "$pattern"` instead of `grep`. Either is fine; pick one and document it.

- [ ] **N25. CI is currently red — `tests/direnv.bats` references an `install_direnv()` that doesn't exist in `setup-km.sh`.**

  Reproduction:
  ```
  $ bash tests/run_all.sh --tap | grep '^not ok'
  not ok 65 install_direnv function exists in setup-km.sh
  not ok 66 setup-km.sh calls install_direnv in the install steps section
  not ok 68 install_direnv only writes to ~/.bashrc not ~/.zshrc
  not ok 69 install_direnv writes direnv hook line to ~/.bashrc
  not ok 70 install_direnv hook write is idempotent (no duplicate lines)
  not ok 71 install_direnv does not write anything to ~/.zshrc
  not ok 72 install_direnv skips hook write when already present
  ```
  This means: (a) the README's "the BATS suite passes" claim is currently false on `main`, (b) `.github/workflows/test.yml` is presumably failing, and (c) anyone forking right now hits red CI on first push. Tests reference behaviour that was specified but never implemented.

  **Minimal fix:** decide whether `install_direnv` is in v0 scope. If yes, implement it (write the direnv hook to `~/.bashrc` only, idempotently, gated by direnv being on PATH). If no, delete `tests/direnv.bats`. Either way, the suite must be green before any other v0 work tags.

- [ ] **Fuzz / property-test harness over `bin/okm`.**

  Every review pass has found bugs the previous pass missed (B-series → F-series → N1-9 → N10-15 → N16-24). The arrival rate hasn't slowed. Before tagging v0, add a small property test that throws random Unicode/quotes/slashes/newlines/empty/long strings at:
  - `okm new <title>`
  - `okm capture <body>`
  - `okm tag <note> <tag...>`
  - `okm tagged <tag>`
  - `okm spot <url>`
  - `okm grep <pattern>`
  - `okm files <pattern>`
  - `okm open <path>`

  Pass criteria: every command either exits 0 with a sane file written, or exits non-zero with a human-readable error. Never: silent success, partial corruption, error-with-exit-0, or files written outside the vault.

  This is the only v0 item that needs a new bit of infrastructure rather than a 1-to-15-line patch. Worth half a day.

## Pre-v0 Blockers

Must fix before tagging v0. These are correctness bugs that will bite real users in week one.

- [ ] **B1. `compress-images.py` — wikilink rewriter does substring match, not boundary match.**
  ```
              updated = content.replace(old_name, new_name)
  ```
  If `attachments/foo.png` is converted, every occurrence of the literal string `foo.png` in any note gets replaced — including inside `super-foo.png`, `not-foo.png`, etc. Real vaults have prefixed/suffixed names. This silently corrupts wikilinks that point to **different files**.

  **Minimal fix:** replace only inside `![[...]]` and `[](...)` link contexts, e.g. via a regex like `r"!\[\[" + re.escape(old) + r"\]\]"` (and the `[](path)` form too).

- [ ] **B2. `okm tagged` matches partial tags via faulty word boundary.**
  ```
    rg -l --glob '*.md' --glob '!.git/' "^tags:.*\\b${tag}\\b" "$VAULT" 2>/dev/null \
      | sed "s#^$VAULT/##" | sort
  ```
  `\b` treats `-` and `/` as non-word characters, so `okm tagged para` matches notes tagged `para-tag` or `parameters`, and `okm tagged source` matches `source/spotify`. The frontmatter scan in `list_tags` has the same blind spot.

  **Minimal fix:** match on the tokenised list instead of regex against the line, or anchor with delimiters present in the inline-array form: `[, ]`. Easiest correct version: parse tags per file with `parse_tags` and compare equality.

- [ ] **B3. `okm tag`/`untag` only handle inline-array YAML; multi-line lists are silently broken.**
  ```
  parse_tags() {
    local line="$1"
    echo "$line" | sed 's/^tags:[[:space:]]*//; s/^\[//; s/\]$//; s/,/ /g' \
      | tr ' ' '\n' | sed '/^$/d'
  }
  ```
  Anyone who uses Obsidian's "tags" plugin or hand-writes:
  ```yaml
  tags:
    - foo
    - bar
  ```
  …will silently get `(no tags)` from `okm tags <note>`, and `okm tag` will inject a second `tags:` line (corrupt YAML) because `get_tags_line` only finds the header line. Obsidian users absolutely write tags this way — this is the most common foot-gun for v0.

  **Minimal fix:** detect block style (next line begins with `- `) and either (a) refuse with a clear error and a hint to switch to inline, or (b) normalise on read.

- [ ] **B4. No tag-name validation — users will break their own YAML.**
  `okm tag mynote "machine learning"` writes:
  ```yaml
  tags: [machine learning]
  ```
  …which `parse_tags` will then split into two tags (`machine`, `learning`). Same for tags containing `,` `[` `]` `:` `"`.

  **Minimal fix:** in `add_tags`, reject tag values matching `[[:space:],\[\]:\"]` with a one-line error. ~3 lines.

- [ ] **B5. `git add -A` in `okm sync` is dangerous on a shared vault.**
  ```
    git -C "$VAULT" add -A
  ```
  Anyone who drops a `.env`, `~/.aws/credentials` symlink, or a private export into the vault root will commit it on next `okm sync`. The `.gitignore` covers binary noise, not secrets.

  **Minimal fix:** at minimum, add a top-level `.gitignore` rule for `.env*`, `*.pem`, `*credentials*`, `*.key`. Better: `okm sync` should print the file list and prompt on first uncommon extension.

## Known Bugs

Functional, lower severity than blockers. Tracked but do not block v0 sign-off on their own.

- [ ] **F1. `okm spot` is misusing `spotdl save`.**
  ```
      meta="$(spotdl save "$url" --output "{artist} - {title}" 2>/dev/null | head -1 || true)"
  ```
  `spotdl save` writes a `.spotdl` JSON file; it does not emit `Artist - Title` on stdout. So `meta` is almost always empty in real use, and `title` falls through to `Spotify track <id>`. The frontmatter `title:` ends up as `Spotify track 6rqhFgbbKwnb9MLmUQDhG6` — not human-readable. Tests mask this because they only check the slug.

  **Minimal fix:** use `spotdl meta <url>` (it has a `--print-only` flag) or `yt-dlp --skip-download --print "%(artist)s - %(title)s" "$url"` (already a project dep). Or be honest: drop the metadata fetch and use `Spotify <type> <id>` consistently.

- [ ] **F2. `okm spot` makes a network call but README claims "offline by default".**
  `spotdl save` hits the Spotify API. `setup-km.sh` revokes Obsidian's network but leaves `okm spot` networked. That's defensible — you opt in by running `okm spot` — but the README's "Offline Mode" table doesn't mention this asymmetry. Worth one line under that table.

- [ ] **F3. `okm today` template diverges from `daily-template.md`.**
  `bin/okm today_note()` hardcodes `## Tasks` + `## Notes`, but `inbox/templates/daily-template.md` requires `Captures`, `Notes`, `Tasks`, `Reflection`. The Format Specification block on the template lies about what gets produced. Either:
  - have `today_note()` render the template (preferred — tests already validate template structure), or
  - shrink the template to match the CLI.

- [ ] **F4. `setup-km.sh` modifies Windows registry on WSL2 but README says "no global config files were modified".**
  ```
          powershell.exe -c '
              $fontDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
              $regPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
              ...
  ```
  Plus mutates `Microsoft.WindowsTerminal_*\settings.json`. These are real, persistent, user-visible changes. The README's "Your ~/.zshrc, ~/.config/nvim, and ~/.config/lazygit are untouched" is technically accurate but materially misleading for WSL2 users. Add one line under **Rules** disclosing this, and gate it behind a prompt or `KM_INSTALL_FONT=1`.

- [ ] **F5. Project-root `.gitignore` has a dead rule.**
  ```
  # Personal notes (vault content should not live in the tooling repo)
  inbox/*.md
  !inbox/*-template.md
  ```
  Templates now live at `inbox/templates/*.md`, which `inbox/*.md` doesn't match in the first place — the negation is obsolete. Harmless, but suggests stale state. Remove it.

- [ ] **F6. `KM_TRACK_NOTES` default disagreement across files.**
  - `env.sh:40` defaults to `true`
  - `setup-km.sh:141` reads `${KM_TRACK_NOTES:-false}` (default `false`)
  - `setup-km.sh:563` interactive prompt defaults to `true`

  In the normal flow (`source env.sh && bash setup-km.sh`) this is consistent. But `bash setup-km.sh` alone (which the README's quickstart shows first) yields the opposite default from `env.sh`. Pick one and use `${KM_TRACK_NOTES:-true}` everywhere.

- [ ] **F7. `cron.bats` has documentation-coupling tests that will break for trivial edits.**
  ```
  @test "README.md documents all 3 cron times" {
      for hour in "${EXPECTED_HOURS[@]}"; do
          grep -q "3 ${hour} \* \* \*" "${PROJECT_ROOT}/README.md"
      done
  }
  ```
  Coupling docs strings to test assertions makes README edits a foot-gun. Either drop these or move the cron schedule into a single source-of-truth file (`scripts/cron.example`) that both README and script load.

## Tagging Gaps to Close

The skeleton is there but it's not safe at the scale of "I'll tag thousands of notes and refactor the taxonomy in a year". Minimal additions for v0:

- [ ] **Fix the substring-match bug** ([B2](#pre-v0-blockers)) — non-negotiable.
- [ ] **Reject invalid tag chars** ([B4](#pre-v0-blockers)) — non-negotiable, ~3 lines.
- [ ] **Detect block-style YAML and bail with a clear error** ([B3](#pre-v0-blockers)) — could be a hard-fail in v0, with v0.1 adding read support.
- [ ] **Add `okm rename-tag <old> <new>`** — single most common operation users do once they realize their tagging scheme is wrong. ~15 lines around `add_tags`/`remove_tags`.
- [ ] **Add `-t` to `okm today`** — currently asymmetric (`new`, `capture`, `spot` accept it; `today` doesn't). Trivial.
- [ ] **`okm tags --json`** — for piping into fzf/scripts. Optional but a 3-line addition.

What you can defer:
- Hierarchical tags (`source/spotify` style) — already work via convention.
- fzf tag picker — nice but not blocking.
- `#inline-tags` body scanning — Obsidian-style. Defer to v0.1.
- Tag aliasing.

## Polish

Not blocking. Do later.

- [ ] Setup logs go to `~/.local/log/setup-km-*.log` but never get rotated/cleaned. Consider keep-last-N.
- [ ] `verify-km.sh` exits 1 on any FAIL but the exit happens after the summary banner — fine, just worth noting in README that the banner is informational.
- [ ] `okm sync` swallows commit messages with no quoting: `okm sync some message with spaces` is reconstructed via `"$*"` (line 524) but multi-arg quoting is fragile. Consider `okm sync -m "msg"` flag form, leaving positional as a shorthand.
- [ ] `bin/okm:230` `pick_file` and `:343 recent_notes` shell out to `find … -exec stat …` — the `||` chain on macOS path is unreachable on Linux because `stat --format=` succeeds. Refactor when adding macOS support.
- [ ] The `setlocale` warning floods test output (locale isn't installed in the dev env). Either set `LC_ALL=C` in `tests/run_all.sh` or document that warnings are benign.

## Recommended Ship Plan

In priority order, do these in one PR per cluster to reach green. The ordering is deliberate: clustered fixes share helpers and want one coherent rewrite each, and `private-*/` exclusion must land alongside B5+N3 for the privacy story to be coherent end-to-end. Step 11 (fuzz) is the gate.

1. [B1](#pre-v0-blockers) — `compress-images.py` regex-bound wikilink replacement + adjacency-collision test.
2. **Tagging cluster** — single rewrite of `add_tags`/`remove_tags`/`get_tags_line`/`list_tagged` covering [B2](#pre-v0-blockers) (boundary regex) ⊃ [N17](#fourth-pass-findings) (regex injection), [B3](#pre-v0-blockers) (block-style hard-fail), [B4](#pre-v0-blockers) (char validation) ⊃ [N23](#fourth-pass-findings), [N10](#third-pass-findings) (sed delimiter), [N11](#third-pass-findings) (no-frontmatter), [N21](#fourth-pass-findings) (first-block-only frontmatter parse), [N22](#fourth-pass-findings) (`grep -- "$t"`). Tests for hierarchical tags, frontmatter-less files, body-`---` notes, and tags starting with `-`.
3. **Privacy cluster** — [N12](#third-pass-findings) excludes `private-*/` from every read-side `okm` command by default + paired with [B5](#pre-v0-blockers) and [N3](#second-pass-findings): vault `.gitignore` adds `.env*`, `*.pem`, `*.key`, `*credentials*`, `private-{daily,inbox,archive}/*.md`, `private-attachments/*`. README **Rules** updated with one line on each.
4. **Path-safety cluster** — [N19](#fourth-pass-findings) `okm open` refuses paths outside the vault + [N15](#third-pass-findings) `core.symlinks=false` and symlink refusal in `okm sync`.
5. **Input-validation cluster** — [N13](#third-pass-findings) escape `"` in YAML, [N14](#third-pass-findings) slugify fail-closed on empty/short slugs ⊃ [N18](#fourth-pass-findings) length cap ⊃ [N20](#fourth-pass-findings) newline collapse, [N16](#fourth-pass-findings) Spotify ID validation.
6. **[N1](#second-pass-findings)** — convert the 4 block-style templates to inline YAML *before* B3 ships, so B3 doesn't land red on the demo dataset.
7. **[F3](#known-bugs) widened by [N2](#second-pass-findings)** — align all 4 drifting producers (`okm today`, `okm new`, `okm spot` track, `okm spot` episode) to render their templates via placeholder substitution.
8. [F4](#known-bugs) — README disclosure on WSL2 Windows-side writes; gate font install behind a flag.
9. **[N4](#second-pass-findings)** — "Linux (apt + Flatpak)" → "Debian/Ubuntu (apt + Flatpak)" in the stack table.
10. **[N5](#second-pass-findings)** — drop the dead `!inbox/*-template.md` test in `tests/gitignore.bats` once [F5](#known-bugs) removes the rule. **[N24](#fourth-pass-findings)** — clarify or fix `okm files <pattern>` semantics (literal substring vs glob) and document it.
11. **[N25](#fourth-pass-findings)** — green CI first. Decide: implement `install_direnv` (writes `eval "$(direnv hook bash)"` to `~/.bashrc` idempotently) **or** delete `tests/direnv.bats`. Pick one, then move forward. No other work merges while CI is red.
12. **Fuzz gate** — add a property-test harness over `bin/okm` (see [Fuzz harness](#fourth-pass-findings)). Any new bug it finds becomes a v0 fix; only after fuzz is clean does v0 tag.

Then it's green. Everything else (F1, F2, F5, F6, F7, N6–N9, polish) is post-ship cleanup that won't lose you a user.

## Planned Features

Not yet started. Tracked separately from bug-fix work.

- [ ] `okm yt` — YouTube transcript + metadata → note
- [ ] `okm pod` — local audio → whisperX → note
- [ ] `okm distill` — AI summary (Claude + Ollama backends)
- [ ] `okm online` / `okm offline` toggle
- [ ] macOS support (Homebrew install paths in `setup-km.sh`)
- [ ] HuggingFace token for pyannote (speaker diarization)
- [ ] git-crypt initialisation
- [x] GitHub Actions CI for the BATS suite
- [ ] Private PARA mirror folder

## What's Genuinely Good

For balance — these are the things v0 already does well and should not be regressed during the bug-fix work:

- 280 BATS tests, fast, isolated via `FAKE_VAULT_DIR` and fake `$HOME` — this is rare and excellent.
- `scripts/lib/scan.sh` extracted as a real shared library, not duplicated between `todo-summary.sh` and `weekly-tasks.sh`.
- Idempotency is consistent across `setup-km.sh`, `okm new`, `okm today`, `okm spot`.
- `verify-km.sh` exit-code discipline (FAIL blocks, WARN doesn't) is the right shape.
- `_skills/`, `disclaimer.md`, `ai-instructions.md`, `private-*` boundary — privacy posture is well thought out.
- CI workflow is minimal and correct.

## Skills Roadmap

Tracked features migrated from `_skills/`. Check off as shipped.

- [x] **TODO/FIXME/BUG highlighting** — `TODO:` yellow, `FIXME:` orange, `BUG:` red. Neovim via `todo-comments.nvim` (`config/nvim/lua/plugins/todo-comments.lua`); Vim via `matchadd` in `config/vim/vimrc`.
- [x] **Public/private PARA banners** — Neovim winbar / Vim statusline shows green `PUBLIC PARA · <subdir>` or red `⚠ PRIVATE PARA · <subdir>` based on the buffer's path. Wired in `config/nvim/lua/config/autocmds.lua` and `config/vim/vimrc`.
- [x] **Typed templates + demo dataset** — every markdown type has a template in `inbox/templates/` with a Format Specification header. `bash scripts/seed-demo.sh` populates `demo-*` files across the public PARA folders; `--teardown` removes them.
- [x] **Auto-loading project-scoped config** — `.envrc` at the project root makes direnv auto-source `env.sh` on `cd`, activating `NVIM_APPNAME`, `VIMINIT`, `LG_CONFIG_FILE`, `MPV_HOME`, and the venv. One-time setup: `direnv allow .`.
- [x] **Richer video/podcast templates** — `yt-template`, `spotify-episode-template`, and `podcast-template` now require `## Actionable Insights`, `## Sources Cited`, and `## Follow-ups` sections.
- [x] **Required screenshots for video notes** — `yt-template` marks `## Screenshots` as REQUIRED with mpv `s` capture at every key visual moment so the note replaces re-watching. Spotify and podcast templates mark `## Key Quotes` as the audio-only equivalent.
- [x] **High-fidelity transcripts** — required whisperX flags (`large-v3-turbo`, `compute_type float32`, `--diarize`, `--vad_filter`) documented in `_skills/transcripts.md`.
- [x] **Beyond summarization → insights** — `_skills/distill-prompt.md` defines the four-section distill output (Summary / Actionable Insights / Sources Cited / Follow-ups), with hard rules against hallucinated citations and explicit handling of contradictions.
- [x] **Source citation in distill output** — `## Sources Cited` is part of every video/podcast template; the distill prompt spec mandates `Title — Author — URL/DOI/ISBN` formatting.
