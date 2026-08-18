import 'package:cinema_subtitles/domain/subtitle_cue.dart';

enum SubtitleFormat { srt, webVtt }

abstract interface class SubtitleParser {
  Future<List<SubtitleCue>> parse({
    required String contents,
    required SubtitleFormat format,
  });
}

enum SubtitleParseFailureKind { emptyFile, invalidSyntax, invalidCue }

final class SubtitleParseException implements Exception {
  const SubtitleParseException(this.kind, this.message, [this.cause]);

  final SubtitleParseFailureKind kind;
  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
