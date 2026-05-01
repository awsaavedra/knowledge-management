<!--
Format Specification: yt-template
Required frontmatter: title, source_type=youtube, source_url, author, publish_date, captured_date, captured_via, tags
Required sections: Disclaimer, Thumbnail, Summary, Structured Data, Key Quotes, Screenshots, Timestamps, Transcript
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
tags:
  - source/youtube
  - topic/your-topic
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

## Structured Data

<!-- use tables for structured data: comparisons, frameworks, lists with attributes -->

| Item | Detail | Notes |
|---|---|---|
| Example | Value | Context |

## Key Quotes

> [MM:SS] "Notable quote from the video..."

> [MM:SS] "Another important quote..."

## Screenshots

<!-- press 's' in mpv during playback to capture key visuals -->

![[screenshot-HHMMSS.png]]

## Timestamps

- 00:00 — Introduction
- 02:30 — Section 1
- 05:45 — Section 2

## Transcript

<!-- okm yt fetches this automatically, or use whisperX for local transcription -->

[00:00] Transcript text goes here...
