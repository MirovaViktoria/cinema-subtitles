import 'package:cinema_subtitles/domain/subtitle_cue.dart';
import 'package:cinema_subtitles/infrastructure/subtitle_parser.dart';
import 'package:subtitle/subtitle.dart' as package;

final class SubtitlePackageAdapter implements SubtitleParser {
  @override
  Future<List<SubtitleCue>> parse({
    required String contents,
    required SubtitleFormat format,
  }) async {
    final normalizedContents = contents.replaceFirst('\uFEFF', '').trim();
    if (normalizedContents.isEmpty) {
      throw const SubtitleParseException(
        SubtitleParseFailureKind.emptyFile,
        'The subtitle file is empty.',
      );
    }
    if (format == SubtitleFormat.webVtt &&
        !normalizedContents.startsWith('WEBVTT')) {
      throw const SubtitleParseException(
        SubtitleParseFailureKind.invalidSyntax,
        'The WebVTT header is missing.',
      );
    }

    try {
      final timedBlockCount = _validateTimedBlocks(normalizedContents, format);
      final parsed = package.SubtitleParser(
        package.SubtitleObject(
          data: normalizedContents,
          type: switch (format) {
            SubtitleFormat.srt => package.SubtitleType.srt,
            SubtitleFormat.webVtt => package.SubtitleType.vtt,
          },
        ),
      ).parsing(shouldNormalizeText: false);

      if (parsed.isEmpty || parsed.length != timedBlockCount) {
        throw const SubtitleParseException(
          SubtitleParseFailureKind.invalidSyntax,
          'One or more subtitle cues could not be parsed.',
        );
      }

      return [
        for (final (sourceIndex, parsedCue) in parsed.indexed)
          _toDomainCue(parsedCue, sourceIndex),
      ];
    } on SubtitleParseException {
      rethrow;
    } on ArgumentError catch (error) {
      throw SubtitleParseException(
        SubtitleParseFailureKind.invalidCue,
        'A subtitle cue has an invalid time range.',
        error,
      );
    } on Object catch (error) {
      throw SubtitleParseException(
        SubtitleParseFailureKind.invalidSyntax,
        'The subtitle file could not be parsed.',
        error,
      );
    }
  }

  SubtitleCue _toDomainCue(package.Subtitle cue, int sourceIndex) {
    return SubtitleCue(
      id: '${sourceIndex}_${cue.index}',
      start: cue.start,
      end: cue.end,
      text: _normalizeText(cue.data),
      sourceIndex: sourceIndex,
    );
  }

  String _normalizeText(String text) {
    return text
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();
  }

  int _validateTimedBlocks(String contents, SubtitleFormat format) {
    final blocks = contents
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split(RegExp(r'\n{2,}'));
    final timingLinePattern = RegExp(
      r'^(?:\d+:)?\d{2}:\d{2}[.,]\d{1,3}\s*-->\s*'
      r'(?:\d+:)?\d{2}:\d{2}[.,]\d{1,3}(?:\s+.*)?$',
    );
    var count = 0;

    for (final block in blocks) {
      final trimmed = block.trim();
      if (trimmed.isEmpty ||
          (format == SubtitleFormat.webVtt &&
              (trimmed.startsWith('WEBVTT') ||
                  trimmed.startsWith('NOTE') ||
                  trimmed.startsWith('STYLE') ||
                  trimmed.startsWith('REGION')))) {
        continue;
      }

      final lines = trimmed.split('\n');
      final timingIndexes = <int>[
        for (var index = 0; index < lines.length; index++)
          if (timingLinePattern.hasMatch(lines[index].trim())) index,
      ];
      if (timingIndexes.length != 1 ||
          lines.sublist(timingIndexes.single + 1).join('\n').trim().isEmpty) {
        throw const SubtitleParseException(
          SubtitleParseFailureKind.invalidSyntax,
          'One or more subtitle cues have invalid syntax.',
        );
      }
      count++;
    }
    return count;
  }
}
