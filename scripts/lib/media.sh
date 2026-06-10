#!/usr/bin/env bash
# media.sh — okm media-ingest commands: spot, yt, pod, distill.
#
# Sourced by bin/okm (not executable on its own). Uses bin/okm helpers
# (ensure_dirs, parse_tag_flag, slugify, yaml_escape_dq, _tags_yaml, iso_now,
# resolve_note) and globals (VAULT, NOTES_DIR, EDITOR_CMD, _REMAINING_ARGS).

_spotify_type() {
  case "$1" in
    *episode*)  echo "episode" ;;
    *show*)     echo "show" ;;
    *album*)    echo "album" ;;
    *playlist*) echo "playlist" ;;
    *)          echo "track" ;;
  esac
}

# N16: extract and validate the Spotify ID (exactly 22 base62 chars).
_spotify_id() {
  local url="$1" id
  id="$(printf '%s' "$url" | sed -E 's#.*/[a-z]+/([a-zA-Z0-9]+)(\?.*)?$#\1#')"
  if [ -z "$id" ] || [[ ! "$id" =~ ^[a-zA-Z0-9]{22}$ ]]; then
    echo "Invalid Spotify URL: could not extract a valid ID from '$url'" >&2
    return 1
  fi
  echo "$id"
}

_SPOT_ARTIST="" _SPOT_TITLE=""
_spotify_fetch_metadata() {
  _SPOT_ARTIST=""; _SPOT_TITLE=""
  local url="$1" meta=""
  if command -v spotdl >/dev/null 2>&1; then
    meta="$(spotdl save "$url" --output "{artist} - {title}" 2>/dev/null | head -1 || true)"
  fi
  if [ -z "$meta" ]; then
    echo "okm spot requires network access to fetch Spotify metadata. Continuing with offline scaffold." >&2
    return 0
  fi
  _SPOT_ARTIST="$(printf '%s' "$meta" | sed 's/ - .*//')"
  _SPOT_TITLE="$(printf '%s' "$meta" | sed 's/^[^-]*- //')"
}

_spotify_source_tag() {
  case "$1" in
    episode|show) echo "source/podcast" ;;
    track|album)  echo "source/music" ;;
    playlist)     echo "source/playlist" ;;
    *)            echo "source/spotify" ;;
  esac
}

spot_note() {
  ensure_dirs
  parse_tag_flag "$@"
  local url="${_REMAINING_ARGS[0]:-}"
  [ -n "$url" ] || { echo "Spotify URL required" >&2; exit 1; }

  case "$url" in
    *open.spotify.com/*|*spotify:*) ;;
    *) echo "Not a Spotify URL: $url" >&2; exit 1 ;;
  esac

  local spot_type spot_id embed_url
  spot_type="$(_spotify_type "$url")"
  spot_id="$(_spotify_id "$url")" || exit 1
  embed_url="https://open.spotify.com/embed/${spot_type}/${spot_id}"

  _spotify_fetch_metadata "$url"
  local title="${_SPOT_TITLE}" artist="${_SPOT_ARTIST}"

  if [ -z "$title" ]; then
    title="$(printf '%s' "$url" | sed -E 's|.*/[a-zA-Z]+/[a-zA-Z0-9]+[?/]?||; s/[?#].*//' | tr '-' ' ')"
    [ -n "$title" ] || title="Spotify ${spot_type} ${spot_id}"
  fi

  local slug file
  slug="$(slugify "$title")" || exit 1
  file="$VAULT/$NOTES_DIR/$slug.md"

  local safe_title safe_artist source_tag tags_yaml
  safe_title="$(yaml_escape_dq "$title")"
  safe_artist="$(yaml_escape_dq "$artist")"
  source_tag="$(_spotify_source_tag "$spot_type")"
  tags_yaml="$(_tags_yaml "$source_tag")"

  if [ ! -f "$file" ]; then
    # Frontmatter + player are shared; only the body sections differ by type.
    cat > "$file" <<EOF
---
title: "${safe_title}"
source_type: spotify-${spot_type}
source_url: "${url}"
author: "${safe_artist}"
created: $(iso_now)
tags: ${tags_yaml}
---

# ${title}

## Player

[Listen on Spotify](<${url}>)

<iframe src="${embed_url}" width="100%" height="352" frameBorder="0" allowfullscreen allow="autoplay; clipboard-write; encrypted-media; fullscreen; picture-in-picture" loading="lazy"></iframe>

EOF
    case "$spot_type" in
      episode|show)
        cat >> "$file" <<'EOF'
## Summary

<!-- caveman speech: short sentences, no filler, bullets over paragraphs -->

-

## Actionable Insights

## Sources Cited

## Follow-ups

- [ ]

## Structured Data

## Key Quotes

> [MM:SS] "..."

## Transcript

<!-- okm distill or whisperX after downloading audio -->

EOF
        ;;
      *)
        cat >> "$file" <<'EOF'
