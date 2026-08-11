<!--
Format Specification: podcast-template
Required frontmatter: title, source_type=podcast, source_file, author, created, tags
Required sections: Player, Summary, Actionable Insights, Sources Cited, Follow-ups, Structured Data, Key Quotes (REQUIRED — audio-only equivalent of video screenshots), Transcript
Producer: okm pod <link|file> — resolves the show's RSS feed for metadata + an existing transcript (RSS <podcast:transcript>). okm never transcribes audio itself.
-->
---
title: "Podcast Episode Title"
source_type: podcast
source_platform: spotify
source_url: "https://open.spotify.com/episode/XXXXXXXXXXXXXXXXXXXXXX"
show: "Show or Host Name"
episode: 99
publish_date: 2026-01-01
captured_date: 2026-01-01
captured_via: okm-pod
tags: [source/podcast, topic/your-topic]
---

# Podcast Episode Title

## Player

[Open episode](<https://open.spotify.com/episode/XXXXXXXXXXXXXXXXXXXXXX>)

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

<!-- okm pod embeds the source's published transcript (RSS <podcast:transcript>) when one exists, as timestamped [MM:SS] lines. okm never transcribes audio itself; if the source publishes none, paste one here or leave this scaffold. -->

[00:00] Transcript text goes here...
