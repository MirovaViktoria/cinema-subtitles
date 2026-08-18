enum SubtitleFormat { srt, webVtt }

final class SubtitleSource {
  SubtitleSource({
    required this.name,
    required this.reference,
    required List<int> bytes,
    required this.format,
    this.favoriteId,
  }) : bytes = List.unmodifiable(bytes);

  final String name;
  final String reference;
  final List<int> bytes;
  final SubtitleFormat format;
  final String? favoriteId;
}
