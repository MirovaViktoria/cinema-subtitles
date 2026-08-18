import 'dart:convert';

import 'package:cinema_subtitles/domain/subtitle_source.dart';
import 'package:cinema_subtitles/infrastructure/subtitle_document_loader.dart';
import 'package:cinema_subtitles/infrastructure/subtitle_file_loader.dart';
import 'package:cinema_subtitles/infrastructure/subtitle_package_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cache and private sources produce the same document payload', () async {
    const contents = '1\n00:00:01,000 --> 00:00:02,000\nHello\n';
    final bytes = utf8.encode(contents);
    final loader = SubtitleDocumentLoader(
      SubtitleFileLoader(),
      SubtitlePackageAdapter(),
    );
    final cacheSource = SubtitleSource(
      name: 'movie.srt',
      reference: 'cache/movie.srt',
      bytes: bytes,
      format: SubtitleFormat.srt,
    );
    final privateSource = SubtitleSource(
      name: 'movie.srt',
      reference: 'support/favorites/hash.srt',
      bytes: bytes,
      format: SubtitleFormat.srt,
      favoriteId: 'hash',
    );

    final cacheDocument = await loader.parse(cacheSource);
    final privateDocument = await loader.parse(privateSource);

    expect(cacheDocument.source.bytes, privateDocument.source.bytes);
    expect(cacheDocument.source.format, privateDocument.source.format);
    expect(cacheDocument.timeline.cues, hasLength(1));
    expect(privateDocument.timeline.cues, hasLength(1));
    expect(
      privateDocument.timeline.cues.single.text,
      cacheDocument.timeline.cues.single.text,
    );
  });
}
