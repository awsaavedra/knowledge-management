<!--
Format Specification: yt-template
Required frontmatter: title, source_type=youtube, source_url, author, publish_date, captured_date, captured_via, tags
Required sections: Disclaimer, Thumbnail, Summary, Actionable Insights, Sources Cited, Follow-ups, Structured Data, Key Quotes, Screenshots (REQUIRED — capture every key visual moment so the note replaces re-watching), Timestamps, Transcript
Producer: okm yt <URL> (planned) + mpv `s` for screenshots
-->
---
title: "Video Title Here"
source_type: youtube
source_url: "https://www.youtube.com/watch?v=XXXXXXXXXXX"
author: "Channel Name"
publish_date: 2026-01-01
captured_date: 2026-01-01
captured_via: okm-yt
tags: [source/youtube, topic/your-topic]
---

# Video Title Here

> **Disclaimer:** Educational content only. Not financial advice. See [`disclaimer.md`](../disclaimer.md).

![[video-thumbnail.png]]

## Summary

<!-- caveman speech: short sentences, no filler, bullets over paragraphs -->
<!-- lead with the fact, not the context. numbers over prose. -->
<!-- tables over lists when there's structured data -->

- Key takeaway 1
- Key takeaway 2
- Key takeaway 3

## Actionable Insights

<!-- Specific things to do with this content. Each bullet is a verb + URL or concrete next step. -->
<!-- Example: "Build openclaw on mac mini — tutorial: https://example.com/openclaw-mac" -->

- Insight 1 — what to do, where to learn more
- Insight 2 — tool/library to try, link

## Sources Cited

<!-- External references the author/speaker mentions: books, papers, websites, tools. -->
<!-- Format: short title — author — URL (or DOI / ISBN). Distinct from Key Quotes. -->

- Reference 1 — Author — https://example.com/source
- Reference 2 — Book Title (Author, Year) — ISBN

## Follow-ups

<!-- Open questions, contradictions to resolve, or topics to investigate further. -->

- [ ] Follow-up 1
- [ ] Follow-up 2

## Structured Data

<!-- use tables for structured data: comparisons, frameworks, lists with attributes -->

| Item | Detail | Notes |
|---|---|---|
| Example | Value | Context |

## Key Quotes

> [MM:SS] "Notable quote from the video..."

> [MM:SS] "Another important quote..."

## Screenshots

<!-- REQUIRED for video notes. Press 's' in mpv at every key visual moment: -->
<!-- diagrams, code, slides, demos, charts, faces during quotes. -->
<!-- The goal is for the note to replace re-watching the video. -->
<!-- Audio-only sources (Spotify) substitute Key Quotes for this requirement. -->

![[screenshot-HHMMSS.png]]

## Timestamps

- 00:00 — Introduction
- 02:30 — Section 1
- 05:45 — Section 2

## Transcript

<!-- okm yt fetches this automatically, or use whisperX for local transcription -->

[00:00] Transcript text goes here...
