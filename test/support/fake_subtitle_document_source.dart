import 'package:cinema_subtitles/domain/subtitle_source.dart';
import 'package:cinema_subtitles/infrastructure/subtitle_document_loader.dart';

final class FakeSubtitleDocumentSource implements SubtitleDocumentSource {
  FakeSubtitleDocumentSource({this.document, this.error});

  SubtitleDocument? document;
  Object? error;
  int pickCount = 0;
  int reopenCount = 0;

  @override
  Future<SubtitleDocument?> pick() async {
    pickCount++;
    if (error case final currentError?) {
      throw currentError;
    }
    return document;
  }

  @override
  Future<SubtitleDocument> reopen(String reference) async {
    reopenCount++;
    if (error case final currentError?) {
      throw currentError;
    }
    return document!;
  }

  @override
  Future<SubtitleDocument> parse(SubtitleSource source) async {
    if (error case final currentError?) {
      throw currentError;
    }
    return SubtitleDocument(source: source, timeline: document!.timeline);
  }
}
