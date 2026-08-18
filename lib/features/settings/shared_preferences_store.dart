import 'dart:convert';

import 'package:cinema_subtitles/features/settings/player_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class SharedPreferencesPlayerPreferencesStore
    implements PlayerPreferencesStore {
  SharedPreferencesPlayerPreferencesStore([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _stateKey = 'player.preferences.v1';

  final SharedPreferencesAsync _preferences;

  @override
  Future<PlayerPreferences> load() async {
    final encoded = await _preferences.getString(_stateKey);
    if (encoded == null) {
      return const PlayerPreferences();
    }

    try {
      final value = jsonDecode(encoded);
      if (value is! Map<String, Object?>) {
        return const PlayerPreferences();
      }
      return PlayerPreferences(
        position: Duration(
          microseconds: (value['positionUs'] as num?)?.toInt() ?? 0,
        ),
        subtitleDelay: Duration(
          microseconds: (value['subtitleDelayUs'] as num?)?.toInt() ?? 0,
        ),
        playbackRate: (value['playbackRate'] as num?)?.toDouble() ?? 1,
        fontSize: (value['fontSize'] as num?)?.toDouble() ?? 36,
        oledMode: value['oledMode'] as bool? ?? true,
        lastFileReference: value['lastFileReference'] as String?,
        lastFileName: value['lastFileName'] as String?,
      );
    } on Object {
      return const PlayerPreferences();
    }
  }

  @override
  Future<void> save(PlayerPreferences preferences) {
    return _preferences.setString(
      _stateKey,
      jsonEncode({
        'positionUs': preferences.position.inMicroseconds,
        'subtitleDelayUs': preferences.subtitleDelay.inMicroseconds,
        'playbackRate': preferences.playbackRate,
        'fontSize': preferences.fontSize,
        'oledMode': preferences.oledMode,
        'lastFileReference': preferences.lastFileReference,
        'lastFileName': preferences.lastFileName,
      }),
    );
  }
}
