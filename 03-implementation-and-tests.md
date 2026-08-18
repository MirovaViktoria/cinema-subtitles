# Subtitle Clock App — Implementation and Test Plan

## Objective

Implement the first Android MVP of the offline subtitle-clock application using Flutter.

Prioritize correctness of timing and overlapping subtitle behavior before visual polish.

## Phase 1 — Project Bootstrap

Create Flutter project with Android support.

Add dependencies for:

- subtitle parsing
- file selection
- wake lock
- lightweight settings persistence

Configure linting and tests.

Deliverable:

- app launches on Android emulator/device
- empty home screen with `Open subtitle file`

## Phase 2 — Domain Layer

Implement:

- `SubtitleCue`
- `SubtitleTimeline`
- `PlaybackClock`
- `PlayerState`

Do not depend on Flutter widgets inside these classes.

### PlaybackClock Requirements

- use monotonic elapsed time
- no accumulated periodic-timer increments
- support play/pause
- support absolute seek
- support relative seek
- support playback rate
- changing rate must preserve current position

## Phase 3 — Subtitle Parsing

Implement parser adapter around the selected open-source subtitle library.

Support MVP formats:

- `.srt`
- `.vtt`

Normalize parsed cues into app-owned `SubtitleCue` instances.

Preserve:

- start time
- end time
- text
- original source order
- multiple simultaneous cues

Do not deduplicate cues unless they are clearly exact duplicate artifacts and tests explicitly cover that behavior.

## Phase 4 — Timeline Lookup

Implement efficient methods:

```dart
List<SubtitleCue> activeAt(Duration position)
SubtitleCue? nextAfter(Duration position)
SubtitleCue? previousBefore(Duration position)
List<SubtitleCue> nearby(Duration position, ...)
```

Use half-open intervals:

```text
[start, end)
```

Do not rely on playback history to determine active cues.

Any arbitrary seek must produce correct active cues immediately.

## Phase 5 — Player Controller

Implement controller commands:

```text
play
pause
seek
seekBy
setRate
adjustRate
resetRate
setSubtitleDelay
adjustSubtitleDelay
resetSubtitleDelay
nextCue
previousCue
syncToCue
```

Default controls:

```text
seek: -10s, -1s, +1s, +10s
rate: -0.001x, +0.001x
subtitle delay: -1s, -0.1s, +0.1s, +1s
```

Exact values may be adjusted later after real cinema testing.

## Phase 6 — Android File Picker

Implement local file opening.

Required behavior:

- user chooses `.srt` or `.vtt`
- app parses file
- parse error shown without crashing
- successful file opens player screen

Do not add network subtitle search.

## Phase 7 — Player UI

Initial layout:

```text
+----------------------------------+
|            01:24:37              |
|                                  |
|                                  |
|     active subtitle cue 1        |
|                                  |
|     active subtitle cue 2        |
|                                  |
|                                  |
|       rate 1.000x                |
|       delay +0.0s                |
|                                  |
| -10s  -1s   Play/Pause  +1s +10s|
+----------------------------------+
```

Requirements:

- black background
- white text
- large subtitle area
- multiple cues rendered independently
- manual font size adjustment
- controls hidden/reduced while not needed if useful
- screen wake lock enabled on player screen

## Phase 8 — Nearby Cue Browser / Sync Here

Show previous/current/upcoming cues.

Allow tapping a cue and selecting:

```text
Sync here
```

Behavior:

```text
playbackPosition = selectedCue.start
```

Preserve current play/pause state.

This is an important cinema usability feature.

## Required Unit Tests

### 1. Normal Active Cue

Input:

```text
A: 10s -> 15s
```

Expected:

```text
9.999s => []
10.000s => [A]
14.999s => [A]
15.000s => []
```

### 2. Overlapping Cues

Input:

```text
A: 10s -> 20s
B: 15s -> 18s
```

Expected:

```text
16s => [A, B]
19s => [A]
```

