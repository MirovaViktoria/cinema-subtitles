# Agent Instructions — Subtitle Clock App

## Language

- Communicate with the user in Russian by default.
- Write OpenSpec artifacts in Russian while preserving required OpenSpec keywords.
- Keep code identifiers, file names, and terminal commands in English.

## Mission

Implement the Android-first Flutter application described in the accompanying specification files.

Read these files before coding:

1. `01-product-requirements.md`
2. `02-architecture.md`
3. `03-implementation-and-tests.md`

Treat them as the source of truth for MVP behavior.

## Key Constraints

- Flutter / Dart
- Android first, but avoid Android-only domain logic
- fully offline MVP
- no video player
- no audio player
- no AI or speech recognition
- no OpenSubtitles integration
- open local subtitle files
- SRT and WebVTT for MVP
- use an open-source subtitle parsing library behind an adapter
- application owns playback timing logic

## Critical Correctness Rules

### Playback Clock

Never advance movie position by incrementing a periodic timer.

Use a monotonic anchor-based clock:

```text
position = anchorPosition + elapsedSinceAnchor * playbackRate
```

Re-anchor on:

- play
- pause
- seek
- rate change

Rate changes must never cause an immediate position jump.

### Subtitle Activation

Use:

```text
cue.start <= time < cue.end
```

The application must support zero, one, or many active cues at any timestamp.

Do not assume only one active subtitle.

### Overlapping / Long Cues

Keep cues independent in the domain model.

Never destroy a long-running cue because a newer cue starts.

Merge only visually in the renderer.

### Synchronization Controls

Keep these independent:

- playback position / seek
- subtitle delay
- playback rate

Subtitle delay affects lookup time only.

## Implementation Priority

1. domain models
2. playback clock + tests
3. subtitle timeline + overlap tests
4. parser adapter + fixtures
5. player controller
6. file picker
7. minimal player UI
8. sync controls
9. nearby cue browser / `Sync here`
10. persistence and polish

Do not spend significant time on visual polish until timing tests pass.

## Testing Requirement

Before declaring the feature complete, run automated tests covering all edge cases in `03-implementation-and-tests.md`.

Especially verify:

- overlapping cues
- same-start cues
- same-range cues
- long cues
- exact cue boundaries
- arbitrary seek into a cue
- backward seek into a cue
- playback rate calculations
- rate changes without jumps
- subtitle delay independence

## Engineering Style

- keep domain code independent of Flutter widgets where practical
- favor small composable classes
- do not leak third-party parser models into the domain layer
- keep timing behavior deterministic and unit-testable
- do not silently repair or discard subtitle data unless the behavior is documented and tested
- avoid unrelated features

## Deliverables

Expected implementation deliverables:

- working Flutter project
- Android build
- automated tests
- sample subtitle fixtures for edge cases
- concise README with run/build instructions

When tradeoffs are necessary, prioritize deterministic timing and correct subtitle display over UI complexity.
