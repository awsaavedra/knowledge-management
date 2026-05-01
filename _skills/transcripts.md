# Skill: High-Fidelity Transcripts

Reference for any future implementation of `okm yt`, `okm pod`, or any other transcription pipeline in this repo. The goal is **lossless, speaker-attributed, time-aligned text** that future-you (or an AI assistant) can search and quote without re-listening.

## Required toolchain

| Tool | Role | Why |
|---|---|---|
| whisperX | ASR + alignment | large-v3-turbo balances speed and accuracy; outputs word-level timestamps |
| pyannote.audio | Speaker diarization | Labels speakers `SPEAKER_00`, `SPEAKER_01`, ... |
| ffmpeg | Audio normalization | 16 kHz mono WAV input maximises whisperX accuracy |

## Mandatory whisperX flags

```bash
whisperx INPUT.wav \
  --model large-v3-turbo \
  --compute_type float32 \
  --diarize \
  --hf_token $HF_TOKEN \
  --output_format json \
  --output_dir transcripts/ \
  --language en \
  --vad_filter true \
  --condition_on_previous_text false
```

**Why each flag:**
- `--model large-v3-turbo` — highest accuracy for the speed; do not downgrade to `base` or `small`.
- `--compute_type float32` — full precision. `int8` is faster but quantizes the model; loses accents and rare words.
- `--diarize` — required. Without speaker labels, multi-voice transcripts collapse into anonymous text.
- `--hf_token` — pyannote requires a HuggingFace token (one-time signup, free).
- `--output_format json` — preserve word-level timestamps. Markdown rendering is downstream.
- `--vad_filter true` — voice-activity-detection drops silences before ASR; reduces hallucinations.
- `--condition_on_previous_text false` — prevents whisperX from echoing prior context into the next chunk (a known cause of repetition loops).

## Required input pre-processing

Before whisperX:
```bash
ffmpeg -i source.mp4 -ac 1 -ar 16000 -c:a pcm_s16le source.wav
```

- `-ac 1` mono
- `-ar 16000` 16 kHz sample rate (matches whisperX training set)
- `-c:a pcm_s16le` uncompressed 16-bit PCM (lossless)

Do **not** transcribe lossy MP3/AAC directly when the lossless source is available — small accuracy gains compound across long sessions.

## Output format requirements

The transcript section in a markdown note must:
1. Preserve word-level timestamps in `[HH:MM:SS]` form (round to second; whisperX provides word-level, but second granularity is enough for human navigation).
2. Prefix each turn with the speaker label: `[00:00] [SPEAKER_00] ...`.
3. Use line breaks at speaker turns or every ~80 chars (so diffs and `okm grep` are useful).
4. Never editorialize or summarize — verbatim only. The Summary / Key Quotes sections do interpretation.

## Storage

- Source audio → `attachments/<title>.wav` (gitignored by default — large).
- whisperX JSON → keep alongside the markdown (`attachments/<title>.transcript.json`) so future tooling can re-render without re-transcribing.
- Markdown transcript → embedded in the note's `## Transcript` section, derived from the JSON.

## Anti-patterns (do not do)

- Compressing the audio to MP3 before transcription.
- Skipping diarization to "save time" — once a transcript is written without speaker labels, retrofitting them requires re-running the whole pipeline.
- Truncating transcripts to keep the note small. Storage is cheap; lossy notes are expensive.
- Auto-correcting transcription errors silently. Mark uncertain segments with `[unclear]` rather than guessing.
