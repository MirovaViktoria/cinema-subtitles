import 'package:cinema_subtitles/domain/playback_clock.dart';
import 'package:cinema_subtitles/domain/subtitle_cue.dart';
import 'package:cinema_subtitles/domain/subtitle_timeline.dart';
import 'package:cinema_subtitles/features/player/player_controller.dart';
import 'package:cinema_subtitles/features/player/player_screen.dart';
import 'package:cinema_subtitles/features/settings/player_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_monotonic_time_source.dart';
import '../../support/memory_player_preferences_store.dart';
import '../../support/memory_screen_wake_lock.dart';

void main() {
  late FakeMonotonicTimeSource timeSource;
  late MemoryPlayerPreferencesStore preferencesStore;
  late MemoryScreenWakeLock wakeLock;
  late SubtitleCue longCue;
  late SubtitleCue shortCue;
  late SubtitleCue nextCue;
  late PlayerController controller;

  setUp(() {
    timeSource = FakeMonotonicTimeSource();
    preferencesStore = MemoryPlayerPreferencesStore();
    wakeLock = MemoryScreenWakeLock();
    longCue = SubtitleCue(
      id: 'long',
      start: const Duration(seconds: 10),
      end: const Duration(seconds: 60),
      text: 'Long-running cue',
      sourceIndex: 0,
    );
    shortCue = SubtitleCue(
      id: 'short',
      start: const Duration(seconds: 11),
      end: const Duration(seconds: 13),
      text: 'Short cue',
      sourceIndex: 1,
    );
    nextCue = SubtitleCue(
      id: 'next',
      start: const Duration(seconds: 70),
      end: const Duration(seconds: 75),
      text: 'Next cue',
      sourceIndex: 2,
    );
    controller = PlayerController(
      fileName: 'movie.srt',
      fileReference: 'movie.srt',
      timeline: SubtitleTimeline([longCue, shortCue, nextCue]),
      clock: PlaybackClock(timeSource: timeSource),
      preferencesStore: preferencesStore,
      preferences: const PlayerPreferences(position: Duration(seconds: 12)),
      refreshInterval: null,
    );
  });

  Future<void> pumpPlayer(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: PlayerScreen(controller: controller, wakeLock: wakeLock),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders all active cues and retains a long cue', (tester) async {
    await pumpPlayer(tester);

    expect(find.text('Long-running cue'), findsOneWidget);
    expect(find.text('Short cue'), findsOneWidget);

    controller.seek(const Duration(seconds: 30));
    await tester.pump();

    expect(find.text('Long-running cue'), findsOneWidget);
    expect(find.text('Short cue'), findsNothing);
  });

  testWidgets('play, rate and delay controls update state', (tester) async {
    await pumpPlayer(tester);

    await tester.tap(find.byKey(const Key('play-pause-button')));
    await tester.pump();
    expect(controller.state.isPlaying, isTrue);

    await tester.tap(find.text('+.001'));
    await tester.tap(find.text('+.1'));
    await tester.pump();

    expect(controller.state.playbackRate, 1.001);
    expect(controller.state.subtitleDelay, const Duration(milliseconds: 100));
  });

  testWidgets('jumps to an exact timestamp', (tester) async {
    await pumpPlayer(tester);

    await tester.tap(find.byKey(const Key('exact-timestamp-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0:00:25.000');
    await tester.tap(find.text('Jump'));
    await tester.pumpAndSettle();

    expect(controller.state.position, const Duration(seconds: 25));
  });

  testWidgets('nearby browser syncs to a selected cue', (tester) async {
    await pumpPlayer(tester);

    await tester.tap(find.byTooltip('Nearby cues'));
    await tester.pumpAndSettle();
    final syncButtons = find.text('Sync here');
    expect(syncButtons, findsWidgets);
    await tester.tap(syncButtons.last);
    await tester.pumpAndSettle();

    expect(controller.state.position, nextCue.start);
  });

  testWidgets('manages wake lock and pauses on background', (tester) async {
    await pumpPlayer(tester);
    controller.play();
    expect(wakeLock.enableCount, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(controller.state.isPlaying, isFalse);
    expect(wakeLock.disableCount, 1);
  });
}
