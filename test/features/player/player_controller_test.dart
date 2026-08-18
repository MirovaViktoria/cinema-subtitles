import 'package:cinema_subtitles/domain/playback_clock.dart';
import 'package:cinema_subtitles/domain/subtitle_cue.dart';
import 'package:cinema_subtitles/domain/subtitle_timeline.dart';
import 'package:cinema_subtitles/features/player/player_controller.dart';
import 'package:cinema_subtitles/features/settings/player_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_monotonic_time_source.dart';
import '../../support/memory_player_preferences_store.dart';

void main() {
  late FakeMonotonicTimeSource timeSource;
  late MemoryPlayerPreferencesStore preferencesStore;
  late SubtitleCue firstCue;
  late SubtitleCue delayedCue;
  late SubtitleCue thirdCue;
  late PlayerController controller;

  setUp(() {
    timeSource = FakeMonotonicTimeSource();
    preferencesStore = MemoryPlayerPreferencesStore();
    firstCue = SubtitleCue(
      id: 'first',
      start: const Duration(seconds: 10),
      end: const Duration(seconds: 15),
      text: 'First',
      sourceIndex: 0,
    );
    delayedCue = SubtitleCue(
      id: 'delayed',
      start: const Duration(seconds: 18),
      end: const Duration(seconds: 19),
      text: 'Delayed',
      sourceIndex: 1,
    );
    thirdCue = SubtitleCue(
      id: 'third',
      start: const Duration(seconds: 25),
      end: const Duration(seconds: 30),
      text: 'Third',
      sourceIndex: 2,
    );
    controller = PlayerController(
      fileName: 'movie.srt',
      fileReference: 'movie.srt',
      timeline: SubtitleTimeline([firstCue, delayedCue, thirdCue]),
      clock: PlaybackClock(timeSource: timeSource),
      preferencesStore: preferencesStore,
      refreshInterval: null,
    );
  });

  tearDown(() {
    controller.dispose();
  });

  test('refresh reads anchor clock instead of incrementing position', () {
    controller.play();
    timeSource.advance(const Duration(seconds: 12));
    controller.refresh();

    expect(controller.state.position, const Duration(seconds: 12));
    expect(controller.state.activeCues, [firstCue]);
  });

  test('seek controls preserve play and pause state', () {
    controller.seek(const Duration(seconds: 10));
    expect(controller.state.isPlaying, isFalse);

    controller.play();
    controller.seekBy(const Duration(seconds: 10));

    expect(controller.state.position, const Duration(seconds: 20));
    expect(controller.state.isPlaying, isTrue);
  });

  test('rate changes do not jump position', () {
    controller.seek(const Duration(seconds: 10));
    controller.play();
    timeSource.advance(const Duration(seconds: 5));
    controller.refresh();
    final before = controller.state.position;

    controller.adjustRate(PlayerController.rateStep);

    expect(controller.state.position, before);
    expect(controller.state.playbackRate, 1.001);
  });

  test('subtitle delay changes lookup only, not movie position', () {
    controller.seek(const Duration(seconds: 20));
    controller.setSubtitleDelay(const Duration(seconds: 2));

    expect(controller.state.position, const Duration(seconds: 20));
    expect(controller.state.activeCues, [delayedCue]);
  });

  test('previous, next and sync actions seek to cue starts', () {
    controller.seek(const Duration(seconds: 20));
    controller.previousCue();
    expect(controller.state.position, delayedCue.start);

    controller.nextCue();
    expect(controller.state.position, thirdCue.start);

    controller.syncToCue(firstCue);
    expect(controller.state.position, firstCue.start);
  });

  test('restores and persists independent player settings', () async {
    controller.dispose();
    preferencesStore = MemoryPlayerPreferencesStore(
      const PlayerPreferences(
        position: Duration(seconds: 12),
        subtitleDelay: Duration(milliseconds: 500),
        playbackRate: 1.01,
        fontSize: 42,
      ),
    );
    controller = PlayerController(
      fileName: 'movie.srt',
      fileReference: 'cached/movie.srt',
      timeline: SubtitleTimeline([firstCue, delayedCue, thirdCue]),
      clock: PlaybackClock(timeSource: timeSource),
      preferencesStore: preferencesStore,
      preferences: preferencesStore.preferences,
      refreshInterval: null,
    );

    expect(controller.state.position, const Duration(seconds: 12));
    expect(controller.state.subtitleDelay, const Duration(milliseconds: 500));
    expect(controller.state.playbackRate, 1.01);
    expect(controller.state.fontSize, 42);

    await controller.persist();
    expect(preferencesStore.preferences.lastFileName, 'movie.srt');
    expect(preferencesStore.preferences.lastFileReference, 'cached/movie.srt');
  });

  test('serializes persistence and keeps the latest snapshot last', () async {
    controller.dispose();
    final serialStore = SerialCheckPlayerPreferencesStore();
    controller = PlayerController(
      fileName: 'movie.srt',
      fileReference: 'movie.srt',
      timeline: SubtitleTimeline([firstCue, delayedCue, thirdCue]),
      clock: PlaybackClock(timeSource: timeSource),
      preferencesStore: serialStore,
      refreshInterval: null,
    );

    controller.seek(const Duration(seconds: 10));
    controller.setSubtitleDelay(const Duration(milliseconds: 100));
    controller.adjustRate(PlayerController.rateStep);
    await controller.persist();

    expect(serialStore.maximumConcurrentSaves, 1);
    expect(serialStore.saved.last.position, const Duration(seconds: 10));
    expect(
      serialStore.saved.last.subtitleDelay,
      const Duration(milliseconds: 100),
    );
    expect(serialStore.saved.last.playbackRate, 1.001);
  });
}
