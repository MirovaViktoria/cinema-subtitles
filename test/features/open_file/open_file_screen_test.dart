import 'dart:async';
import 'dart:convert';

import 'package:cinema_subtitles/app/app.dart';
import 'package:cinema_subtitles/domain/subtitle_cue.dart';
import 'package:cinema_subtitles/domain/subtitle_timeline.dart';
import 'package:cinema_subtitles/domain/subtitle_source.dart';
import 'package:cinema_subtitles/features/favorites/favorite_subtitle.dart';
import 'package:cinema_subtitles/features/settings/player_preferences.dart';
import 'package:cinema_subtitles/infrastructure/subtitle_document_loader.dart';
import 'package:cinema_subtitles/infrastructure/subtitle_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_subtitle_document_source.dart';
import '../../support/memory_favorite_subtitle_repository.dart';
import '../../support/memory_player_preferences_store.dart';
import '../../support/memory_screen_wake_lock.dart';

void main() {
  SubtitleDocument document() {
    return SubtitleDocument(
      source: SubtitleSource(
        name: 'movie.srt',
        reference: 'cache/movie.srt',
        bytes: const [49],
        format: SubtitleFormat.srt,
      ),
      timeline: SubtitleTimeline([
        SubtitleCue(
          id: 'cue',
          start: Duration.zero,
          end: const Duration(seconds: 5),
          text: 'Opened successfully',
          sourceIndex: 0,
        ),
      ]),
    );
  }

  ({FavoriteSubtitle entry, SubtitleSource source}) favorite() {
    const id = 'favorite-id';
    final source = SubtitleSource(
      name: 'favorite.srt',
      reference: 'memory/favorites/favorite.srt',
      bytes: utf8.encode('1\n00:00:01,000 --> 00:00:02,000\nFavorite\n'),
      format: SubtitleFormat.srt,
      favoriteId: id,
    );
    return (
      entry: FavoriteSubtitle(
        id: id,
        displayName: source.name,
        format: source.format,
        privatePath: source.reference,
        addedAt: DateTime.utc(2026, 8, 18),
      ),
      source: source,
    );
  }

  testWidgets('opens a selected subtitle document', (tester) async {
    final source = FakeSubtitleDocumentSource(document: document());
    await tester.pumpWidget(
      CinemaSubtitlesApp(
        documentSource: source,
        favoriteRepository: MemoryFavoriteSubtitleRepository(),
        preferencesStore: MemoryPlayerPreferencesStore(),
        wakeLock: MemoryScreenWakeLock(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open subtitle file'));
    await tester.pumpAndSettle();

    expect(find.text('movie.srt'), findsOneWidget);
    expect(find.text('Opened successfully'), findsOneWidget);
  });

  testWidgets('shows a parser error without leaving the open screen', (
    tester,
  ) async {
    final source = FakeSubtitleDocumentSource(
      error: const SubtitleParseException(
        SubtitleParseFailureKind.invalidSyntax,
        'Broken subtitle file',
      ),
    );
    await tester.pumpWidget(
      CinemaSubtitlesApp(
        documentSource: source,
        favoriteRepository: MemoryFavoriteSubtitleRepository(),
        preferencesStore: MemoryPlayerPreferencesStore(),
        wakeLock: MemoryScreenWakeLock(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open subtitle file'));
    await tester.pumpAndSettle();

    expect(find.text('Broken subtitle file'), findsOneWidget);
    expect(find.text('Open subtitle file'), findsOneWidget);
  });

  testWidgets('lists and opens a persistent favorite', (tester) async {
    final saved = favorite();
    final repository = MemoryFavoriteSubtitleRepository(
      entries: [saved.entry],
      sources: {saved.entry.id: saved.source},
    );
    await tester.pumpWidget(
      CinemaSubtitlesApp(
        documentSource: FakeSubtitleDocumentSource(document: document()),
        favoriteRepository: repository,
        preferencesStore: MemoryPlayerPreferencesStore(),
        wakeLock: MemoryScreenWakeLock(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('favorite.srt'), findsOneWidget);
    expect(find.text('SRT'), findsOneWidget);

    await tester.tap(find.text('favorite.srt'));
    await tester.pumpAndSettle();

    expect(find.text('favorite.srt'), findsOneWidget);
    expect(find.text('Opened successfully'), findsOneWidget);
    expect(find.byTooltip('Remove from favorites'), findsOneWidget);
  });

  testWidgets('requires confirmation before deleting a favorite', (
    tester,
  ) async {
    final saved = favorite();
    final repository = MemoryFavoriteSubtitleRepository(
      entries: [saved.entry],
      sources: {saved.entry.id: saved.source},
    );
    final preferencesStore = MemoryPlayerPreferencesStore(
      PlayerPreferences(
        lastFileReference: saved.entry.privatePath,
        lastFileName: saved.entry.displayName,
      ),
    );
    await tester.pumpWidget(
      CinemaSubtitlesApp(
        documentSource: FakeSubtitleDocumentSource(document: document()),
        favoriteRepository: repository,
        preferencesStore: preferencesStore,
        wakeLock: MemoryScreenWakeLock(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('remove-favorite-${saved.entry.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('favorite.srt'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('remove-favorite-${saved.entry.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-remove-favorite-button')));
    await tester.pumpAndSettle();

    expect(find.text('favorite.srt'), findsNothing);
    expect(repository.removeCount, 1);
    expect(preferencesStore.preferences.lastFileReference, isNull);
    expect(find.byKey(const Key('reopen-last-file-button')), findsNothing);
  });

  testWidgets('shows cleanup action for an unavailable favorite', (
    tester,
  ) async {
    final saved = favorite();
    final broken = saved.entry.copyWith(isAvailable: false);
    final repository = MemoryFavoriteSubtitleRepository(entries: [broken]);
    await tester.pumpWidget(
      CinemaSubtitlesApp(
        documentSource: FakeSubtitleDocumentSource(document: document()),
        favoriteRepository: repository,
        preferencesStore: MemoryPlayerPreferencesStore(),
        wakeLock: MemoryScreenWakeLock(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SRT · Private copy unavailable'), findsOneWidget);
    expect(
      find.byKey(ValueKey('remove-broken-favorite-${saved.entry.id}')),
      findsOneWidget,
    );

    await tester.tap(find.text('favorite.srt'));
    await tester.pumpAndSettle();

    expect(find.text('Missing favorite'), findsWidgets);
    expect(find.text('Open subtitle file'), findsOneWidget);
  });

  testWidgets('player add is reflected on home after navigation', (
    tester,
  ) async {
    final repository = MemoryFavoriteSubtitleRepository();
    await tester.pumpWidget(
      CinemaSubtitlesApp(
        documentSource: FakeSubtitleDocumentSource(document: document()),
        favoriteRepository: repository,
        preferencesStore: MemoryPlayerPreferencesStore(),
        wakeLock: MemoryScreenWakeLock(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open subtitle file'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add to favorites'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(repository.addCount, 1);
    expect(find.byType(Card), findsOneWidget);
    expect(find.text('movie.srt'), findsOneWidget);
  });

  testWidgets('blocks a second favorite open while navigation is pending', (
    tester,
  ) async {
    final first = favorite();
    final secondSource = SubtitleSource(
      name: 'second.srt',
      reference: 'memory/favorites/second.srt',
      bytes: utf8.encode('1\n00:00:01,000 --> 00:00:02,000\nSecond\n'),
      format: SubtitleFormat.srt,
      favoriteId: 'second-id',
    );
    final second = FavoriteSubtitle(
      id: 'second-id',
      displayName: secondSource.name,
      format: secondSource.format,
      privatePath: secondSource.reference,
      addedAt: DateTime.utc(2026, 8, 18, 1),
    );
    final repository = MemoryFavoriteSubtitleRepository(
      entries: [first.entry, second],
      sources: {first.entry.id: first.source, second.id: secondSource},
    );
    final gate = Completer<void>();
    repository.openGate = gate;
    await tester.pumpWidget(
      CinemaSubtitlesApp(
        documentSource: FakeSubtitleDocumentSource(document: document()),
        favoriteRepository: repository,
        preferencesStore: MemoryPlayerPreferencesStore(),
        wakeLock: MemoryScreenWakeLock(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('favorite.srt'));
    await tester.tap(find.text('second.srt'));

    expect(repository.openCount, 1);
    gate.complete();
    await tester.pumpAndSettle();
  });
}
