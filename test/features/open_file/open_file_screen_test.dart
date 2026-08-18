import 'package:cinema_subtitles/app/app.dart';
import 'package:cinema_subtitles/domain/subtitle_cue.dart';
import 'package:cinema_subtitles/domain/subtitle_timeline.dart';
import 'package:cinema_subtitles/infrastructure/subtitle_document_loader.dart';
import 'package:cinema_subtitles/infrastructure/subtitle_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_subtitle_document_source.dart';
import '../../support/memory_player_preferences_store.dart';
import '../../support/memory_screen_wake_lock.dart';

void main() {
  SubtitleDocument document() {
    return SubtitleDocument(
      name: 'movie.srt',
      reference: 'cache/movie.srt',
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

  testWidgets('opens a selected subtitle document', (tester) async {
    final source = FakeSubtitleDocumentSource(document: document());
    await tester.pumpWidget(
      CinemaSubtitlesApp(
        documentSource: source,
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
}
