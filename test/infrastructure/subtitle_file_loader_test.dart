import 'package:cinema_subtitles/infrastructure/subtitle_file_loader.dart';
import 'package:cinema_subtitles/infrastructure/subtitle_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detects supported formats case-insensitively', () {
    expect(SubtitleFileLoader.detectFormat('movie.SRT'), SubtitleFormat.srt);
    expect(SubtitleFileLoader.detectFormat('movie.vtt'), SubtitleFormat.webVtt);
  });

  test('rejects unsupported formats', () {
    expect(
      () => SubtitleFileLoader.detectFormat('movie.ass'),
      throwsA(
        isA<SubtitleFileException>().having(
          (error) => error.kind,
          'kind',
          SubtitleFileFailureKind.unsupportedFormat,
        ),
      ),
    );
  });

  test('sniffs SRT content when an Android cache file has a txt suffix', () {
    expect(
      SubtitleFileLoader.detectFormat(
        'cached-file.txt',
        contents: '1\n00:00:01,000 --> 00:00:02,000\nHello',
      ),
      SubtitleFormat.srt,
    );
  });

  test('decodes UTF-8 and removes a byte-order mark', () {
    expect(SubtitleFileLoader.decodeUtf8([0xEF, 0xBB, 0xBF, 0x48, 0x69]), 'Hi');
  });

  test('reports invalid UTF-8 encoding', () {
    expect(
      () => SubtitleFileLoader.decodeUtf8([0xC3, 0x28]),
      throwsA(
        isA<SubtitleFileException>().having(
          (error) => error.kind,
          'kind',
          SubtitleFileFailureKind.encoding,
        ),
      ),
    );
  });
}
