import 'package:cinema_subtitles/infrastructure/screen_wake_lock.dart';

final class MemoryScreenWakeLock implements ScreenWakeLock {
  int enableCount = 0;
  int disableCount = 0;

  @override
  Future<void> enable() async {
    enableCount++;
  }

  @override
  Future<void> disable() async {
    disableCount++;
  }
}
