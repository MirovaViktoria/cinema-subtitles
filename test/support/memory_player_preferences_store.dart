import 'package:cinema_subtitles/features/settings/player_preferences.dart';

final class MemoryPlayerPreferencesStore implements PlayerPreferencesStore {
  MemoryPlayerPreferencesStore([this.preferences = const PlayerPreferences()]);

  PlayerPreferences preferences;
  int saveCount = 0;

  @override
  Future<PlayerPreferences> load() async => preferences;

  @override
  Future<void> save(PlayerPreferences value) async {
    preferences = value;
    saveCount++;
  }
}

final class SerialCheckPlayerPreferencesStore
    implements PlayerPreferencesStore {
  int activeSaves = 0;
  int maximumConcurrentSaves = 0;
  final List<PlayerPreferences> saved = [];

  @override
  Future<PlayerPreferences> load() async =>
      saved.isEmpty ? const PlayerPreferences() : saved.last;

  @override
  Future<void> save(PlayerPreferences preferences) async {
    activeSaves++;
    if (activeSaves > maximumConcurrentSaves) {
      maximumConcurrentSaves = activeSaves;
    }
    await Future<void>.delayed(const Duration(milliseconds: 2));
    saved.add(preferences);
    activeSaves--;
  }
}
