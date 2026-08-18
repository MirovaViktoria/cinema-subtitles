import 'package:cinema_subtitles/domain/playback_clock.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_monotonic_time_source.dart';

void main() {
  late FakeMonotonicTimeSource timeSource;
  late PlaybackClock clock;

  setUp(() {
    timeSource = FakeMonotonicTimeSource();
    clock = PlaybackClock(timeSource: timeSource);
  });

  test('advances from a monotonic anchor while playing', () {
    clock.seek(const Duration(seconds: 30));
    clock.play();
    timeSource.advance(const Duration(seconds: 5));

    expect(clock.position, const Duration(seconds: 35));
  });

  test('does not advance while paused', () {
    clock.play();
    timeSource.advance(const Duration(seconds: 3));
    clock.pause();
    final pausedAt = clock.position;

    timeSource.advance(const Duration(hours: 1));

    expect(clock.position, pausedAt);
    expect(clock.isPlaying, isFalse);
  });

  test('seeks while paused and remains paused', () {
    clock.seek(const Duration(seconds: 17));

    expect(clock.position, const Duration(seconds: 17));
    expect(clock.isPlaying, isFalse);
  });

  test('seeks while playing and continues from the new anchor', () {
    clock.play();
    timeSource.advance(const Duration(seconds: 4));
    clock.seek(const Duration(seconds: 40));
    timeSource.advance(const Duration(seconds: 2));

    expect(clock.position, const Duration(seconds: 42));
    expect(clock.isPlaying, isTrue);
  });

  test('clamps a relative seek at zero', () {
    clock.seek(const Duration(seconds: 3));
    clock.seekBy(const Duration(seconds: -10));

    expect(clock.position, Duration.zero);
  });

  test('applies playback rate to elapsed time', () {
    clock.setRate(1.01);
    clock.play();
    timeSource.advance(const Duration(seconds: 100));

    expect(clock.position, const Duration(seconds: 101));
  });

  test('changing rate does not jump the current position', () {
    clock.seek(const Duration(seconds: 30));
    clock.setRate(1.01);
    clock.play();
    timeSource.advance(const Duration(seconds: 10));
    final before = clock.position;

    clock.setRate(0.99);

    expect(clock.position, before);
    timeSource.advance(const Duration(seconds: 10));
    expect(clock.position, before + const Duration(milliseconds: 9900));
  });

  test('rejects invalid rates', () {
    expect(() => clock.setRate(0), throwsArgumentError);
    expect(() => clock.setRate(double.nan), throwsArgumentError);
    expect(() => clock.setRate(double.infinity), throwsArgumentError);
  });
}
