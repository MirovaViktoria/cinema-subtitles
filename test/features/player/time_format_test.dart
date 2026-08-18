import 'package:cinema_subtitles/features/player/time_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats duration with stable clock fields', () {
    expect(
      formatDuration(
        const Duration(hours: 1, minutes: 2, seconds: 3, milliseconds: 45),
        milliseconds: true,
      ),
      '1:02:03.045',
    );
  });

  test('parses exact timestamps with optional hours and milliseconds', () {
    expect(
      parseTimestamp('1:02:03.045'),
      const Duration(hours: 1, minutes: 2, seconds: 3, milliseconds: 45),
    );
    expect(
      parseTimestamp('02:03,5'),
      const Duration(minutes: 2, seconds: 3, milliseconds: 500),
    );
  });

  test('rejects invalid timestamps', () {
    expect(parseTimestamp('1:90:00'), isNull);
    expect(parseTimestamp('not a time'), isNull);
  });
}
