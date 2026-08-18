import 'package:cinema_subtitles/domain/monotonic_time_source.dart';

final class FakeMonotonicTimeSource implements MonotonicTimeSource {
  @override
  Duration elapsed = Duration.zero;

  void advance(Duration duration) {
    if (duration.isNegative) {
      throw ArgumentError.value(duration, 'duration', 'Must not be negative.');
    }
    elapsed += duration;
  }
}
