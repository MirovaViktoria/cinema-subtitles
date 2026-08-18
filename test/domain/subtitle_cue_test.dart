import 'package:cinema_subtitles/domain/subtitle_cue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preserves valid cue data', () {
    final cue = SubtitleCue(
      id: '7',
      start: const Duration(seconds: 10),
      end: const Duration(seconds: 15),
      text: 'Hello',
      sourceIndex: 3,
    );

    expect(cue.duration, const Duration(seconds: 5));
    expect(cue.text, 'Hello');
    expect(cue.sourceIndex, 3);
  });

  test('rejects invalid time ranges', () {
    expect(
      () => SubtitleCue(
        id: 'negative',
        start: const Duration(milliseconds: -1),
        end: const Duration(seconds: 1),
        text: 'Invalid',
        sourceIndex: 0,
      ),
      throwsArgumentError,
    );
    expect(
      () => SubtitleCue(
        id: 'empty',
        start: const Duration(seconds: 1),
        end: const Duration(seconds: 1),
        text: 'Invalid',
        sourceIndex: 0,
      ),
      throwsArgumentError,
    );
  });
}
