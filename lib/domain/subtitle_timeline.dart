import 'package:cinema_subtitles/domain/subtitle_cue.dart';

final class SubtitleTimeline {
  SubtitleTimeline(Iterable<SubtitleCue> cues)
    : _cues = List<SubtitleCue>.of(cues) {
    _cues.sort((left, right) {
      final startComparison = left.start.compareTo(right.start);
      if (startComparison != 0) {
        return startComparison;
      }
      final sourceComparison = left.sourceIndex.compareTo(right.sourceIndex);
      if (sourceComparison != 0) {
        return sourceComparison;
      }
      return left.id.compareTo(right.id);
    });

    _prefixMaxEnd = List<Duration>.filled(_cues.length, Duration.zero);
    var maxEnd = Duration.zero;
    for (var index = 0; index < _cues.length; index++) {
      if (_cues[index].end > maxEnd) {
        maxEnd = _cues[index].end;
      }
      _prefixMaxEnd[index] = maxEnd;
    }

    _cuesByEnd = List<SubtitleCue>.of(_cues)
      ..sort((left, right) {
        final endComparison = left.end.compareTo(right.end);
        if (endComparison != 0) {
          return endComparison;
        }
        final startComparison = left.start.compareTo(right.start);
        if (startComparison != 0) {
          return startComparison;
        }
        final sourceComparison = left.sourceIndex.compareTo(right.sourceIndex);
        if (sourceComparison != 0) {
          return sourceComparison;
        }
        return left.id.compareTo(right.id);
      });
  }

  final List<SubtitleCue> _cues;
  late final List<Duration> _prefixMaxEnd;
  late final List<SubtitleCue> _cuesByEnd;

  List<SubtitleCue> get cues => List.unmodifiable(_cues);

  Duration get duration =>
      _prefixMaxEnd.isEmpty ? Duration.zero : _prefixMaxEnd.last;

  List<SubtitleCue> activeAt(Duration position) {
    if (position.isNegative || _cues.isEmpty) {
      return const [];
    }

    final endExclusive = _upperBound(position);
    final active = <SubtitleCue>[];

    for (var index = endExclusive - 1; index >= 0; index--) {
      if (_prefixMaxEnd[index] <= position) {
        break;
      }

      final cue = _cues[index];
      if (cue.start <= position && position < cue.end) {
        active.add(cue);
      }
    }

    return active.reversed.toList(growable: false);
  }

  SubtitleCue? latestEndedAt(Duration position) {
    if (position <= Duration.zero || _cuesByEnd.isEmpty) {
      return null;
    }

    final endExclusive = _endUpperBound(position);
    if (endExclusive == 0) {
      return null;
    }

    return _cuesByEnd[endExclusive - 1];
  }

  SubtitleCue? nextAfter(Duration position) {
    final index = _upperBound(position);
    return index < _cues.length ? _cues[index] : null;
  }

  SubtitleCue? previousBefore(Duration position) {
    final index = _lowerBound(position) - 1;
    return index >= 0 ? _cues[index] : null;
  }

  List<SubtitleCue> nearby(Duration position, {int before = 3, int after = 5}) {
    if (before < 0 || after < 0) {
      throw ArgumentError('Nearby counts must not be negative.');
    }
    if (_cues.isEmpty) {
      return const [];
    }

    final pivot = _lowerBound(position);
    final start = (pivot - before).clamp(0, _cues.length);
    final end = (pivot + after + 1).clamp(start, _cues.length);
    return List.unmodifiable(_cues.sublist(start, end));
  }

  int _lowerBound(Duration position) {
    var low = 0;
    var high = _cues.length;
    while (low < high) {
      final middle = low + ((high - low) >> 1);
      if (_cues[middle].start < position) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }

  int _upperBound(Duration position) {
    var low = 0;
    var high = _cues.length;
    while (low < high) {
      final middle = low + ((high - low) >> 1);
      if (_cues[middle].start <= position) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }

  int _endUpperBound(Duration position) {
    var low = 0;
    var high = _cuesByEnd.length;
    while (low < high) {
      final middle = low + ((high - low) >> 1);
      if (_cuesByEnd[middle].end <= position) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }
}
