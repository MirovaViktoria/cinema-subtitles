String formatDuration(Duration duration, {bool milliseconds = false}) {
  final safeDuration = duration.isNegative ? Duration.zero : duration;
  final totalHours = safeDuration.inHours;
  final minutes = safeDuration.inMinutes
      .remainder(60)
      .toString()
      .padLeft(2, '0');
  final seconds = safeDuration.inSeconds
      .remainder(60)
      .toString()
      .padLeft(2, '0');
  final buffer = StringBuffer('$totalHours:$minutes:$seconds');
  if (milliseconds) {
    buffer
      ..write('.')
      ..write(
        safeDuration.inMilliseconds.remainder(1000).toString().padLeft(3, '0'),
      );
  }
  return buffer.toString();
}

Duration? parseTimestamp(String input) {
  final match = RegExp(r'^(?:(\d+):)?([0-5]?\d):([0-5]?\d)(?:[.,](\d{1,3}))?$')
      .firstMatch(input.trim());
  if (match == null) {
    return null;
  }

  final millisecondsText = match.group(4) ?? '0';
  return Duration(
    hours: int.parse(match.group(1) ?? '0'),
    minutes: int.parse(match.group(2)!),
    seconds: int.parse(match.group(3)!),
    milliseconds: int.parse(millisecondsText.padRight(3, '0')),
  );
}
