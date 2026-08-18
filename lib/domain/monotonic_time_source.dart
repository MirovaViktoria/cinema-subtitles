abstract interface class MonotonicTimeSource {
  Duration get elapsed;
}

final class StopwatchTimeSource implements MonotonicTimeSource {
  StopwatchTimeSource() {
    _stopwatch.start();
  }

  final Stopwatch _stopwatch = Stopwatch();

  @override
  Duration get elapsed => _stopwatch.elapsed;
}
