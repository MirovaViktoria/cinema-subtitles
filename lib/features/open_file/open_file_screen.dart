import 'package:cinema_subtitles/domain/monotonic_time_source.dart';
import 'package:cinema_subtitles/domain/playback_clock.dart';
import 'package:cinema_subtitles/domain/subtitle_source.dart';
import 'package:cinema_subtitles/features/favorites/favorite_subtitle.dart';
import 'package:cinema_subtitles/features/favorites/favorites_controller.dart';
import 'package:cinema_subtitles/features/player/player_controller.dart';
import 'package:cinema_subtitles/features/player/player_screen.dart';
import 'package:cinema_subtitles/features/settings/player_preferences.dart';
import 'package:cinema_subtitles/infrastructure/screen_wake_lock.dart';
import 'package:cinema_subtitles/infrastructure/subtitle_document_loader.dart';
import 'package:flutter/material.dart';

class OpenFileScreen extends StatefulWidget {
  const OpenFileScreen({
    required this.documentSource,
    required this.favoritesController,
    required this.preferencesStore,
    required this.wakeLock,
    required this.initialPreferences,
    super.key,
  });

  final SubtitleDocumentSource documentSource;
  final FavoritesController favoritesController;
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
    return AnimatedBuilder(
      animation: widget.favoritesController,
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final lastFileReference = _preferences.lastFileReference;
    final favoritesState = widget.favoritesController.state;
    final favoritesBusy = _isLoading || favoritesState.isOperating;
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
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Text(
                        'Favorites',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      if (favoritesState.isLoading)
                        const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (!favoritesState.isLoading &&
                      favoritesState.entries.isEmpty)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Files saved from the player appear here.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  else
                    for (final entry in favoritesState.entries)
                      _FavoriteTile(
                        entry: entry,
                        isBroken:
                            favoritesState.brokenIds.contains(entry.id) ||
                            !entry.isAvailable,
                        isBusy: favoritesBusy,
                        onOpen: () => _openFavorite(entry),
                        onRemove: () => _confirmRemoveFavorite(entry),
                      ),
                  if (favoritesState.error != null && _error == null) ...[
                    const SizedBox(height: 8),
                    Text(
                      favoritesState.error!,
                      key: const Key('favorites-error-message'),
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

  Future<void> _openFavorite(FavoriteSubtitle entry) async {
    await _load(() async {
      final source = await widget.favoritesController.openSource(entry.id);
      return widget.documentSource.parse(source);
    }, brokenFavoriteId: entry.id);
  }

  Future<void> _load(
    Future<SubtitleDocument?> Function() loader, {
    String? brokenFavoriteId,
  }) async {
    if (_isLoading || widget.favoritesController.state.isOperating) {
      return;
    }
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
          builder: (_) => PlayerScreen(
            controller: controller,
            wakeLock: widget.wakeLock,
            source: document.source,
            favoritesController: widget.favoritesController,
          ),
        ),
      );
      _preferences = await widget.preferencesStore.load();
    } on Object catch (error) {
      _error = error.toString();
      if (brokenFavoriteId != null) {
        widget.favoritesController.markBroken(brokenFavoriteId, error);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _confirmRemoveFavorite(FavoriteSubtitle entry) async {
    if (_isLoading || widget.favoritesController.state.isOperating) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove favorite?'),
        content: Text(
          'Remove ${entry.displayName} and its private copy from this device?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-remove-favorite-button'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      final removed = await widget.favoritesController.remove(entry.id);
      if (!removed) {
        return;
      }
      if (_preferences.lastFileReference == entry.privatePath) {
        _preferences = _preferences.copyWith(clearLastFile: true);
        try {
          await widget.preferencesStore.save(_preferences);
        } on Object {
          // Removing the private copy remains successful if settings fail.
        }
      }
      if (mounted) {
        setState(() => _error = null);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    }
  }
}

class _FavoriteTile extends StatelessWidget {
  const _FavoriteTile({
    required this.entry,
    required this.isBroken,
    required this.isBusy,
    required this.onOpen,
    required this.onRemove,
  });

  final FavoriteSubtitle entry;
  final bool isBroken;
  final bool isBusy;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final format = entry.format == SubtitleFormat.srt ? 'SRT' : 'WebVTT';
    return Card(
      key: ValueKey('favorite-${entry.id}'),
      margin: const EdgeInsets.only(top: 8),
      child: ListTile(
        enabled: !isBusy,
        onTap: isBusy ? null : onOpen,
        leading: Icon(
          isBroken ? Icons.warning_amber_rounded : Icons.subtitles_outlined,
          color: isBroken ? Theme.of(context).colorScheme.error : null,
        ),
        title: Text(
          entry.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          isBroken ? '$format · Private copy unavailable' : format,
        ),
        trailing: isBusy
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : isBroken
            ? TextButton(
                key: ValueKey('remove-broken-favorite-${entry.id}'),
                onPressed: onRemove,
                child: const Text('Remove'),
              )
            : IconButton(
                key: ValueKey('remove-favorite-${entry.id}'),
                tooltip: 'Remove favorite',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
      ),
    );
  }
}