## Notes

-

## Why I saved this

EOF
        ;;
    esac
    echo "Created: $file"
  else
    echo "Exists: $file"
  fi
  exec "$EDITOR_CMD" "$file"
}

# Extract and validate an 11-char YouTube video ID from common URL forms
# (watch?v=, youtu.be/, shorts|embed|live/). Prints the ID or fails.
_youtube_id() {
  local url="$1" id
  id="$(printf '%s' "$url" | sed -E '
    s#.*[?&]v=([A-Za-z0-9_-]{11}).*#\1#; t
    s#.*youtu\.be/([A-Za-z0-9_-]{11}).*#\1#; t
    s#.*/(shorts|embed|live)/([A-Za-z0-9_-]{11}).*#\2#; t
    s#.*#@@#')"
  if [[ ! "$id" =~ ^[A-Za-z0-9_-]{11}$ ]]; then
    echo "Invalid YouTube URL: could not extract an 11-char video ID from '$url'" >&2
    return 1
  fi
  printf '%s' "$id"
}

# Pull title/uploader/upload_date via yt-dlp when present. Sets the _YT_* vars.
# Graceful no-op offline or without yt-dlp — same pattern as _spotify_fetch_metadata.
_YT_TITLE="" _YT_AUTHOR="" _YT_DATE=""
_yt_fetch_metadata() {
  _YT_TITLE=""; _YT_AUTHOR=""; _YT_DATE=""
  command -v yt-dlp >/dev/null 2>&1 || return 0
  local meta
  meta="$(yt-dlp --no-warnings --skip-download \
            --print '%(title)s\t%(uploader)s\t%(upload_date)s' "$1" 2>/dev/null | head -1 || true)"
  [ -n "$meta" ] || return 0
  _YT_TITLE="$(printf '%s' "$meta" | cut -f1)"
  _YT_AUTHOR="$(printf '%s' "$meta" | cut -f2)"
  _YT_DATE="$(printf '%s' "$meta" | cut -f3)"
}

# Print a plain-text transcript (auto-captions) via yt-dlp, or nothing.
_yt_fetch_transcript() {
  command -v yt-dlp >/dev/null 2>&1 || return 0
  local url="$1" tmp vtt
  tmp="$(mktemp -d)" || return 0
  yt-dlp --no-warnings --skip-download --write-auto-subs --write-subs \
         --sub-langs 'en.*' --sub-format vtt -o "$tmp/sub" "$url" >/dev/null 2>&1 || true
  vtt="$(find "$tmp" -name '*.vtt' 2>/dev/null | head -1)"
  if [ -n "$vtt" ]; then
    sed -E '/-->/d; /^WEBVTT/d; /^NOTE/d; /^[0-9]+$/d; s/<[^>]*>//g' "$vtt" \
      | sed '/^[[:space:]]*$/d' | awk '!seen[$0]++'
  fi
  rm -rf "$tmp"
}

