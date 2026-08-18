# Subtitle Clock App — Architecture

## Technology Choice

Use:

- Flutter
- Dart
- Android as first deployment target

Suggested packages:

```yaml
subtitle: ^0.2.0
file_selector: latest compatible stable version
wakelock_plus: latest compatible stable version
```

Pin exact package versions when implementation starts and verify current licenses and APIs.

## Architectural Principle

The subtitle parser is an infrastructure dependency.

The playback clock and subtitle timeline are domain logic owned by the application.

Do not couple the player UI directly to parser-library classes.

## High-Level Data Flow

```text
Local subtitle file
        |
        v
SubtitleParserAdapter
        |
        v
List<SubtitleCue>
        |
        v
SubtitleTimeline
        |
        +-------------------+
        |                   |
        v                   v
PlaybackClock         Cue navigation
        |
        v
Current playback position
        |
        v
subtitleLookupTime = position - delay
        |
        v
activeAt(time)
        |
        v
List<SubtitleCue>
        |
        v
SubtitleRenderer
```

## Suggested Project Structure

```text
lib/
  app/
    app.dart

  domain/
    subtitle_cue.dart
    subtitle_timeline.dart
    playback_clock.dart
    playback_state.dart

  infrastructure/
    subtitle_parser.dart
    subtitle_package_adapter.dart
    subtitle_file_loader.dart

  features/
    open_file/
      open_file_screen.dart
      open_file_controller.dart

    player/
      player_screen.dart
      player_controller.dart
      subtitle_view.dart
      playback_controls.dart
      sync_controls.dart

    settings/
      settings_model.dart
      settings_store.dart
```

## Domain Models

### SubtitleCue

Use an application-owned model.

```dart
class SubtitleCue {
  const SubtitleCue({
    required this.id,
    required this.start,
    required this.end,
    required this.text,
    required this.sourceIndex,
    this.style,
  });

  final String id;
  final Duration start;
  final Duration end;
  final String text;
  final int sourceIndex;
  final SubtitleStyle? style;
}
```

For MVP, `SubtitleStyle` may be absent or minimal.

Validate or normalize malformed timing during parsing.

## Subtitle Parser Abstraction

```dart
abstract interface class SubtitleParser {
  Future<List<SubtitleCue>> parse({
    required String contents,
    required SubtitleFormat format,
  });
}
```

Implementation:

```text
SubtitlePackageAdapter
```

Responsibilities:

- invoke third-party parsing library
- convert third-party cue objects to `SubtitleCue`
- preserve source order
- preserve simultaneous cues
- normalize line endings and text
- reject or report invalid files cleanly

Do not let third-party parser types escape this layer.

## SubtitleTimeline

```dart
abstract interface class SubtitleTimeline {
  List<SubtitleCue> activeAt(Duration position);
  SubtitleCue? nextAfter(Duration position);
  SubtitleCue? previousBefore(Duration position);
  List<SubtitleCue> nearby(Duration position, {int before = 3, int after = 5});
}
```

Implementation should support efficient lookup.

A full scan per UI frame is unnecessary even though typical files are small.

### Active Cue Rule

Use:

```text
start <= position < end
```

This avoids duplicate display at exact cue boundaries.

### Overlapping Cues

Do not maintain a single current-cue pointer as the source of truth.

Seeking can jump directly into an overlapping region, so active cues must be resolved from timeline state at the requested timestamp.

## PlaybackClock

Do not increment playback time using periodic timer ticks.

Use an anchor-based monotonic clock.

Conceptual state:

```dart
class PlaybackClock {
  Duration anchorPosition;
  Duration anchorElapsed;
  double rate;
  bool isPlaying;
}
```

Use a monotonic elapsed-time source such as `Stopwatch` rather than wall-clock `DateTime.now()` for playback calculations.

### Current Position

When paused:

```text
position = anchorPosition
```

When playing:

