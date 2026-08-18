#!/usr/bin/env bash
# media.sh — okm media-ingest commands: pod, video, distill.
#
# Sourced by bin/okm (not executable on its own). Uses bin/okm helpers
# (ensure_dirs, parse_tag_flag, slugify, yaml_escape_dq, _tags_yaml, iso_now,
# resolve_note) and globals (VAULT, NOTES_DIR, EDITOR_CMD, _REMAINING_ARGS).
#
# Design principle (do NOT change without discussion): we PULL transcripts and
# metadata that already exist at the source — RSS <podcast:transcript>, YouTube
# caption tracks, or a local transcript file. We never transcribe audio
# ourselves: whisperX / ASR is intentionally out of scope. If a source exposes
# no transcript, the note is scaffolded and left for the human/loom agent.
#
# Filename convention (both commands):
#   {format}-{Channel}-{Title}[-{episode}]-{YYYY-MM-DD}.md
#   - format   : "podcast" (okm pod) or "video" (okm video)
#   - Channel  : show/uploader name, PascalCase (omitted if unknown)
#   - Title    : episode/video title, PascalCase
#   - episode  : itunes:episode number, digits only (omitted if unknown)
#   - date     : ISO publish date; sorts chronologically

# Resolve the python3 interpreter: prefer the project venv so optional deps
# (youtube_transcript_api) are found even when env.sh hasn't been sourced.
_python3() {
  local venv_py="${OKM_SCRIPT_DIR}/venv/bin/python3"
  if [ -x "$venv_py" ]; then
    "$venv_py" "$@"
  else
    python3 "$@"
  fi
}

# PascalCase a free-text field for use as one filename segment: transliterate
# "&" to "and", drop apostrophes, split on any non-alphanumeric run, capitalise
# the first letter of each token, and concatenate. Caps length so a single long
# title can't blow past filesystem limits (N18-style guard).
pascal_field() {
  local out
  out="$(printf '%s' "$1" \
    | tr '\n\r\t' '   ' \
    | sed -E "s/&/ and /g; s/'//g" \
    | sed -E 's/[^A-Za-z0-9]+/ /g' \
    | awk '{ s=""; for (i=1;i<=NF;i++) s = s toupper(substr($i,1,1)) substr($i,2); print s }')"
  # Cap a single field at 80 chars so the whole name stays well under 200.
  printf '%s' "${out:0:80}"
}

# Build the note filename (without directory) from the resolved metadata.
# Args: format channel title episode date
_media_filename() {
  local fmt="$1" channel="$2" title="$3" episode="$4" date="$5"
  local parts="$fmt"
  [ -n "$channel" ] && parts="${parts}-$(pascal_field "$channel")"
  parts="${parts}-$(pascal_field "$title")"
  [ -n "$episode" ] && parts="${parts}-${episode}"
  [ -n "$date" ] && parts="${parts}-${date}"
  printf '%s' "$parts"
}

# Return 0 if the note already has real transcript text under its
# "## Transcript" heading, 1 otherwise. HTML-comment placeholders (the "no
# captions available" scaffold) count as empty — so a stale scaffold is
# treated as missing a transcript and can be back-filled on a later run.
_note_has_transcript() {
  _python3 - "$1" <<'PYEOF'
import re, sys
try:
    text = open(sys.argv[1], encoding="utf-8").read()
except OSError:
    sys.exit(1)
m = re.search(r'(?im)^##[ \t]+Transcript[ \t]*$', text)
if not m:
    sys.exit(1)
body = re.sub(r'<!--.*?-->', '', text[m.end():], flags=re.S).strip()
sys.exit(0 if body else 1)
PYEOF
}

