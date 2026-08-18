import 'package:cinema_subtitles/domain/subtitle_timeline.dart';
import 'package:cinema_subtitles/domain/subtitle_source.dart';
import 'package:cinema_subtitles/infrastructure/subtitle_file_loader.dart';
import 'package:cinema_subtitles/infrastructure/subtitle_parser.dart';

final class SubtitleDocument {
  const SubtitleDocument({required this.source, required this.timeline});

  final SubtitleSource source;
  final SubtitleTimeline timeline;

  String get name => source.name;
  String get reference => source.reference;
}

abstract interface class SubtitleDocumentSource {
  Future<SubtitleDocument?> pick();
  Future<SubtitleDocument> reopen(String reference);
  Future<SubtitleDocument> parse(SubtitleSource source);
}

final class SubtitleDocumentLoader implements SubtitleDocumentSource {
  const SubtitleDocumentLoader(this._fileLoader, this._parser);

  final SubtitleFileLoader _fileLoader;
  final SubtitleParser _parser;

  @override
  Future<SubtitleDocument?> pick() async {
    final file = await _fileLoader.pick();
    return file == null ? null : parse(file);
  }

  @override
  Future<SubtitleDocument> reopen(String reference) async {
    return parse(await _fileLoader.reopen(reference));
  }

  @override
  Future<SubtitleDocument> parse(SubtitleSource source) async {
    final cues = await _parser.parse(
      contents: SubtitleFileLoader.decodeUtf8(source.bytes),
      format: source.format,
    );
    return SubtitleDocument(source: source, timeline: SubtitleTimeline(cues));
  }
}
