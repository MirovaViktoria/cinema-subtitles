import 'package:cinema_subtitles/domain/subtitle_timeline.dart';
import 'package:cinema_subtitles/infrastructure/subtitle_file_loader.dart';
import 'package:cinema_subtitles/infrastructure/subtitle_parser.dart';

final class SubtitleDocument {
  const SubtitleDocument({
    required this.name,
    required this.reference,
    required this.timeline,
  });

  final String name;
  final String reference;
  final SubtitleTimeline timeline;
}

abstract interface class SubtitleDocumentSource {
  Future<SubtitleDocument?> pick();
  Future<SubtitleDocument> reopen(String reference);
}

final class SubtitleDocumentLoader implements SubtitleDocumentSource {
  const SubtitleDocumentLoader(this._fileLoader, this._parser);

  final SubtitleFileLoader _fileLoader;
  final SubtitleParser _parser;

  @override
  Future<SubtitleDocument?> pick() async {
    final file = await _fileLoader.pick();
    return file == null ? null : _parse(file);
  }

  @override
  Future<SubtitleDocument> reopen(String reference) async {
    return _parse(await _fileLoader.reopen(reference));
  }

  Future<SubtitleDocument> _parse(SubtitleFileContents file) async {
    final cues = await _parser.parse(
      contents: file.contents,
      format: file.format,
    );
    return SubtitleDocument(
      name: file.name,
      reference: file.reference,
      timeline: SubtitleTimeline(cues),
    );
  }
}
