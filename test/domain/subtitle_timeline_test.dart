import 'package:cinema_subtitles/domain/subtitle_cue.dart';
import 'package:cinema_subtitles/domain/subtitle_timeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SubtitleCue cue(
    String id,
    int startSeconds,
    int endSeconds,
    int sourceIndex,
  ) => SubtitleCue(
    id: id,
    start: Duration(seconds: startSeconds),
    end: Duration(seconds: endSeconds),
    text: id,
    sourceIndex: sourceIndex,
  );

  test('uses half-open cue boundaries', () {
    final a = cue('A', 10, 15, 0);
    final timeline = SubtitleTimeline([a]);

    expect(timeline.activeAt(const Duration(milliseconds: 9999)), isEmpty);
    expect(timeline.activeAt(const Duration(seconds: 10)), [a]);
    expect(timeline.activeAt(const Duration(milliseconds: 14999)), [a]);
    expect(timeline.activeAt(const Duration(seconds: 15)), isEmpty);
  });

  test('preserves overlapping cues', () {
    final a = cue('A', 10, 20, 0);
    final b = cue('B', 15, 18, 1);
    final timeline = SubtitleTimeline([b, a]);

    expect(timeline.activeAt(const Duration(seconds: 16)), [a, b]);
    expect(timeline.activeAt(const Duration(seconds: 19)), [a]);
  });

  test('preserves cues with the same start time', () {
    final a = cue('A', 10, 15, 0);
    final b = cue('B', 10, 12, 1);
    final timeline = SubtitleTimeline([b, a]);

    expect(timeline.activeAt(const Duration(seconds: 11)), [a, b]);
  });

  test('preserves cues with the same exact range', () {
    final a = cue('A', 10, 15, 0);
    final b = cue('B', 10, 15, 1);
    final timeline = SubtitleTimeline([a, b]);

    expect(timeline.activeAt(const Duration(seconds: 11)), [a, b]);
  });

  test('keeps a long cue after a nested cue ends', () {
    final a = cue('A', 10, 60, 0);
    final b = cue('B', 24, 27, 1);
    final timeline = SubtitleTimeline([a, b]);

    expect(timeline.activeAt(const Duration(seconds: 25)), [a, b]);
    expect(timeline.activeAt(const Duration(seconds: 30)), [a]);
    expect(timeline.activeAt(const Duration(milliseconds: 59999)), [a]);
    expect(timeline.activeAt(const Duration(seconds: 60)), isEmpty);
  });

  test('resolves arbitrary forward and backward seeks from position only', () {
    final a = cue('A', 10, 20, 0);
    final timeline = SubtitleTimeline([a]);

    expect(timeline.activeAt(const Duration(seconds: 17)), [a]);
    expect(timeline.activeAt(const Duration(seconds: 30)), isEmpty);
    expect(timeline.activeAt(const Duration(seconds: 12)), [a]);
  });

  test('finds the latest ended cue during gaps and active cues', () {
    final a = cue('A', 10, 15, 0);
    final b = cue('B', 20, 25, 1);
    final timeline = SubtitleTimeline([a, b]);

    expect(timeline.latestEndedAt(const Duration(seconds: 9)), isNull);
    expect(timeline.latestEndedAt(const Duration(seconds: 16)), a);
    expect(timeline.activeAt(const Duration(seconds: 20)), [b]);
    expect(timeline.latestEndedAt(const Duration(seconds: 20)), a);
    expect(timeline.latestEndedAt(const Duration(seconds: 26)), b);
  });

  test('selects one latest ended cue after overlaps and shared end times', () {
    final long = cue('Long', 10, 30, 0);
    final nested = cue('Nested', 24, 27, 1);
    final sameEnd = cue('Same end', 28, 30, 2);
    final timeline = SubtitleTimeline([long, nested, sameEnd]);

    expect(timeline.latestEndedAt(const Duration(seconds: 29)), nested);
    expect(timeline.latestEndedAt(const Duration(seconds: 31)), sameEnd);
  });

  test('navigates and returns nearby cues in timeline order', () {
    final cues = [
      cue('A', 5, 6, 0),
      cue('B', 10, 11, 1),
      cue('C', 15, 16, 2),
      cue('D', 20, 21, 3),
    ];
    final timeline = SubtitleTimeline(cues.reversed);

    expect(timeline.previousBefore(const Duration(seconds: 15)), cues[1]);
    expect(timeline.nextAfter(const Duration(seconds: 15)), cues[3]);
    expect(timeline.nearby(const Duration(seconds: 15), before: 1, after: 1), [
      cues[1],
      cues[2],
      cues[3],
    ]);
  });
}
