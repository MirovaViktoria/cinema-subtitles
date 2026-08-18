import 'package:cinema_subtitles/domain/monotonic_time_source.dart';

final class PlaybackClock {
  PlaybackClock({
    required MonotonicTimeSource timeSource,
    Duration initialPosition = Duration.zero,
    double initialRate = 1,
  }) : _timeSource = timeSource,
       _anchorPosition = _validatePosition(initialPosition),
       _rate = _validateRate(initialRate),
       _anchorElapsed = timeSource.elapsed;

  final MonotonicTimeSource _timeSource;

  Duration _anchorPosition;
  Duration _anchorElapsed;
  double _rate;
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;
  double get rate => _rate;

  Duration get position => _positionAt(_timeSource.elapsed);

  void play() {
    if (_isPlaying) {
      return;
    }

    final now = _timeSource.elapsed;
    _anchorPosition = _positionAt(now);
    _anchorElapsed = now;
    _isPlaying = true;
  }

  void pause() {
    if (!_isPlaying) {
      return;
    }

    final now = _timeSource.elapsed;
    _anchorPosition = _positionAt(now);
    _anchorElapsed = now;
    _isPlaying = false;
  }

  void seek(Duration target) {
    _anchorPosition = _validatePosition(target);
    _anchorElapsed = _timeSource.elapsed;
  }

  void seekBy(Duration delta) {
    final now = _timeSource.elapsed;
    final target = _positionAt(now) + delta;
    _anchorPosition = target.isNegative ? Duration.zero : target;
    _anchorElapsed = now;
  }

  void setRate(double newRate) {
    final validatedRate = _validateRate(newRate);
    final now = _timeSource.elapsed;
    _anchorPosition = _positionAt(now);
    _anchorElapsed = now;
    _rate = validatedRate;
  }

  Duration _positionAt(Duration now) {
    if (!_isPlaying) {
      return _anchorPosition;
    }

    final elapsedMicroseconds = (now - _anchorElapsed).inMicroseconds * _rate;
    return _anchorPosition +
        Duration(microseconds: elapsedMicroseconds.round());
  }

  static Duration _validatePosition(Duration position) {
    if (position.isNegative) {
      throw ArgumentError.value(position, 'position', 'Must not be negative.');
    }
    return position;
  }

  static double _validateRate(double rate) {
    if (!rate.isFinite || rate <= 0) {
      throw ArgumentError.value(rate, 'rate', 'Must be finite and positive.');
    }
    return rate;
  }
}