# Replace whatever sits under the note's "## Transcript" heading with the given
# transcript, preserving any sections that follow it. The transcript is passed
# via the environment so newlines and length are never a shell concern.
_note_set_transcript() {
  local file="$1" transcript="$2"
  OKM_TRANSCRIPT="$transcript" _python3 - "$file" <<'PYEOF'
import os, re, sys
path = sys.argv[1]
body = os.environ.get("OKM_TRANSCRIPT", "").rstrip("\n")
text = open(path, encoding="utf-8").read()
m = re.search(r'(?im)^##[ \t]+Transcript[ \t]*$', text)
if not m:
    text = text.rstrip("\n") + "\n\n## Transcript\n\n" + body + "\n"
else:
    rest = text[m.end():]
    nxt = re.search(r'(?m)^##[ \t]+', rest)          # next H2 after Transcript
    tail = ("\n\n" + rest[nxt.start():].rstrip("\n") + "\n") if nxt else "\n"
    text = text[:m.end()] + "\n\n" + body + tail
with open(path, "w", encoding="utf-8") as f:
    f.write(text)
PYEOF
}

# ---------------------------------------------------------------------------
# okm pod — podcast capture from a link (Spotify / Apple / RSS / page) or file.
# ---------------------------------------------------------------------------

# Resolve a podcast link to a single episode's metadata + transcript and print
# it as one JSON object, or print nothing on failure. All network access lives
# here so the rest of the command stays testable. Test hooks:
#   OKM_POD_OFFLINE=1        — skip all network, print nothing (forces fallback)
#   OKM_POD_FEED_FILE=<path> — parse this local RSS file instead of fetching
#   OKM_POD_EPISODE_MATCH=<s>— select the item whose title contains <s>
_pod_meta_json() {
  [ "${OKM_POD_OFFLINE:-0}" = "1" ] && return 1
  _python3 - "$1" <<'PYEOF'
import json, os, re, sys, urllib.request, urllib.parse
import xml.etree.ElementTree as ET
from email.utils import parsedate_to_datetime

UA = "Mozilla/5.0 (okm podcast fetcher)"
SOURCE = sys.argv[1]

def get(url, headers=None):
    h = {"User-Agent": UA}
    if headers:
        h.update(headers)
    req = urllib.request.Request(url, headers=h)
    with urllib.request.urlopen(req, timeout=25) as r:
        return r.read().decode("utf-8", "replace")

def norm(s):
    return re.sub(r"[^a-z0-9]+", "", (s or "").lower())

def itunes_search_feed(show_name):
    q = urllib.parse.urlencode({"term": show_name, "entity": "podcast", "limit": 5})
    data = json.loads(get("https://itunes.apple.com/search?" + q))
    tgt = norm(show_name)
    for r in data.get("results", []):
        if r.get("feedUrl") and (norm(r.get("collectionName")) == tgt or not tgt):
            return r["feedUrl"]
    for r in data.get("results", []):
        if r.get("feedUrl"):
            return r["feedUrl"]
    return None

def itunes_lookup(id_):
    data = json.loads(get("https://itunes.apple.com/lookup?id=%s" % id_))
    return data.get("results", [])

# --- Resolve (feed_url, episode_title_hint) from the source URL ---------------
feed_url, ep_hint = None, os.environ.get("OKM_POD_EPISODE_MATCH", "")

feed_file = os.environ.get("OKM_POD_FEED_FILE")
if feed_file:
    feed_xml = open(feed_file, encoding="utf-8").read()
else:
    try:
        if "open.spotify.com" in SOURCE and "/episode/" in SOURCE:
            m = re.search(r"/episode/([A-Za-z0-9]+)", SOURCE)
            emb = get("https://open.spotify.com/embed/episode/%s" % m.group(1))
            j = re.search(r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>', emb, re.S)
            ent = json.loads(j.group(1))["props"]["pageProps"]["state"]["data"]["entity"]
            ep_hint = ent.get("name") or ep_hint
            feed_url = itunes_search_feed(ent.get("subtitle") or "")
        elif "podcasts.apple.com" in SOURCE:
            cid = re.search(r"/id(\d+)", SOURCE)
            eid = re.search(r"[?&]i=(\d+)", SOURCE)
            if eid:
                for r in itunes_lookup(eid.group(1)):
                    if r.get("kind") == "podcast-episode":
                        ep_hint = r.get("trackName") or ep_hint
                        feed_url = r.get("feedUrl") or feed_url
            if not feed_url and cid:
                for r in itunes_lookup(cid.group(1)):
                    if r.get("feedUrl"):
                        feed_url = r["feedUrl"]; break
        elif re.search(r"\.(xml|rss)(\?|$)", SOURCE) or "feeds." in SOURCE:
            feed_url = SOURCE
        else:
            parsed = urllib.parse.urlparse(SOURCE)
            slug = parsed.path.rstrip("/").split("/")[-1]
            try:
                page = get(SOURCE)
            except Exception:
                page = ""
            lm = re.search(r'<link[^>]+type="application/rss\+xml"[^>]+href="([^"]+)"', page) \
                 or re.search(r'<link[^>]+href="([^"]+)"[^>]+type="application/rss\+xml"', page)
            if lm:
                feed_url = lm.group(1)
            else:
                # JS-only host pages (Simplecast/Transistor/Buzzsprout/etc.) expose
                # no metadata server-side. Derive the show from the subdomain and
                # find its feed via iTunes; match the episode by the URL slug.
                sub = parsed.netloc.split(".")[0]
                if sub and sub not in ("www", "feeds", "feed", "rss", "open",
                                       "podcasts", "player", "pca", "pod", "api"):
                    feed_url = itunes_search_feed(sub.replace("-", " "))
            if not ep_hint:
                tm = re.search(r"<title>(.*?)</title>", page, re.S)
                if tm:
                    ep_hint = re.sub(r"\s+", " ", tm.group(1)).strip()
                elif slug:
                    ep_hint = slug.replace("-", " ")
    except Exception:
        pass
    if not feed_url:
        sys.exit(1)
    feed_xml = get(feed_url)

# --- Parse the feed and select the episode -----------------------------------
try:
    root = ET.fromstring(feed_xml.encode("utf-8"))
except Exception:
    sys.exit(1)

ns = {
    "itunes": "http://www.itunes.com/dtds/podcast-1.0.dtd",
    "podcast": "https://podcastindex.org/namespace/1.0",
}
channel = root.find("channel")
if channel is None:
    sys.exit(1)

def chan_title():
    t = channel.findtext("title") or ""
    a = channel.findtext("itunes:author", default="", namespaces=ns)
    return t or a

items = channel.findall("item")
if not items:
    sys.exit(1)

chosen = None
if ep_hint:
    h = norm(ep_hint)
    for it in items:
        if norm(it.findtext("title")) == h:
            chosen = it; break
    if chosen is None:
        for it in items:
            t = norm(it.findtext("title"))
            if h and (h in t or t in h):
                chosen = it; break
if chosen is None:
    chosen = items[0]  # latest

def txt(el, path, nsp=None):
    return (el.findtext(path, default="", namespaces=nsp) or "").strip()

title = txt(chosen, "title")
episode = txt(chosen, "itunes:episode", ns)
episode = episode if episode.isdigit() else ""

date = ""
pub = txt(chosen, "pubDate")
if pub:
    try:
        date = parsedate_to_datetime(pub).strftime("%Y-%m-%d")
    except Exception:
        date = ""

enclosure, enc_type = "", ""
enc = chosen.find("enclosure")
if enc is not None:
    enclosure = enc.get("url", "")
    enc_type = enc.get("type", "")

tr_url, tr_type = "", ""
for tr in chosen.findall("podcast:transcript", ns):
    ty = (tr.get("type") or "").lower()
    tr_url = tr.get("url", ""); tr_type = ty
    if "vtt" in ty or "srt" in ty or "json" in ty:
        break  # prefer a time-aligned format

print(json.dumps({
    "channel": chan_title(),
    "title": title,
    "episode": episode,
    "date": date,
    "enclosure": enclosure,
    "enclosure_type": enc_type,
    "transcript_url": tr_url,
    "transcript_type": tr_type,
}))
PYEOF
}

# Fetch a transcript URL and render it as timestamped lines. Supports VTT, SRT,
# Podcast Index JSON, and plain text/HTML. Prints nothing on failure.
# Test hook: OKM_POD_TRANSCRIPT_FILE overrides the URL with a local file.
_pod_fetch_transcript() {
  local url="$1" type="$2"
  _python3 - "$url" "$type" <<'PYEOF'
import os, re, sys, json, html, urllib.request

url, ttype = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else "").lower()
override = os.environ.get("OKM_POD_TRANSCRIPT_FILE")

def stamp(sec):
    sec = int(sec); h, rem = divmod(sec, 3600); m, s = divmod(rem, 60)
    return "%02d:%02d:%02d" % (h, m, s) if h else "%02d:%02d" % (m, s)

try:
    if override:
        raw = open(override, encoding="utf-8").read()
    elif os.path.exists(url):
        raw = open(url, encoding="utf-8").read()
    else:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (okm)"})
        raw = urllib.request.urlopen(req, timeout=25).read().decode("utf-8", "replace")
except Exception:
    sys.exit(1)

out = []
looks_json = "json" in ttype or raw.lstrip().startswith("{")
if looks_json:
    try:
        data = json.loads(raw)
        segs = data.get("segments", data if isinstance(data, list) else [])
        for s in segs:
            t = s.get("startTime", s.get("start"))
            body = (s.get("body") or s.get("text") or "").strip()
            if body:
                out.append("[%s] %s" % (stamp(t), body) if t is not None else body)
    except Exception:
        out = []

if not out and ("vtt" in ttype or "srt" in ttype or "-->" in raw):
    def to_sec(ts):
        parts = [float(p.replace(",", ".")) for p in ts.split(":")]
        while len(parts) < 3:
            parts.insert(0, 0.0)
        return parts[0] * 3600 + parts[1] * 60 + parts[2]
    cur, buf = None, []
    for line in raw.splitlines():
        line = line.strip()
        if line == "WEBVTT" or line.isdigit():
            continue
        m = re.match(r"(\d{1,2}:\d{2}(?::\d{2})?[.,]\d+)\s*-->", line)
        if m:
            if cur is not None and buf:
                out.append("[%s] %s" % (cur, " ".join(buf)))
            cur, buf = stamp(to_sec(m.group(1))), []
            continue
        if line and cur is not None:
            buf.append(re.sub(r"<[^>]+>", "", line))
    if cur is not None and buf:
        out.append("[%s] %s" % (cur, " ".join(buf)))

if not out:  # plain text or HTML
    text = re.sub(r"<[^>]+>", " ", raw)
    text = html.unescape(re.sub(r"\s+\n", "\n", text)).strip()
    if text:
        out = [text]

if not out:
    sys.exit(1)
print("\n".join(out))
PYEOF
}

