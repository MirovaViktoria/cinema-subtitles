import 'dart:async';

import 'package:cinema_subtitles/domain/playback_clock.dart';
import 'package:cinema_subtitles/domain/subtitle_cue.dart';
import 'package:cinema_subtitles/domain/subtitle_timeline.dart';
import 'package:cinema_subtitles/features/player/player_state.dart';
import 'package:cinema_subtitles/features/settings/player_preferences.dart';
import 'package:flutter/foundation.dart';

final class PlayerController extends ChangeNotifier {
  factory PlayerController({
    required String fileName,
    required String fileReference,
    required SubtitleTimeline timeline,
    required PlaybackClock clock,
    required PlayerPreferencesStore preferencesStore,
    PlayerPreferences preferences = const PlayerPreferences(),
    Duration? refreshInterval = const Duration(milliseconds: 75),
  }) {
    return PlayerController._(
      fileName,
      fileReference,
      timeline,
      clock,
      preferencesStore,
      preferences,
      refreshInterval,
    );
  }

  PlayerController._(
    this._fileName,
    this._fileReference,
    this._timeline,
    this._clock,
    this._preferencesStore,
    PlayerPreferences preferences,
    this._refreshInterval,
  ) : _subtitleDelay = _clampDelay(preferences.subtitleDelay),
      _fontSize = preferences.fontSize.clamp(18, 72),
      _oledMode = preferences.oledMode {
    final restoredPosition = preferences.position.isNegative
        ? Duration.zero
        : preferences.position;
    _clock.seek(_clampToTimeline(restoredPosition));
    final restoredRate = preferences.playbackRate;
    _clock.setRate(
      restoredRate.isFinite && restoredRate >= 0.5 && restoredRate <= 2
          ? restoredRate
          : 1,
    );
    _state = _buildState();
  }

  static const rateStep = 0.001;
  static const fontSizeStep = 2.0;

  final String _fileName;
  final String _fileReference;
  final SubtitleTimeline _timeline;
  final PlaybackClock _clock;
  final PlayerPreferencesStore _preferencesStore;
  final Duration? _refreshInterval;

  late PlayerState _state;
  Duration _subtitleDelay;
  double _fontSize;
  bool _oledMode;
  Timer? _refreshTimer;
  Future<void> _saveQueue = Future.value();

  PlayerState get state => _state;

  void play() {
    if (_timeline.duration == Duration.zero) {
      return;
    }
    if (_clock.position >= _timeline.duration) {
      _clock.seek(Duration.zero);
    }
    _clock.play();
    _startRefreshTimer();
    refresh();
  }

  void pause() {
    _clock.pause();
    _stopRefreshTimer();
    refresh();
    unawaited(persist());
  }

  void togglePlayPause() => _clock.isPlaying ? pause() : play();

  void seek(Duration target) {
    _clock.seek(_clampToTimeline(target));
    refresh();
    unawaited(persist());
  }

  void seekBy(Duration delta) => seek(_clock.position + delta);

  void setRate(double rate) {
    _clock.setRate(rate.clamp(0.5, 2));
    refresh();
    unawaited(persist());
  }

  void adjustRate(double delta) => setRate(_clock.rate + delta);

  void resetRate() => setRate(1);

  void setSubtitleDelay(Duration delay) {
    _subtitleDelay = _clampDelay(delay);
    refresh();
    unawaited(persist());
  }

  void adjustSubtitleDelay(Duration delta) {
    setSubtitleDelay(_subtitleDelay + delta);
  }

  void resetSubtitleDelay() => setSubtitleDelay(Duration.zero);

  void previousCue() {
    final cue = _timeline.previousBefore(_clock.position);
    if (cue != null) {
      seek(cue.start);
    }
  }

  void nextCue() {
    final cue = _timeline.nextAfter(_clock.position);
    if (cue != null) {
      seek(cue.start);
    }
  }

  void syncToCue(SubtitleCue cue) => seek(cue.start);

  void increaseFontSize() => setFontSize(_fontSize + fontSizeStep);

  void decreaseFontSize() => setFontSize(_fontSize - fontSizeStep);

  void setFontSize(double size) {
    _fontSize = size.clamp(18, 72);
    refresh();
    unawaited(persist());
  }

  void setOledMode(bool enabled) {
    _oledMode = enabled;
    refresh();
    unawaited(persist());
  }

  void refresh() {
    if (_clock.isPlaying && _clock.position >= _timeline.duration) {
      _clock.pause();
      _clock.seek(_timeline.duration);
      _stopRefreshTimer();
      unawaited(persist());
    }
    _state = _buildState();
    notifyListeners();
  }

  Future<void> persist() {
    final snapshot = PlayerPreferences(
      position: _clock.position,
      subtitleDelay: _subtitleDelay,
      playbackRate: _clock.rate,
      fontSize: _fontSize,
      oledMode: _oledMode,
      lastFileReference: _fileReference,
      lastFileName: _fileName,
    );
    _saveQueue = _saveQueue.then((_) async {
      try {
        await _preferencesStore.save(snapshot);
      } on Object {
        // An inaccessible settings backend must not interrupt playback.
      }
    });
    return _saveQueue;
  }

  PlayerState _buildState() {
    final position = _clock.position;
    final lookupTime = position - _subtitleDelay;
    return PlayerState(
      fileName: _fileName,
      isPlaying: _clock.isPlaying,
      position: position,
      duration: _timeline.duration,
      subtitleDelay: _subtitleDelay,
      playbackRate: _clock.rate,
      fontSize: _fontSize,
      oledMode: _oledMode,
      activeCues: List.unmodifiable(_timeline.activeAt(lookupTime)),
      nearbyCues: _timeline.nearby(lookupTime),
    );
  }

  Duration _clampToTimeline(Duration position) {
    if (position.isNegative) {
      return Duration.zero;
    }
    if (position > _timeline.duration) {
      return _timeline.duration;
    }
    return position;
  }

  void _startRefreshTimer() {
    final interval = _refreshInterval;
    if (interval == null || _refreshTimer != null) {
      return;
    }
    _refreshTimer = Timer.periodic(interval, (_) => refresh());
  }

  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  static Duration _clampDelay(Duration delay) {
    const maximum = Duration(hours: 1);
    if (delay > maximum) {
      return maximum;
    }
    if (delay < -maximum) {
      return -maximum;
    }
    return delay;
  }

  @override
  void dispose() {
    _stopRefreshTimer();
    _clock.pause();
    unawaited(persist());
    super.dispose();
  }
}
