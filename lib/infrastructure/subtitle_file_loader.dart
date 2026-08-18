import 'dart:convert';

import 'package:cinema_subtitles/infrastructure/subtitle_parser.dart';
import 'package:file_selector/file_selector.dart';

final class SubtitleFileContents {
  const SubtitleFileContents({
    required this.name,
    required this.reference,
    required this.contents,
    required this.format,
  });

  final String name;
  final String reference;
  final String contents;
  final SubtitleFormat format;
}

enum SubtitleFileFailureKind { unsupportedFormat, unreadable, encoding }

final class SubtitleFileException implements Exception {
  const SubtitleFileException(this.kind, this.message, [this.cause]);

  final SubtitleFileFailureKind kind;
  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

final class SubtitleFileLoader {
  static const _subtitleTypes = XTypeGroup(
    label: 'Subtitles',
    extensions: ['srt', 'vtt'],
    mimeTypes: ['application/x-subrip', 'text/vtt', 'text/plain'],
  );

  Future<SubtitleFileContents?> pick() async {
    final file = await openFile(acceptedTypeGroups: [_subtitleTypes]);
    if (file == null) {
      return null;
    }
    return _read(file);
  }

  Future<SubtitleFileContents> reopen(String reference) {
    return _read(XFile(reference));
  }

  Future<SubtitleFileContents> _read(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final name = file.name;
      final contents = decodeUtf8(bytes);
      return SubtitleFileContents(
        name: name,
        reference: file.path,
        contents: contents,
        format: detectFormat(name, contents: contents),
      );
    } on SubtitleFileException {
      rethrow;
    } on Object catch (error) {
      throw SubtitleFileException(
        SubtitleFileFailureKind.unreadable,
        'The selected subtitle file could not be read.',
        error,
      );
    }
  }

  static SubtitleFormat detectFormat(String name, {String? contents}) {
    final lowerName = name.toLowerCase();
    if (lowerName.endsWith('.srt')) {
      return SubtitleFormat.srt;
    }
    if (lowerName.endsWith('.vtt')) {
      return SubtitleFormat.webVtt;
    }
    final normalizedContents = contents?.replaceFirst('\uFEFF', '').trimLeft();
    if (normalizedContents?.startsWith('WEBVTT') ?? false) {
      return SubtitleFormat.webVtt;
    }
    if (normalizedContents != null &&
        RegExp(
          r'^(?:\d+\s*\n)?(?:\d+:)?\d{2}:\d{2},\d{1,3}\s*-->',
          multiLine: true,
        ).hasMatch(normalizedContents)) {
      return SubtitleFormat.srt;
    }
    throw const SubtitleFileException(
      SubtitleFileFailureKind.unsupportedFormat,
      'Only SRT and WebVTT files are supported.',
    );
  }

  static String decodeUtf8(List<int> bytes) {
    try {
      return utf8.decode(bytes).replaceFirst('\uFEFF', '');
    } on FormatException catch (error) {
      throw SubtitleFileException(
        SubtitleFileFailureKind.encoding,
        'The subtitle file must use UTF-8 encoding.',
        error,
      );
    }
  }
}
