import 'package:cinema_subtitles/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_subtitle_document_source.dart';
import '../support/memory_favorite_subtitle_repository.dart';
import '../support/memory_player_preferences_store.dart';
import '../support/memory_screen_wake_lock.dart';

void main() {
  testWidgets('shows the project-ready screen', (tester) async {
    await tester.pumpWidget(
      CinemaSubtitlesApp(
        documentSource: FakeSubtitleDocumentSource(),
        favoriteRepository: MemoryFavoriteSubtitleRepository(),
        preferencesStore: MemoryPlayerPreferencesStore(),
        wakeLock: MemoryScreenWakeLock(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cinema Subtitles'), findsOneWidget);
    expect(find.text('Offline subtitle clock'), findsOneWidget);
    expect(find.text('Open subtitle file'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('open-subtitle-file-button')),
          )
          .onPressed,
      isNotNull,
    );
  });
}
