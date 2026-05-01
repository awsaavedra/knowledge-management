# Skill: Distill Prompt Spec

Reference for the future `okm distill` command. Covers what a "good" distillation looks like — well beyond a bullet-point recap.

## What distill must produce

When given a transcript-bearing note (YouTube, podcast, Spotify episode), the distill prompt must populate **four** sections in the existing template, not just `## Summary`:

1. `## Summary` — 3–5 caveman bullets of the core takeaways.
2. `## Actionable Insights` — verb-led bullets pointing at concrete next steps with URLs where possible.
3. `## Sources Cited` — every external reference (book, paper, tool, URL) the speakers mention, formatted: `Title — Author — URL/DOI/ISBN`.
4. `## Follow-ups` — checkbox list of open questions, contradictions, or topics to investigate.

It must also extract `## Key Quotes` with timestamps (audio-only) or pair them with screenshots (video).

## Required prompt structure (Claude or Ollama)

```
SYSTEM:
You are a research analyst. Read the transcript and produce four lists,
in this order: Summary, Actionable Insights, Sources Cited, Follow-ups.
Style: caveman speech. Short sentences. No filler. Numbers over prose.

CONSTRAINTS (hard requirements):
- Cite every external reference the speakers mention. Books, papers, URLs,
  tools, datasets. Format: "Title — Author — URL/ISBN/DOI". If a reference
  is mentioned without enough info to identify it, list it as "[unverified] <name>".
- Actionable Insights must contain a verb and either a URL or a concrete
  next step. "Read more about X" is not actionable. "Build openclaw on mac
  mini using https://example.com/tutorial" is.
- Follow-ups must be checkboxes (`- [ ]`) so they can be scanned by
  scripts/todo-summary.sh.
- Surface contradictions explicitly under Follow-ups: "[ ] Speaker A says X
  but the cited paper says Y — resolve."
- Do not paraphrase quotes. If you include a quote, mark it as quote and
  preserve the timestamp from the transcript.
- Do not invent timestamps. If you cannot tie a claim to a transcript
  position, omit the timestamp; do not fabricate.

USER:
<transcript with [HH:MM:SS] [SPEAKER_NN] line prefixes>
```

## Why "beyond summarization"

Bullet recap is what every other tool does. The unique value of these notes is:
- **Actionability** — the user wants to *do* something with the content, not just remember it.
- **Citations** — the user wants to follow up on the sources, not just consume the speaker's framing.
- **Tension** — speakers contradict themselves, contradict cited research, and leave questions hanging. Surfacing those is more valuable than smoothing them over.

Plain summary models lose all three. The distill prompt must explicitly scaffold them.

## Backends

- `okm distill <note>` — Claude (default; better at extracting subtle citations, identifying contradictions).
- `okm distill --local <note>` — Ollama (offline-first; lower-quality citations but no network dependency).

Use the same prompt for both; only the API client differs. If Ollama hallucinates citations more than Claude in practice, add a post-validation step (`grep -F` against the transcript for each cited URL) before writing back to the note.

## Anti-patterns

- Letting the model rewrite the Summary section if the user already filled it in. Treat existing content as read-only; only add to empty sections.
- Producing a single mega-bullet list dumped into Summary. Use the four required sections.
- Citing sources that aren't in the transcript. If the model "knows" a paper but the speakers didn't reference it, that's hallucination — drop it.
- Compressing transcripts before passing to the model. Use prompt caching or chunked inference, not lossy summarization upstream.

## Reference: see also

- `_skills/transcripts.md` — what the input looks like.
- `inbox/templates/yt-template.md`, `spotify-episode-template.md`, `podcast-template.md` — the destination templates with all four sections.
