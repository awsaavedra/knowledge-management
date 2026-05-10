<!--
Format Specification: podcast-template
Required frontmatter: title, source_type=podcast, source_file, author, created, tags
Required sections: File, Summary, Actionable Insights, Sources Cited, Follow-ups, Structured Data, Key Quotes (REQUIRED — audio-only equivalent of video screenshots), Transcript
Producer: okm pod <file> "Title" (planned) — whisperX large-v3-turbo with speaker diarization
-->
---
title: "Podcast Episode Title"
source_type: podcast
source_file: "attachments/episode-name.mp3"
author: "Show or Host Name"
created: 2026-01-01T00:00:00
tags: [source/podcast, topic/your-topic]
---

# Podcast Episode Title

## File

- Local audio: `[[attachments/episode-name.mp3]]`
- Duration: HH:MM:SS
- Recorded: YYYY-MM-DD

## Summary

<!-- caveman speech: short sentences, no filler, bullets over paragraphs -->

- Key takeaway 1
- Key takeaway 2
- Key takeaway 3

## Actionable Insights

<!-- Specific things to do with this content. Each bullet is a verb + URL or concrete next step. -->

- Insight 1 — what to do, where to learn more
- Insight 2 — tool/library to try, link

## Sources Cited

<!-- External references the host/guests mention: books, papers, websites, tools. -->

- Reference 1 — Author — https://example.com/source
- Reference 2 — Book Title (Author, Year) — ISBN

## Follow-ups

<!-- Open questions, contradictions to resolve, topics to investigate further. -->

- [ ] Follow-up 1
- [ ] Follow-up 2

## Structured Data

| Item | Detail | Notes |
|---|---|---|
| Example | Value | Context |

## Key Quotes

<!-- REQUIRED for audio-only sources. Quotes are the substitute for visual screenshots. -->
<!-- Capture every quote you'd want to remember; future-you should not need to re-listen. -->

> [MM:SS] "Notable quote..."

> [MM:SS] "Another quote..."

## Transcript

<!-- whisperX output: lossless, speaker-diarized. Speaker labels prefixed [SPEAKER_00], [SPEAKER_01], ... -->

[00:00] [SPEAKER_00] Transcript text goes here...