### 3. Same Start Time

Input:

```text
A: 10s -> 15s
B: 10s -> 12s
```

Expected:

```text
11s => [A, B]
```

### 4. Same Exact Range

Input:

```text
A: 10s -> 15s
B: 10s -> 15s
```

Expected:

```text
11s => [A, B]
```

unless the entries are confirmed exact duplicate artifacts according to an explicit deduplication rule.

### 5. Long Cue With Short Overlap

Input:

```text
A: 10s -> 60s
B: 24s -> 27s
```

Expected:

```text
25s => [A, B]
30s => [A]
59.999s => [A]
60s => []
```

### 6. Arbitrary Seek Into Active Cue

Start at 5s.

Seek directly to 17s.

If a cue is active at 17s, it must display immediately.

Do not require passing through its start timestamp.

### 7. Seek Backward

Start after a cue has ended.

Seek backward into the cue range.

Cue must display immediately.

### 8. Playback Rate Calculation

At rate `1.01x`:

```text
100 seconds real elapsed => 101 seconds playback elapsed
```

Allow a very small numerical tolerance.

### 9. Rate Change Does Not Jump Position

Scenario:

1. start at 30s
2. play at 1.01x
3. calculate current position
4. change to 0.99x

Expected:

- position immediately before and after rate change is effectively identical
- only future rate of advancement changes

### 10. Pause

When paused, playback position must remain stable regardless of real elapsed time.

### 11. Seek While Paused

Seek must update position while remaining paused.

### 12. Seek While Playing

Seek must update position and continue playing from the new anchor.

### 13. Subtitle Delay

Given:

```text
playbackPosition = 20s
subtitleDelay = +2s
```

lookup time must be:

```text
18s
```

### 14. Delay Change Must Not Change Movie Position

Changing subtitle delay must only affect cue lookup.

The playback clock position must not move.

### 15. Parser Preserves Overlaps

Create an SRT fixture containing overlapping cues.

After parsing, both cues must exist independently.

### 16. Parser Preserves Long Cues

Create a fixture containing a long cue and nested shorter cue.

Both timing ranges must remain unchanged after normalization.

## Widget / Integration Tests

Cover:

- file open success
- parse error UI
- play/pause button
- seek buttons
- rate buttons
- delay buttons
- multiple active cues displayed
- long cue remains when short overlapping cue ends
- exact timestamp entry
- previous/next cue navigation
- wake lock lifecycle where practical

## Manual Android Test Scenarios

### Cinema-Like Sync Test

1. Open a real movie SRT.
2. Start at approximate movie start.
3. Introduce a fixed 8-second timing error.
4. Correct it with seek or delay.
5. Verify cues remain stable for at least 10 minutes.

### Progressive Drift Test

1. Start correctly synchronized.
2. Use an intentionally wrong playback rate.
3. Observe progressive drift.
4. Correct rate by small increments.
5. Verify position does not jump when rate changes.

### Overlap Test

Use a subtitle fixture with at least three simultaneously active cues and verify all are visible.

### Long Text Test

Use:

- one very long multiline cue
- multiple simultaneous long cues

Verify no text disappears silently.

### Background/Resume Test

1. Start playback.
2. Background the app briefly.
3. Return to the app.
4. Verify playback position is consistent with intended lifecycle behavior.

For MVP, decide explicitly whether playback should continue while backgrounded or pause automatically. Recommended initial behavior: **pause when app is no longer active**, because cinema use does not require background playback and this avoids accidental desynchronization.

## Definition of Done

The MVP is complete when:

- Android app opens SRT/VTT files
- playback clock is anchor-based and tested
- play/pause/seek works
- rate adjustment works without jumps
- subtitle delay is independent from clock position
- overlapping cues display simultaneously
- long cues remain visible correctly
- previous/next cue navigation works
- `Sync here` works
- app keeps screen awake while player is active
- app works without network access
- automated tests cover timing edge cases
