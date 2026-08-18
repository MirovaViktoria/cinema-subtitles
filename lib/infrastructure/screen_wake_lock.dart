import 'package:wakelock_plus/wakelock_plus.dart';

abstract interface class ScreenWakeLock {
  Future<void> enable();
  Future<void> disable();
}

final class WakelockPlusScreenWakeLock implements ScreenWakeLock {
  @override
  Future<void> enable() => WakelockPlus.enable();

  @override
  Future<void> disable() => WakelockPlus.disable();
}
