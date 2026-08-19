# Subtitle Clock App — Product Requirements

## Goal

Build a cross-platform offline application for displaying pre-downloaded subtitle files while the user watches a movie elsewhere, especially in a cinema.

The application is **not a video player** and does not generate subtitles. It acts as an independent subtitle playback clock.

First implementation target: **Android**.

Recommended UI framework: **Flutter / Dart** so iOS and desktop can be supported later from the same codebase.

## Primary Use Case

1. User downloads a subtitle file such as `.srt`.
2. User opens the subtitle file in the app.
3. User starts playback when the movie starts.
4. App displays the subtitle cue or cues active at the current playback time.
5. User can correct synchronization during playback using seek, subtitle delay, or playback speed controls.

## Non-Goals for MVP

Do not implement:

- video playback
- audio playback
- microphone input
- speech recognition
- AI subtitle generation
- OpenSubtitles integration
- user accounts
- network dependency
- cloud synchronization

The MVP should work fully offline after installation.

## Supported Subtitle Formats

MVP:

- SRT
- WebVTT

Future:

- TTML / DFXP
- ASS / SSA, if needed

Use an open-source parser library behind an adapter so the parsing library can be replaced later.

Recommended initial Dart package:

- `subtitle`
- MIT license
- Supports SRT, WebVTT, TTML and DFXP
- Supports lookup of multiple cues active at the same time

## Core User Controls

The player screen must support:

- Play
- Pause
- Seek backward 10 seconds
- Seek backward 1 second
- Seek forward 1 second
- Seek forward 10 seconds
- Previous subtitle cue
- Next subtitle cue
- Jump to exact timestamp
- Increase playback speed
- Decrease playback speed
- Reset playback speed to `1.000x`
- Increase subtitle delay
- Decrease subtitle delay
- Reset subtitle delay
- Font size increase/decrease

## Playback Concepts

The app must distinguish between three independent synchronization operations.

### Seek

Seek changes the current playback position immediately.

Example:

```text
01:20:00 + 10 seconds => 01:20:10
```

### Subtitle Delay

Subtitle delay shifts when subtitle cues are displayed without changing the movie clock.

Example:

```text
subtitleDelay = +3.0s
```

means every subtitle should appear 3 seconds later.

Recommended formula:

```text
subtitleLookupTime = playbackPosition - subtitleDelay
```

### Playback Rate

Playback rate corrects progressive timing drift.

Examples:

```text
1.000x
0.999x
1.001x
1.010x
```

Use fine-grained adjustments because cinema subtitle drift is usually small.

Recommended adjustment step:

```text
0.001x
```

Optionally add coarse controls later.

## Multiple Simultaneous Subtitles

Multiple subtitle cues may be active at the same time.

The application must never assume there is only one active cue.

Use:

```text
List<SubtitleCue> activeCues
```

not:

```text
SubtitleCue? activeCue
```

A cue is active when:

```text
cue.start <= time < cue.end
```

Use half-open ranges `[start, end)` so adjacent cues do not overlap at an exact boundary.

Example:

```text
A: 10s -> 20s
B: 14s -> 16s
```

At 15 seconds, display both A and B.

At 17 seconds, display only A.

Do not permanently merge overlapping cues. Combine them only in the renderer.

## Long Subtitle Cues

Long-running cues must remain visible until their configured end time even when new cues begin.

Example:

```text
A: 10s -> 30s
B: 24s -> 27s
```

At 25 seconds, both A and B must be displayed.

A must still be visible after B ends until 30 seconds.

## Same-Time Cues

If two or more cues have the same start time or exact same time range, preserve all of them unless they are confirmed exact duplicates.

Do not silently discard cues because they share timing information.

## Rendering

Default cinema-oriented design:

- black / OLED background
- white subtitle text
- minimal UI chrome while playing
- very low brightness-friendly presentation
- large centered subtitle area
- controls that can be revealed without leaving the player
- show one most recently ended cue in a distinct opaque cool-gray color
- keep that previous cue visible during a gap and while new cues appear below it
- animate cue changes with a subtle cross-fade
- keep each visible cue in its current vertical slot when it becomes previous;
  place the next cue in the other free slot instead of moving existing text

The previous-cue color is visual only. Cue activity still uses the
half-open `[start, end)` rule, and the subtitle area remains empty before the
first cue begins.

Recommended subtitle ordering:

1. explicit layer/position metadata when the format supports it
2. cue start time
3. source file order

For SRT, sort by:

1. start time
2. source file index

## Long Text Layout

The renderer must not drop text when there are multiple or long cues.

Preferred behavior:

1. use the configured font size if content fits
2. reduce font size down to a safe minimum if needed
3. preserve all cue text
4. allow scrolling only as a last fallback

The user must also be able to manually change text size.

## Cinema Usability

The app should support:

- keep screen awake while player screen is active
- dark/OLED mode by default
- minimal distracting animations
- large touch targets
- operation without network access
- restoring current file and playback state if Android temporarily backgrounds the app

## Sync-to-Cue Feature

Add a fast synchronization workflow:

1. User browses nearby subtitle cues.
2. User taps a cue corresponding to dialogue currently heard in the movie.
3. User chooses `Sync here`.
4. App updates playback position so the selected cue begins now.

This should be easier to use in a cinema than repeatedly pressing seek buttons.

## Persistence

Persist at least:

- last opened subtitle file reference if possible
- current playback position
- subtitle delay
- playback rate
- text size
- dark/OLED setting

Do not require persistence to work across inaccessible Android file picker URIs; handle this gracefully.

## Acceptance Criteria

The MVP is acceptable when:

- a local SRT file can be opened on Android
- playback clock can play and pause without timing drift caused by UI timer scheduling
- seek backward/forward works immediately
- speed adjustment does not cause a position jump
- subtitle delay works independently of playback position
- overlapping cues display simultaneously
- long-running cues remain visible until their end time
- previous/next cue navigation works
- exact timestamp jump works
- app works offline
- screen remains awake during subtitle playback
