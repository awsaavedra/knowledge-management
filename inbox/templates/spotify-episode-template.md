<!--
Format Specification: spotify-episode-template
Required frontmatter: title, source_type=spotify-episode, source_url, author, created, tags
Required sections: Player, Summary, Structured Data, Key Quotes, Transcript
Producer: okm spot <URL> (skeleton) -> spotdl -> okm pod <file> (transcribe)
-->
---
title: "Episode or Track Title"
source_type: spotify-episode
source_url: "https://open.spotify.com/episode/XXXXXXXXXXX"
author: "Show or Artist Name"
created: 2026-01-01T00:00:00
tags:
  - source/podcast
  - topic/your-topic
---

# Episode or Track Title

## Player

[Listen on Spotify](https://open.spotify.com/episode/XXXXXXXXXXX)

<iframe src="https://open.spotify.com/embed/episode/XXXXXXXXXXX" width="100%" height="352" frameBorder="0" allowfullscreen allow="autoplay; clipboard-write; encrypted-media; fullscreen; picture-in-picture" loading="lazy"></iframe>

## Summary

<!-- caveman speech: short sentences, no filler, bullets over paragraphs -->

- Key takeaway 1
- Key takeaway 2
- Key takeaway 3

## Structured Data

<!-- use tables for structured data: comparisons, frameworks, lists with attributes -->

| Item | Detail | Notes |
|---|---|---|
| Example | Value | Context |

## Key Quotes

> [MM:SS] "Notable quote..."

> [MM:SS] "Another quote..."

## Transcript

<!-- transcription workflow for Spotify episodes: -->
<!-- 1. okm spot <url>           — creates this note skeleton -->
<!-- 2. spotdl <url>             — downloads audio -->
<!-- 3. okm pod <file> "Title"   — transcribes with whisperX -->

[00:00] Transcript text goes here...