yt_note() {
  ensure_dirs
  parse_tag_flag "$@"
  local url="${_REMAINING_ARGS[0]:-}"
  [ -n "$url" ] || { echo "YouTube URL required" >&2; exit 1; }

  case "$url" in
    *youtube.com/*|*youtu.be/*) ;;
    *) echo "Not a YouTube URL: $url" >&2; exit 1 ;;
  esac

  local vid; vid="$(_youtube_id "$url")" || exit 1

  # You handed it a URL, so offer to pull the info down — but only when we can
  # (yt-dlp present) and won't hang a script (interactive stdin). Declining or a
  # missing tool leaves a clean offline scaffold.
  local transcript=""
  if command -v yt-dlp >/dev/null 2>&1 && [ -t 0 ]; then
    printf 'Fetch title + transcript from YouTube now? [y/N] ' >&2
    local reply; read -r reply
    case "$reply" in
      [Yy]*)
        _yt_fetch_metadata "$url"
        transcript="$(_yt_fetch_transcript "$url")"
        ;;
    esac
  fi

  local title="${_YT_TITLE}"
  [ -n "$title" ] || title="YouTube ${vid}"

  local pub_date=""
  [ -n "$_YT_DATE" ] && pub_date="${_YT_DATE:0:4}-${_YT_DATE:4:2}-${_YT_DATE:6:2}"

  local slug; slug="$(slugify "$title")" || exit 1
  local file rel
  file="$VAULT/$NOTES_DIR/$(date +%F)-${slug}.md"
  rel="${file#"$VAULT"/}"

  if [ ! -f "$file" ]; then
    local safe_title safe_author tags_yaml
    safe_title="$(yaml_escape_dq "$title")"
    safe_author="$(yaml_escape_dq "${_YT_AUTHOR}")"
    tags_yaml="$(_tags_yaml "source/youtube")"
    # vid is validated [A-Za-z0-9_-]{11}; source_url is rebuilt canonically rather
    # than echoing the raw URL, so no untrusted query string enters the heredoc.
    cat > "$file" <<EOF
---
title: "${safe_title}"
source_type: youtube
source_url: "https://www.youtube.com/watch?v=${vid}"
video_id: "${vid}"
author: "${safe_author}"
publish_date: ${pub_date}
captured_date: $(date +%F)
captured_via: okm-yt
tags: ${tags_yaml}
---

# ${title}

## Summary

<!-- short sentences, bullets over paragraphs, numbers over prose -->

-

## Actionable Insights

-

## Key Quotes

> [MM:SS] "..."

## Transcript

EOF
    if [ -n "$transcript" ]; then
      printf '%s\n' "$transcript" >> "$file"
    else
      printf '%s\n' "<!-- okm yt fills this when yt-dlp is installed and you opt in; otherwise paste it here -->" >> "$file"
    fi
    echo "Created: $rel"
  else
    echo "Exists: $rel"
  fi
  exec "$EDITOR_CMD" "$file"
}

# okm pod <audio-file> "Title" [-t tag1,tag2]
# Transcribe a local audio/video file with whisperX and create a dated note.
pod_note() {
  ensure_dirs
  parse_tag_flag "$@"
  local audio_file="${_REMAINING_ARGS[0]:-}"
  local title="${_REMAINING_ARGS[*]:1}"
  [ -n "$audio_file" ] || { echo "Audio file required" >&2; exit 1; }
  [ -f "$audio_file" ] || { echo "File not found: $audio_file" >&2; exit 1; }
  [ -n "$title" ] || title="$(basename "${audio_file%.*}")"

  local slug; slug="$(slugify "$title")" || exit 1
  local file="$VAULT/$NOTES_DIR/$(date +%F)-${slug}.md"
  local rel="${file#"$VAULT"/}"

  local safe_title; safe_title="$(yaml_escape_dq "$title")"
  local tags_yaml; tags_yaml="$(_tags_yaml "source/podcast")"

  local transcript=""
  if command -v whisperx >/dev/null 2>&1 || command -v whisper >/dev/null 2>&1; then
    local whisper_cmd
    whisper_cmd="$(command -v whisperx 2>/dev/null || command -v whisper)"
    local tmp_dir; tmp_dir="$(mktemp -d)"
    local model="${WHISPER_MODEL:-large-v3-turbo}"
    "$whisper_cmd" "$audio_file" --model "$model" --output_dir "$tmp_dir" \
      --output_format txt >/dev/null 2>&1 || true
    local txt_out; txt_out="$(find "$tmp_dir" -name '*.txt' | head -1)"
    [ -n "$txt_out" ] && transcript="$(cat "$txt_out")"
    # No EXIT trap: this function ends with exec, which would skip it anyway.
    rm -rf "$tmp_dir"
  else
    echo "okm pod: whisperX/whisper not installed — transcript will be empty. Install via venv: pip install whisperx" >&2
  fi

  if [ ! -f "$file" ]; then
    cat > "$file" <<EOF
---
title: "${safe_title}"
source_type: local-audio
source_file: "$(basename "$audio_file")"
created: $(iso_now)
captured_date: $(date +%F)
captured_via: okm-pod
tags: ${tags_yaml}
---

# ${title}

## Summary

<!-- short sentences, bullets over paragraphs -->

-

## Actionable Insights

-

## Key Quotes

> [MM:SS] "..."

## Transcript

EOF
    if [ -n "$transcript" ]; then
      printf '%s\n' "$transcript" >> "$file"
    else
      printf '%s\n' "<!-- paste or run whisperX to fill this in -->" >> "$file"
    fi
    echo "Created: $rel"
  else
    echo "Exists: $rel"
  fi
  exec "$EDITOR_CMD" "$file"
}

# okm distill <note> [--model claude|ollama]
# Summarize a note using Claude or Ollama. Writes a distilled version alongside.
distill_note() {
  local note="" model="${DISTILL_MODEL:-claude}"
  while [ $# -gt 0 ]; do
    case "$1" in
      --model)
        [ $# -ge 2 ] || { echo "okm distill: --model requires a value" >&2; exit 1; }
        model="$2"; shift ;;
      *) note="$1" ;;
    esac
    shift
  done
  [ -n "$note" ] || { echo "Note required" >&2; exit 1; }

  local file; file="$(resolve_note "$note")"
  local base="${file%.md}"
  local out="${base}-distilled.md"

  if [ -f "$out" ]; then
    echo "Distilled note already exists: ${out#"$VAULT"/}"
    exec "$EDITOR_CMD" "$out"
  fi

  local content; content="$(cat "$file")"

  local prompt="Summarize this note in concise bullet points. Focus on key insights and actionable takeaways. Output plain Markdown."
  local summary=""
  case "$model" in
    claude)
      if ! command -v claude >/dev/null 2>&1; then
        echo "okm distill: 'claude' CLI not found. Install Claude Code or set DISTILL_MODEL=ollama." >&2
        exit 1
      fi
      summary="$(printf '%s\n' "$content" | claude --print "$prompt" 2>/dev/null || true)"
      ;;
    ollama)
      if ! command -v ollama >/dev/null 2>&1; then
        echo "okm distill: 'ollama' not found. Install ollama or set DISTILL_MODEL=claude." >&2
        exit 1
      fi
      summary="$(printf '%s\n' "$content" | ollama run "${OLLAMA_MODEL:-llama3}" "$prompt" 2>/dev/null || true)"
      ;;
    *)
      echo "okm distill: unknown model '$model'. Use --model claude or --model ollama." >&2
      exit 1 ;;
  esac

  local safe_title; safe_title="$(yaml_escape_dq "$(basename "${file%.md}")")"
  cat > "$out" <<EOF
---
title: "Distilled: ${safe_title}"
source_note: "${file#"$VAULT"/}"
distilled_by: ${model}
created: $(iso_now)
tags: [distilled, automated]
---

# Distilled: ${safe_title}

${summary:-<!-- distillation failed — check model configuration -->}
EOF
  echo "Created: ${out#"$VAULT"/}"
  exec "$EDITOR_CMD" "$out"
}
