import 'package:cinema_subtitles/domain/monotonic_time_source.dart';
import 'package:cinema_subtitles/domain/playback_clock.dart';
import 'package:cinema_subtitles/features/player/player_controller.dart';
import 'package:cinema_subtitles/features/player/player_screen.dart';
import 'package:cinema_subtitles/features/settings/player_preferences.dart';
import 'package:cinema_subtitles/infrastructure/screen_wake_lock.dart';
import 'package:cinema_subtitles/infrastructure/subtitle_document_loader.dart';
import 'package:flutter/material.dart';

class OpenFileScreen extends StatefulWidget {
  const OpenFileScreen({
    required this.documentSource,
    required this.preferencesStore,
    required this.wakeLock,
    required this.initialPreferences,
    super.key,
  });

  final SubtitleDocumentSource documentSource;
  final PlayerPreferencesStore preferencesStore;
  final ScreenWakeLock wakeLock;
  final PlayerPreferences initialPreferences;

  @override
  State<OpenFileScreen> createState() => _OpenFileScreenState();
}

class _OpenFileScreenState extends State<OpenFileScreen> {
  late PlayerPreferences _preferences = widget.initialPreferences;
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final lastFileReference = _preferences.lastFileReference;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.subtitles_outlined,
                    size: 72,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Cinema Subtitles',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Offline subtitle clock',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (_isLoading)
                    const CircularProgressIndicator()
                  else ...[
                    FilledButton.icon(
                      key: const Key('open-subtitle-file-button'),
                      onPressed: _pickFile,
                      icon: const Icon(Icons.folder_open_outlined),
                      label: const Text('Open subtitle file'),
                    ),
                    if (lastFileReference != null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        key: const Key('reopen-last-file-button'),
                        onPressed: () => _openReference(lastFileReference),
                        icon: const Icon(Icons.history),
                        label: Text(
                          'Reopen ${_preferences.lastFileName ?? 'last file'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      _error!,
                      key: const Key('file-error-message'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text(
                    'SRT and WebVTT · No network required',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    await _load(() => widget.documentSource.pick());
  }

  Future<void> _openReference(String reference) async {
    await _load(() => widget.documentSource.reopen(reference));
  }

  Future<void> _load(Future<SubtitleDocument?> Function() loader) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final document = await loader();
      if (document == null || !mounted) {
        return;
      }
      final storedPreferences = await widget.preferencesStore.load();
      if (!mounted) {
        return;
      }
      final restoringSameFile =
          storedPreferences.lastFileReference == document.reference;
      final preferences = PlayerPreferences(
        position: restoringSameFile
            ? storedPreferences.position
            : Duration.zero,
        subtitleDelay: storedPreferences.subtitleDelay,
        playbackRate: storedPreferences.playbackRate,
        fontSize: storedPreferences.fontSize,
        oledMode: storedPreferences.oledMode,
        lastFileReference: document.reference,
        lastFileName: document.name,
      );
      final controller = PlayerController(
        fileName: document.name,
        fileReference: document.reference,
        timeline: document.timeline,
        clock: PlaybackClock(timeSource: StopwatchTimeSource()),
        preferencesStore: widget.preferencesStore,
        preferences: preferences,
      );

      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              PlayerScreen(controller: controller, wakeLock: widget.wakeLock),
        ),
      );
      _preferences = await widget.preferencesStore.load();
    } on Object catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
