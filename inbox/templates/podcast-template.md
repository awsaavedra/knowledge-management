<!--
Format Specification: podcast-template
Required frontmatter: title, source_type=podcast, source_file, author, created, tags
Required sections: File, Summary, Structured Data, Key Quotes, Transcript
Producer: okm pod <file> "Title" (planned) — whisperX large-v3-turbo with speaker diarization
-->
---
title: "Podcast Episode Title"
source_type: podcast
source_file: "attachments/episode-name.mp3"
author: "Show or Host Name"
created: 2026-01-01T00:00:00
tags:
  - source/podcast
  - topic/your-topic
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

## Structured Data

| Item | Detail | Notes |
|---|---|---|
| Example | Value | Context |

## Key Quotes

> [MM:SS] "Notable quote..."

> [MM:SS] "Another quote..."

## Transcript

<!-- whisperX output: lossless, speaker-diarized. Speaker labels prefixed [SPEAKER_00], [SPEAKER_01], ... -->

[00:00] [SPEAKER_00] Transcript text goes here...
