import 'package:cinema_subtitles/domain/subtitle_cue.dart';

final class PlayerState {
  const PlayerState({
    required this.fileName,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.subtitleDelay,
    required this.playbackRate,
    required this.fontSize,
    required this.oledMode,
    required this.activeCues,
    required this.nearbyCues,
  });

  final String fileName;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final Duration subtitleDelay;
  final double playbackRate;
  final double fontSize;
  final bool oledMode;
  final List<SubtitleCue> activeCues;
  final List<SubtitleCue> nearbyCues;
}
