import 'package:cinema_subtitles/domain/subtitle_cue.dart';
import 'package:cinema_subtitles/features/player/subtitle_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('preserves long cues with increased system text scaling', (
    tester,
  ) async {
    final cues = [
      for (var index = 0; index < 3; index++)
        SubtitleCue(
          id: '$index',
          start: Duration.zero,
          end: const Duration(seconds: 10),
          text: 'Long subtitle cue $index ' * 8,
          sourceIndex: index,
        ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: SizedBox(
            width: 320,
            height: 180,
            child: SubtitleView(cues: cues, preferredFontSize: 42),
          ),
        ),
      ),
    );

    for (final cue in cues) {
      expect(find.byKey(ValueKey(cue.id)), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}