# Given a local file, return "transcript" if it is a recognised transcript
# format we can import verbatim, else "media".
_pod_local_kind() {
  case "${1,,}" in
    *.srt|*.vtt|*.txt|*.json) echo "transcript" ;;
    *) echo "media" ;;
  esac
}

pod_note() {
  ensure_dirs
  parse_tag_flag "$@"
  local src="${_REMAINING_ARGS[0]:-}"
  [ -n "$src" ] || { echo "Podcast link or file required" >&2; exit 1; }

  local fmt="podcast" platform="" source_url="" source_file=""
  local channel="" title="" episode="" date="" enclosure="" transcript=""

  if [ -f "$src" ]; then
    # Local file: import a transcript verbatim, or scaffold for raw media.
    platform="local"; source_file="$(basename "$src")"
    title="${_REMAINING_ARGS[*]:1}"
    [ -n "$title" ] || title="$(basename "${src%.*}")"
    date="$(date +%F)"
    if [ "$(_pod_local_kind "$src")" = "transcript" ]; then
      transcript="$(_pod_fetch_transcript "$src" "${src##*.}" || true)"
    fi
  else
    case "$src" in
      *youtube.com/*|*youtu.be/*)
        echo "okm pod: that's a YouTube link — use 'okm video $src' for videos/lectures." >&2
        exit 1 ;;
    esac
    case "$src" in
      http://*|https://*|spotify:*) ;;
      *) echo "Not a link or a readable file: $src" >&2; exit 1 ;;
    esac
    source_url="$src"
    case "$src" in
      *open.spotify.com*|spotify:*) platform="spotify" ;;
      *podcasts.apple.com*)         platform="apple" ;;
      *)                            platform="rss" ;;
    esac
    local meta; meta="$(_pod_meta_json "$src" || true)"
    if [ -n "$meta" ]; then
      channel="$(printf '%s' "$meta" | _json_get channel)"
      title="$(printf '%s' "$meta" | _json_get title)"
      episode="$(printf '%s' "$meta" | _json_get episode)"
      date="$(printf '%s' "$meta" | _json_get date)"
      enclosure="$(printf '%s' "$meta" | _json_get enclosure)"
      local tr_url tr_type
      tr_url="$(printf '%s' "$meta" | _json_get transcript_url)"
      tr_type="$(printf '%s' "$meta" | _json_get transcript_type)"
      [ -n "$tr_url" ] && transcript="$(_pod_fetch_transcript "$tr_url" "$tr_type" || true)"
    fi
    # Graceful degradation: no metadata (offline / unresolved) → scaffold with
    # a deterministic id-based name rather than failing.
    if [ -z "$title" ]; then
      echo "okm pod: could not fetch episode metadata over the network (offline or source blocked) — wrote an offline scaffold." >&2
      # Fallback title from the URL's last path segment (unique per episode),
      # e.g. .../episodes/riva-tez -> "riva tez" -> RivaTez.
      local seg
      seg="$(printf '%s' "$src" | sed -E 's#[?#].*$##; s#/+$##; s#.*/##' | head -c 40)"
      seg="${seg//-/ }"
      title="${seg:-podcast episode}"
      date="${date:-$(date +%F)}"
    fi
  fi

  local name file rel
  name="$(_media_filename "$fmt" "$channel" "$title" "$episode" "$date")"
  file="$VAULT/$NOTES_DIR/${name}.md"
  rel="${file#"$VAULT"/}"

  if [ -f "$file" ]; then
    # The note already exists. Only short-circuit if it already carries a
    # transcript; a stale scaffold (placeholder only) gets back-filled when a
    # transcript is now reachable, so re-running finishes what a blocked or
    # caption-less first run left undone.
    if _note_has_transcript "$file"; then
      echo "Exists: $rel"
    elif [ -n "$transcript" ]; then
      _note_set_transcript "$file" "$transcript"
      echo "Filled transcript: $rel"
    else
      echo "Exists: $rel (no transcript available — source has none or fetch was blocked)"
    fi
    exec "$EDITOR_CMD" "$file"
  fi

  local safe_title safe_channel tags_yaml
  safe_title="$(yaml_escape_dq "$title")"
  safe_channel="$(yaml_escape_dq "$channel")"
  tags_yaml="$(_tags_yaml "source/podcast")"

  {
    printf -- '---\n'
    printf 'title: "%s"\n' "$safe_title"
    printf 'source_type: podcast\n'
    printf 'source_platform: %s\n' "$platform"
    [ -n "$source_url" ]  && printf 'source_url: "%s"\n' "$source_url"
    [ -n "$source_file" ] && printf 'source_file: "%s"\n' "$source_file"
    [ -n "$safe_channel" ] && printf 'show: "%s"\n' "$safe_channel"
    [ -n "$episode" ]     && printf 'episode: %s\n' "$episode"
    [ -n "$date" ]        && printf 'publish_date: %s\n' "$date"
    [ -n "$enclosure" ]   && printf 'audio_url: "%s"\n' "$enclosure"
    printf 'captured_date: %s\n' "$(date +%F)"
    printf 'captured_via: okm-pod\n'
    printf 'tags: %s\n' "$tags_yaml"
    printf -- '---\n\n'
    printf '# %s\n\n' "$title"
    [ -n "$source_url" ] && printf '## Player\n\n[Open episode](<%s>)\n\n' "$source_url"
    cat <<'BODY'
## Summary

<!-- caveman speech: short sentences, no filler, bullets over paragraphs -->

-

## Actionable Insights

## Sources Cited

## Follow-ups

- [ ]

## Key Quotes

> [MM:SS] "..."

## Transcript

BODY
    if [ -n "$transcript" ]; then
      printf '%s\n' "$transcript"
    else
      printf '%s\n' "<!-- No transcript published at the source. okm pulls existing transcripts (RSS <podcast:transcript> or YouTube captions) only — it does not transcribe audio. Paste one here or fill by hand. -->"
    fi
  } > "$file"

  echo "Created: $rel"
  exec "$EDITOR_CMD" "$file"
}

# Minimal JSON string/number field reader (stdin JSON, key as $1). Avoids a hard
# jq dependency; values are simple (no nested objects, no escaped quotes here).
_json_get() {
  _python3 -c 'import json,sys; print(json.load(sys.stdin).get(sys.argv[1],""))' "$1" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# okm video — video capture from a link (YouTube) or file.
# ---------------------------------------------------------------------------

# Extract and validate an 11-char YouTube video ID from common URL forms.
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
# Graceful no-op offline or without yt-dlp.
_YT_TITLE="" _YT_AUTHOR="" _YT_DATE=""
_yt_fetch_metadata() {
  _YT_TITLE=""; _YT_AUTHOR=""; _YT_DATE=""
  command -v yt-dlp >/dev/null 2>&1 || return 0
  local raw
  raw="$(yt-dlp --no-warnings --skip-download --dump-json "$1" 2>/dev/null | head -1 || true)"
  [ -n "$raw" ] || return 0
  local parsed
  parsed="$(printf '%s' "$raw" | _python3 -c '
import json, sys
d = json.load(sys.stdin)
print(d.get("title", ""), d.get("uploader", ""), d.get("upload_date", ""), sep="\n")
' 2>/dev/null || true)"
  [ -n "$parsed" ] || return 0
  _YT_TITLE="$(printf '%s' "$parsed" | sed -n '1p')"
  _YT_AUTHOR="$(printf '%s' "$parsed" | sed -n '2p')"
  _YT_DATE="$(printf '%s'  "$parsed" | sed -n '3p')"
}

# Print a timestamped transcript via youtube_transcript_api, or nothing.
_yt_fetch_transcript() {
  local vid="$1"
  _python3 - "$vid" 2>/dev/null <<'PYEOF'
import sys
from youtube_transcript_api import YouTubeTranscriptApi, NoTranscriptFound

vid = sys.argv[1]
try:
    ytt = YouTubeTranscriptApi()
    try:
        transcript_list = ytt.list(vid)
        try:
            t = transcript_list.find_transcript(['en', 'en-US', 'en-GB'])
        except NoTranscriptFound:
            t = next(iter(transcript_list))
        segs = list(t.fetch())
    except Exception:
        segs = list(ytt.fetch(vid))
    for s in segs:
        start = int(s.start)
        mm, ss = divmod(start, 60)
        hh, mm = divmod(mm, 60)
        stamp = f"{hh:02d}:{mm:02d}:{ss:02d}" if hh else f"{mm:02d}:{ss:02d}"
        print(f"[{stamp}] {s.text}")
except Exception:
    sys.exit(1)
PYEOF
}

video_note() {
  ensure_dirs
  parse_tag_flag "$@"
  local src="${_REMAINING_ARGS[0]:-}"
  [ -n "$src" ] || { echo "Video link or file required" >&2; exit 1; }

  local fmt="video" platform="" source_url="" source_file=""
  local channel="" title="" date="" transcript="" vid=""

  if [ -f "$src" ]; then
    platform="local"; source_file="$(basename "$src")"
    title="${_REMAINING_ARGS[*]:1}"
    [ -n "$title" ] || title="$(basename "${src%.*}")"
    date="$(date +%F)"
  else
    case "$src" in
      *youtube.com/*|*youtu.be/*) ;;
      *) echo "Not a supported video link or a readable file: $src" >&2; exit 1 ;;
    esac
    platform="youtube"; source_url="$src"
    vid="$(_youtube_id "$src")" || exit 1
    _yt_fetch_metadata "$src"
    if _python3 -c "import youtube_transcript_api" 2>/dev/null; then
      transcript="$(_yt_fetch_transcript "$vid")" || true
    fi
    title="${_YT_TITLE}"
    channel="${_YT_AUTHOR}"
    [ -n "$title" ] || title="YouTube ${vid}"
    if [ -n "$_YT_DATE" ] && [[ "$_YT_DATE" =~ ^[0-9]{8}$ ]]; then
      date="${_YT_DATE:0:4}-${_YT_DATE:4:2}-${_YT_DATE:6:2}"
    else
      date="$(date +%F)"
    fi
    source_url="https://www.youtube.com/watch?v=${vid}"
  fi

  local name file rel
  name="$(_media_filename "$fmt" "$channel" "$title" "" "$date")"
  file="$VAULT/$NOTES_DIR/${name}.md"
  rel="${file#"$VAULT"/}"

  if [ -f "$file" ]; then
    # The note already exists. Only short-circuit if it already carries a
    # transcript; a stale scaffold (placeholder only) gets back-filled when a
    # transcript is now reachable, so re-running finishes what a blocked or
    # caption-less first run left undone.
    if _note_has_transcript "$file"; then
      echo "Exists: $rel"
    elif [ -n "$transcript" ]; then
      _note_set_transcript "$file" "$transcript"
      echo "Filled transcript: $rel"
    else
      echo "Exists: $rel (no transcript available — source has none or fetch was blocked)"
    fi
    exec "$EDITOR_CMD" "$file"
  fi

  local safe_title safe_channel tags_yaml
  safe_title="$(yaml_escape_dq "$title")"
  safe_channel="$(yaml_escape_dq "$channel")"
  tags_yaml="$(_tags_yaml "source/youtube")"

  {
    printf -- '---\n'
    printf 'title: "%s"\n' "$safe_title"
    printf 'source_type: video\n'
    printf 'source_platform: %s\n' "$platform"
    [ -n "$source_url" ]   && printf 'source_url: "%s"\n' "$source_url"
    [ -n "$source_file" ]  && printf 'source_file: "%s"\n' "$source_file"
    [ -n "$vid" ]          && printf 'video_id: "%s"\n' "$vid"
    [ -n "$safe_channel" ] && printf 'channel: "%s"\n' "$safe_channel"
    [ -n "$date" ]         && printf 'publish_date: %s\n' "$date"
    printf 'captured_date: %s\n' "$(date +%F)"
    printf 'captured_via: okm-video\n'
    printf 'tags: %s\n' "$tags_yaml"
    printf -- '---\n\n'
    printf '# %s\n\n' "$title"
    cat <<'BODY'
## Summary

<!-- short sentences, bullets over paragraphs, numbers over prose -->

-

## Actionable Insights

-

## Key Quotes

> [MM:SS] "..."

## Transcript

BODY
    if [ -n "$transcript" ]; then
      printf '%s\n' "$transcript"
    else
      printf '%s\n' "<!-- No captions available at the source. okm pulls existing transcripts (YouTube captions via youtube-transcript-api) only — it does not transcribe audio. -->"
    fi
  } > "$file"

  echo "Created: $rel"
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
