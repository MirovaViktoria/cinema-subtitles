import 'package:cinema_subtitles/domain/playback_clock.dart';
import 'package:cinema_subtitles/domain/subtitle_cue.dart';
import 'package:cinema_subtitles/domain/subtitle_timeline.dart';
import 'package:cinema_subtitles/domain/subtitle_source.dart';
import 'package:cinema_subtitles/features/favorites/favorite_subtitle.dart';
import 'package:cinema_subtitles/features/favorites/favorites_controller.dart';
import 'package:cinema_subtitles/features/player/player_controller.dart';
import 'package:cinema_subtitles/features/player/player_screen.dart';
import 'package:cinema_subtitles/features/settings/player_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_monotonic_time_source.dart';
import '../../support/memory_favorite_subtitle_repository.dart';
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
  late MemoryFavoriteSubtitleRepository favoriteRepository;
  late FavoritesController favoritesController;
  late SubtitleSource source;

  setUp(() async {
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
    source = SubtitleSource(
      name: 'movie.srt',
      reference: 'cache/movie.srt',
      bytes: const [49, 10, 48, 48, 58, 48, 48, 58, 48, 49, 44, 48, 48, 48],
      format: SubtitleFormat.srt,
    );
    favoriteRepository = MemoryFavoriteSubtitleRepository();
    favoritesController = FavoritesController(favoriteRepository);
    await favoritesController.load();
    addTearDown(favoritesController.dispose);
  });

  Future<void> pumpPlayer(
    WidgetTester tester, {
    Size size = const Size(412, 915),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: PlayerScreen(
          controller: controller,
          wakeLock: wakeLock,
          source: source,
          favoritesController: favoritesController,
        ),
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

    await tester.tap(find.byTooltip('Player options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nearby cues'));
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

  testWidgets('hides all controls and restores them from subtitle area', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpPlayer(tester);

    expect(find.byKey(const Key('exact-timestamp-button')), findsOneWidget);
    expect(find.byKey(const Key('rate-readout')), findsOneWidget);

    await tester.tap(find.byKey(const Key('hide-controls-button')));
    await tester.pump();

    expect(find.byKey(const Key('exact-timestamp-button')), findsNothing);
    expect(find.byKey(const Key('rate-readout')), findsNothing);
    expect(find.byKey(const Key('play-pause-button')), findsNothing);
    expect(find.text('Long-running cue'), findsOneWidget);
    expect(find.text('Short cue'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Show player controls')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('focus-subtitle-area')));
    await tester.pump();

    expect(find.byKey(const Key('hide-controls-button')), findsOneWidget);
    expect(find.byKey(const Key('play-pause-button')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('focus mode does not change playback or synchronization state', (
    tester,
  ) async {
    await pumpPlayer(tester);
    controller.setRate(1.001);
    controller.setSubtitleDelay(const Duration(milliseconds: 100));
    controller.play();
    final position = controller.state.position;

    await tester.tap(find.byKey(const Key('hide-controls-button')));
    await tester.pump();

    expect(controller.state.position, position);
    expect(controller.state.isPlaying, isTrue);
    expect(controller.state.playbackRate, 1.001);
    expect(controller.state.subtitleDelay, const Duration(milliseconds: 100));
    expect(controller.state.activeCues, [longCue, shortCue]);
  });

  testWidgets('focus mode preserves long text layout fallback', (tester) async {
    final longText = List.filled(
      80,
      'A long subtitle line that must remain available.',
    ).join(' ');
    final cue = SubtitleCue(
      id: 'long-text',
      start: Duration.zero,
      end: const Duration(minutes: 1),
      text: longText,
      sourceIndex: 0,
    );
    controller = PlayerController(
      fileName: 'movie.srt',
      fileReference: 'movie.srt',
      timeline: SubtitleTimeline([cue]),
      clock: PlaybackClock(timeSource: timeSource),
      preferencesStore: preferencesStore,
      refreshInterval: null,
    );
    await pumpPlayer(tester);

    await tester.tap(find.byKey(const Key('hide-controls-button')));
    await tester.pump();

    expect(find.byKey(const ValueKey('long-text')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adds and removes the current favorite without stopping cues', (
    tester,
  ) async {
    await pumpPlayer(tester);
    final position = controller.state.position;

    await tester.tap(find.byTooltip('Add to favorites'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Remove from favorites'), findsOneWidget);
    expect(favoritesController.state.entries, hasLength(1));
    expect(find.text('Saved to favorites'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove from favorites'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(favoritesController.state.entries, hasLength(1));

    await tester.tap(find.byTooltip('Remove from favorites'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('confirm-player-remove-favorite-button')),
    );
    await tester.pumpAndSettle();

    expect(favoritesController.state.entries, isEmpty);
    expect(find.text('Long-running cue'), findsOneWidget);
    expect(controller.state.position, position);
  });

  testWidgets('shows a recoverable favorite add error', (tester) async {
    favoriteRepository.addError = const FavoriteSubtitleException(
      FavoriteSubtitleFailureKind.storage,
      'No space for favorite',
    );
    await pumpPlayer(tester);

    await tester.tap(find.byTooltip('Add to favorites'));
    await tester.pumpAndSettle();

    expect(find.text('No space for favorite'), findsWidgets);
    expect(find.byTooltip('Add to favorites'), findsOneWidget);
  });

  testWidgets('duplicate content becomes filled without another entry', (
    tester,
  ) async {
    await favoriteRepository.add(source);
    await favoritesController.load();
    await pumpPlayer(tester);

    expect(find.byTooltip('Add to favorites'), findsOneWidget);
    await tester.tap(find.byTooltip('Add to favorites'));
    await tester.pumpAndSettle();

    expect(favoritesController.state.entries, hasLength(1));
    expect(find.byTooltip('Remove from favorites'), findsOneWidget);
  });

  testWidgets('each new player starts with visible controls', (tester) async {
    await pumpPlayer(tester);
    await tester.tap(find.byKey(const Key('hide-controls-button')));
    await tester.pump();
    expect(find.byKey(const Key('hide-controls-button')), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    controller = PlayerController(
      fileName: 'movie.srt',
      fileReference: 'movie.srt',
      timeline: SubtitleTimeline([longCue, shortCue, nextCue]),
      clock: PlaybackClock(timeSource: timeSource),
      preferencesStore: preferencesStore,
      preferences: const PlayerPreferences(position: Duration(seconds: 12)),
      refreshInterval: null,
    );
    await pumpPlayer(tester);

    expect(find.byKey(const Key('hide-controls-button')), findsOneWidget);
    expect(find.byKey(const Key('play-pause-button')), findsOneWidget);
  });

  testWidgets('compact Android width does not overflow the header', (
    tester,
  ) async {
    await pumpPlayer(tester, size: const Size(320, 700));

    expect(find.byKey(const Key('favorite-button')), findsOneWidget);
    expect(find.byTooltip('Player options'), findsOneWidget);
    expect(find.byKey(const Key('hide-controls-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('duplicate private source removal clears restorable reference', (
    tester,
  ) async {
    final entry = await favoriteRepository.add(source);
    await favoritesController.load();
    source = SubtitleSource(
      name: source.name,
      reference: entry.privatePath,
      bytes: source.bytes,
      format: source.format,
    );
    controller = PlayerController(
      fileName: source.name,
      fileReference: source.reference,
      timeline: SubtitleTimeline([longCue, shortCue, nextCue]),
      clock: PlaybackClock(timeSource: timeSource),
      preferencesStore: preferencesStore,
      preferences: const PlayerPreferences(position: Duration(seconds: 12)),
      refreshInterval: null,
    );
    await pumpPlayer(tester);

    await tester.tap(find.byTooltip('Add to favorites'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove from favorites'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('confirm-player-remove-favorite-button')),
    );
    await tester.pumpAndSettle();
    await controller.persist();

    expect(preferencesStore.preferences.lastFileReference, isNull);
    expect(find.text('Long-running cue'), findsOneWidget);
  });
}
