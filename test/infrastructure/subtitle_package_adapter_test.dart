import 'dart:io';

import 'package:cinema_subtitles/domain/subtitle_source.dart';
import 'package:cinema_subtitles/infrastructure/subtitle_package_adapter.dart';
import 'package:cinema_subtitles/infrastructure/subtitle_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SubtitlePackageAdapter parser;

  setUp(() {
    parser = SubtitlePackageAdapter();
  });

  Future<String> fixture(String name) {
    return File('test/fixtures/$name').readAsString();
  }

  test('preserves overlapping SRT cues', () async {
    final cues = await parser.parse(
      contents: await fixture('overlapping.srt'),
      format: SubtitleFormat.srt,
    );

    expect(cues, hasLength(2));
    expect(cues[0].start, const Duration(seconds: 10));
    expect(cues[0].end, const Duration(seconds: 20));
    expect(cues[1].start, const Duration(seconds: 15));
    expect(cues[1].end, const Duration(seconds: 18));
  });

  test('preserves a long cue and its nested cue', () async {
    final cues = await parser.parse(
      contents: await fixture('long-cue.srt'),
      format: SubtitleFormat.srt,
    );

    expect(cues, hasLength(2));
    expect(cues[0].end, const Duration(minutes: 1));
    expect(cues[1].start, const Duration(seconds: 24));
    expect(cues[1].end, const Duration(seconds: 27));
  });

  test('does not deduplicate cues with the same exact range', () async {
    final cues = await parser.parse(
      contents: await fixture('same-range.srt'),
      format: SubtitleFormat.srt,
    );

    expect(cues, hasLength(2));
    expect(cues.map((cue) => cue.text), ['First cue', 'Second cue']);
  });

  test('parses WebVTT and normalizes simple markup', () async {
    final cues = await parser.parse(
      contents: await fixture('sample.vtt'),
      format: SubtitleFormat.webVtt,
    );

    expect(cues, hasLength(2));
    expect(cues.first.text, 'Hello cinema');
    expect(cues.last.start, const Duration(seconds: 3));
  });

  test(
    'does not mistake an arrow in cue text for another timing block',
    () async {
      final cues = await parser.parse(
        contents: '''
1
00:00:01,000 --> 00:00:02,000
A --> B
''',
        format: SubtitleFormat.srt,
      );

      expect(cues, hasLength(1));
      expect(cues.single.text, 'A --> B');
    },
  );

  test('reports a malformed block instead of silently dropping it', () async {
    await expectLater(
      parser.parse(
        contents: '''
1
00:00:01,000 --> 00:00:02,000
Valid cue

2
missing timing line
Broken cue
''',
        format: SubtitleFormat.srt,
      ),
      throwsA(
        isA<SubtitleParseException>().having(
          (error) => error.kind,
          'kind',
          SubtitleParseFailureKind.invalidSyntax,
        ),
      ),
    );
  });

  test('reports malformed and empty files', () async {
    await expectLater(
      parser.parse(contents: '', format: SubtitleFormat.srt),
      throwsA(
        isA<SubtitleParseException>().having(
          (error) => error.kind,
          'kind',
          SubtitleParseFailureKind.emptyFile,
        ),
      ),
    );
    await expectLater(
      parser.parse(
        contents: await fixture('malformed.srt'),
        format: SubtitleFormat.srt,
      ),
      throwsA(
        isA<SubtitleParseException>().having(
          (error) => error.kind,
          'kind',
          SubtitleParseFailureKind.invalidSyntax,
        ),
      ),
    );
  });
}