```text
position = anchorPosition
         + (monotonicNow - anchorElapsed) * rate
```

### Play

On `play()`:

```text
anchorPosition = currentPosition
anchorElapsed = monotonicNow
isPlaying = true
```

### Pause

On `pause()`:

```text
anchorPosition = currentPosition
anchorElapsed = monotonicNow
isPlaying = false
```

### Seek

On `seek(target)`:

1. calculate current position
2. set `anchorPosition = target`
3. set `anchorElapsed = monotonicNow`
4. preserve play/pause state

### Change Rate

On `setRate(newRate)`:

1. calculate current position using old rate
2. set `anchorPosition = currentPosition`
3. set `anchorElapsed = monotonicNow`
4. set `rate = newRate`

This prevents a visible position jump when rate changes.

## UI Refresh

The UI may refresh every 50–100 ms while playing.

The refresh mechanism must only request a new state calculation.

It must not advance playback position itself.

Example:

```text
UI timer fires
   |
   v
PlayerController reads PlaybackClock.position
   |
   v
SubtitleTimeline.activeAt(...)
   |
   v
render state
```

If Android skips UI timer callbacks, the next refresh should still calculate the correct current playback position.

## Player State

```dart
class PlayerState {
  const PlayerState({
    required this.isPlaying,
    required this.position,
    required this.subtitleDelay,
    required this.playbackRate,
    required this.activeCues,
  });

  final bool isPlaying;
  final Duration position;
  final Duration subtitleDelay;
  final double playbackRate;
  final List<SubtitleCue> activeCues;
}
```

Optional state:

- current file metadata
- nearby cues
- font size
- controls visibility
- parse warnings

## PlayerController API

Recommended commands:

```dart
play();
pause();
togglePlayPause();

seek(Duration target);
seekBy(Duration delta);

setRate(double rate);
adjustRate(double delta);
resetRate();

setSubtitleDelay(Duration delay);
adjustSubtitleDelay(Duration delta);
resetSubtitleDelay();

previousCue();
nextCue();
syncToCue(SubtitleCue cue);
```

## Subtitle Lookup Time

Playback clock represents movie time.

Subtitle delay is applied only during timeline lookup.

```text
lookupTime = playbackPosition - subtitleDelay
```

This keeps seek and delay independent.

Do not rewrite cue timestamps every time delay changes.

## Renderer

Renderer input:

```text
List<SubtitleCue> activeCues
```

Never merge cues in domain state.

For plain SRT order by:

1. start time
2. source index

Render cue blocks independently with spacing between them.

This allows one long cue to remain visible while shorter overlapping cues appear and disappear.

## File Loading

Use the platform file picker through `file_selector` or equivalent.

Expected flow:

```text
Open File
  -> Android document picker
  -> read bytes/text from selected URI
  -> detect format
  -> parse
  -> normalize
  -> build SubtitleTimeline
  -> open PlayerScreen
```

Avoid requesting broad filesystem permissions if the system document picker is sufficient.

## Screen Wake Lock

Enable screen wake lock while the player view is active.

Disable it when leaving the player screen.

Do not keep a global wake lock active outside subtitle playback.

## Persistence

Suggested first implementation:

- shared_preferences for simple settings and playback state
- retain selected file URI only if Android permissions allow reopening it

Persist:

- rate
- delay
- font size
- last position
- last file identifier/reference when viable

## Error Handling

Display user-friendly errors for:

- unsupported format
- unreadable file
- invalid subtitle syntax
- empty subtitle file
- cue with invalid time range
- encoding issues

Parser errors should be converted into application-level failures rather than thrown directly into UI widgets.

## Future Extensibility

Possible future adapters:

```text
SubtitleParser
  |- SrtVttParserAdapter
  |- AssParserAdapter
  |- TtmlParserAdapter
```

ASS/SSA should be deferred until required because it introduces styles, layers, positions, override tags, karaoke timing, and font behavior.
