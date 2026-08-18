final class SubtitleCue {
  SubtitleCue({
    required this.id,
    required this.start,
    required this.end,
    required this.text,
    required this.sourceIndex,
  }) {
    if (start.isNegative) {
      throw ArgumentError.value(start, 'start', 'Must not be negative.');
    }
    if (end <= start) {
      throw ArgumentError.value(end, 'end', 'Must be greater than start.');
    }
    if (sourceIndex < 0) {
      throw ArgumentError.value(
        sourceIndex,
        'sourceIndex',
        'Must not be negative.',
      );
    }
  }

  final String id;
  final Duration start;
  final Duration end;
  final String text;
  final int sourceIndex;

  Duration get duration => end - start;
}
