final class PlayerPreferences {
  const PlayerPreferences({
    this.position = Duration.zero,
    this.subtitleDelay = Duration.zero,
    this.playbackRate = 1,
    this.fontSize = 36,
    this.oledMode = true,
    this.lastFileReference,
    this.lastFileName,
  });

  final Duration position;
  final Duration subtitleDelay;
  final double playbackRate;
  final double fontSize;
  final bool oledMode;
  final String? lastFileReference;
  final String? lastFileName;

  PlayerPreferences copyWith({
    Duration? position,
    Duration? subtitleDelay,
    double? playbackRate,
    double? fontSize,
    bool? oledMode,
    String? lastFileReference,
    String? lastFileName,
    bool clearLastFile = false,
  }) {
    return PlayerPreferences(
      position: position ?? this.position,
      subtitleDelay: subtitleDelay ?? this.subtitleDelay,
      playbackRate: playbackRate ?? this.playbackRate,
      fontSize: fontSize ?? this.fontSize,
      oledMode: oledMode ?? this.oledMode,
      lastFileReference: clearLastFile
          ? null
          : lastFileReference ?? this.lastFileReference,
      lastFileName: clearLastFile ? null : lastFileName ?? this.lastFileName,
    );
  }
}

abstract interface class PlayerPreferencesStore {
  Future<PlayerPreferences> load();
  Future<void> save(PlayerPreferences preferences);
}
