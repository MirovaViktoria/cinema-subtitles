import 'dart:async';

import 'package:cinema_subtitles/domain/subtitle_source.dart';
import 'package:cinema_subtitles/features/favorites/favorites_controller.dart';
import 'package:cinema_subtitles/features/player/player_controller.dart';
import 'package:cinema_subtitles/features/player/subtitle_view.dart';
import 'package:cinema_subtitles/features/player/time_format.dart';
import 'package:cinema_subtitles/infrastructure/screen_wake_lock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    required this.controller,
    required this.wakeLock,
    required this.source,
    required this.favoritesController,
    super.key,
  });

  final PlayerController controller;
  final ScreenWakeLock wakeLock;
  final SubtitleSource source;
  final FavoritesController favoritesController;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with WidgetsBindingObserver {
  bool _canPop = false;
  bool _isPopping = false;
  bool _controlsVisible = true;
  bool _isFavoriteActionInProgress = false;
  Future<void> _wakeLockQueue = Future.value();
  late final Listenable _animation;
  late String? _favoriteId;

  @override
  void initState() {
    super.initState();
    _animation = Listenable.merge([
      widget.controller,
      widget.favoritesController,
    ]);
    _favoriteId = widget.source.favoriteId;
    WidgetsBinding.instance.addObserver(this);
    _setWakeLock(true);
    unawaited(_setSystemUiMode(SystemUiMode.immersiveSticky));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setWakeLock(true);
      return;
    }
    widget.controller.pause();
    _setWakeLock(false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setWakeLock(false);
    unawaited(_setSystemUiMode(SystemUiMode.edgeToEdge));
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final state = widget.controller.state;
        final background = state.oledMode
            ? Colors.black
            : const Color(0xFF111315);
        final isFavorite =
            _favoriteId != null &&
            widget.favoritesController.findById(_favoriteId!) != null;

        return PopScope(
          canPop: _canPop,
          onPopInvokedWithResult: _persistBeforePop,
          child: Scaffold(
            backgroundColor: background,
            body: SafeArea(
              child: Column(
                children: [
                  if (_controlsVisible) ...[
                    _PlayerHeader(
                      fileName: state.fileName,
                      oledMode: state.oledMode,
                      isFavorite: isFavorite,
                      isFavoriteBusy: _isFavoriteActionInProgress,
                      onToggleFavorite: _toggleFavorite,
                      onHideControls: () {
                        setState(() => _controlsVisible = false);
                      },
                      onToggleOled: () {
                        widget.controller.setOledMode(!state.oledMode);
                      },
                      onDecreaseFont: widget.controller.decreaseFontSize,
                      onIncreaseFont: widget.controller.increaseFontSize,
                      onBrowseCues: _showNearbyCues,
                    ),
                    InkWell(
                      key: const Key('exact-timestamp-button'),
                      onTap: _showTimestampDialog,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: Text(
                          '${formatDuration(state.position, milliseconds: true)}  /  '
                          '${formatDuration(state.duration)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ],
                  Expanded(
                    child: Semantics(
                      button: !_controlsVisible,
                      label: _controlsVisible ? null : 'Show player controls',
                      child: GestureDetector(
                        key: const Key('focus-subtitle-area'),
                        behavior: HitTestBehavior.opaque,
                        onTap: _controlsVisible
                            ? null
                            : () => setState(() => _controlsVisible = true),
                        child: SubtitleView(
                          cues: state.activeCues,
                          preferredFontSize: state.fontSize,
                        ),
                      ),
                    ),
                  ),
                  if (_controlsVisible) ...[
                    _SyncReadout(
                      rate: state.playbackRate,
                      delay: state.subtitleDelay,
                    ),
                    _PlaybackControls(controller: widget.controller),
                    _FineSyncControls(controller: widget.controller),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _persistBeforePop(bool didPop, Object? result) async {
    if (didPop || _canPop || _isPopping) {
      return;
    }
    _isPopping = true;
    widget.controller.pause();
    await widget.controller.persist();
    if (!mounted) {
      return;
    }
    setState(() => _canPop = true);
    Navigator.of(context).pop(result);
  }

  Future<void> _toggleFavorite() async {
    if (_isFavoriteActionInProgress) {
      return;
    }
    final currentId = _favoriteId;
    final currentEntry = currentId == null
        ? null
        : widget.favoritesController.findById(currentId);
    if (currentEntry != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove favorite?'),
          content: Text(
            'Remove ${widget.source.name} and its private copy from this device?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('confirm-player-remove-favorite-button'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) {
        return;
      }
      setState(() => _isFavoriteActionInProgress = true);
      try {
        final removed = await widget.favoritesController.remove(
          currentEntry.id,
        );
        if (!removed) {
          return;
        }
        if (currentEntry.privatePath == widget.source.reference) {
          widget.controller.clearRestorableFileReference();
        }
        if (mounted) {
          setState(() => _favoriteId = null);
          _showFavoriteMessage('Removed from favorites');
        }
      } on Object catch (error) {
        if (mounted) {
          _showFavoriteMessage(error.toString());
        }
      } finally {
        if (mounted) {
          setState(() => _isFavoriteActionInProgress = false);
        }
      }
      return;
    }

    setState(() => _isFavoriteActionInProgress = true);
    try {
      final entry = await widget.favoritesController.add(widget.source);
      if (entry != null && mounted) {
        setState(() => _favoriteId = entry.id);
        _showFavoriteMessage('Saved to favorites');
      }
    } on Object catch (error) {
      if (mounted) {
        _showFavoriteMessage(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isFavoriteActionInProgress = false);
      }
    }
  }

  void _showFavoriteMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _setWakeLock(bool enabled) {
    _wakeLockQueue = _wakeLockQueue.then((_) async {
      try {
        if (enabled) {
          await widget.wakeLock.enable();
        } else {
          await widget.wakeLock.disable();
        }
      } on Object {
        // Platform wake-lock failures must not interrupt subtitle playback.
      }
    });
  }

  Future<void> _setSystemUiMode(SystemUiMode mode) async {
    try {
      await SystemChrome.setEnabledSystemUIMode(mode);
    } on Object {
      // System UI availability varies across Flutter target platforms.
    }
  }

  Future<void> _showTimestampDialog() async {
    var input = formatDuration(
      widget.controller.state.position,
      milliseconds: true,
    );
    String? errorText;
    final position = await showDialog<Duration>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Jump to timestamp'),
              content: TextFormField(
                initialValue: input,
                autofocus: true,
                keyboardType: TextInputType.datetime,
                decoration: InputDecoration(
                  hintText: '0:42:15.500',
                  errorText: errorText,
                ),
                onChanged: (value) => input = value,
                onFieldSubmitted: (value) {
                  final parsed = parseTimestamp(value);
                  if (parsed == null) {
                    setDialogState(() => errorText = 'Use H:MM:SS.mmm');
                  } else {
                    Navigator.pop(context, parsed);
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final parsed = parseTimestamp(input);
                    if (parsed == null) {
                      setDialogState(() => errorText = 'Use H:MM:SS.mmm');
                    } else {
                      Navigator.pop(context, parsed);
                    }
                  },
                  child: const Text('Jump'),
                ),
              ],
            );
          },
        );
      },
    );
    if (position != null) {
      widget.controller.seek(position);
    }
  }

  Future<void> _showNearbyCues() async {
    final cues = widget.controller.state.nearbyCues;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        if (cues.isEmpty) {
          return const SafeArea(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('No nearby cues')),
            ),
          );
        }
        return SafeArea(
          child: ListView.builder(
            itemCount: cues.length,
            itemBuilder: (context, index) {
              final cue = cues[index];
              return ListTile(
                title: Text(
                  cue.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(formatDuration(cue.start, milliseconds: true)),
                trailing: TextButton(
                  onPressed: () {
                    widget.controller.syncToCue(cue);
                    Navigator.pop(context);
                  },
                  child: const Text('Sync here'),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

enum _PlayerMenuAction { nearby, decreaseFont, increaseFont, toggleOled }

class _PlayerHeader extends StatelessWidget {
  const _PlayerHeader({
    required this.fileName,
    required this.oledMode,
    required this.isFavorite,
    required this.isFavoriteBusy,
    required this.onToggleFavorite,
    required this.onHideControls,
    required this.onToggleOled,
    required this.onDecreaseFont,
    required this.onIncreaseFont,
    required this.onBrowseCues,
  });

  final String fileName;
  final bool oledMode;
  final bool isFavorite;
  final bool isFavoriteBusy;
  final VoidCallback onToggleFavorite;
  final VoidCallback onHideControls;
  final VoidCallback onToggleOled;
  final VoidCallback onDecreaseFont;
  final VoidCallback onIncreaseFont;
  final VoidCallback onBrowseCues;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const BackButton(),
        Expanded(
          child: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        if (isFavoriteBusy)
          const SizedBox.square(
            dimension: 48,
            child: Padding(
              padding: EdgeInsets.all(14),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          IconButton(
            key: const Key('favorite-button'),
            tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
            onPressed: onToggleFavorite,
            icon: Icon(isFavorite ? Icons.star : Icons.star_border),
          ),
        PopupMenuButton<_PlayerMenuAction>(
          tooltip: 'Player options',
          icon: const Icon(Icons.more_vert),
          onSelected: (action) {
            switch (action) {
              case _PlayerMenuAction.nearby:
                onBrowseCues();
              case _PlayerMenuAction.decreaseFont:
                onDecreaseFont();
              case _PlayerMenuAction.increaseFont:
                onIncreaseFont();
              case _PlayerMenuAction.toggleOled:
                onToggleOled();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: _PlayerMenuAction.nearby,
              child: Text('Nearby cues'),
            ),
            const PopupMenuItem(
              value: _PlayerMenuAction.decreaseFont,
              child: Text('Decrease font size'),
            ),
            const PopupMenuItem(
              value: _PlayerMenuAction.increaseFont,
              child: Text('Increase font size'),
            ),
            PopupMenuItem(
              value: _PlayerMenuAction.toggleOled,
              child: Text(oledMode ? 'Disable OLED mode' : 'Enable OLED mode'),
            ),
          ],
        ),
        IconButton(
          key: const Key('hide-controls-button'),
          tooltip: 'Hide controls',
          onPressed: onHideControls,
          icon: const Icon(Icons.fullscreen),
        ),
      ],
    );
  }
}

class _SyncReadout extends StatelessWidget {
  const _SyncReadout({required this.rate, required this.delay});

  final double rate;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final delaySeconds = delay.inMilliseconds / 1000;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: _ScrollableControlRow(
        children: [
          Text(
            'Rate ${rate.toStringAsFixed(3)}x',
            key: const Key('rate-readout'),
          ),
          const SizedBox(width: 24),
          Text(
            'Delay ${delaySeconds >= 0 ? '+' : ''}'
            '${delaySeconds.toStringAsFixed(1)}s',
            key: const Key('delay-readout'),
          ),
        ],
      ),
    );
  }
}

class _PlaybackControls extends StatelessWidget {
  const _PlaybackControls({required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    final isPlaying = controller.state.isPlaying;
    return _ScrollableControlRow(
      children: [
        _ControlButton(
          tooltip: 'Previous cue',
          icon: Icons.skip_previous,
          onPressed: controller.previousCue,
        ),
        _TextControlButton(
          label: '-10',
          onPressed: () => controller.seekBy(const Duration(seconds: -10)),
        ),
        _TextControlButton(
          label: '-1',
          onPressed: () => controller.seekBy(const Duration(seconds: -1)),
        ),
        IconButton.filled(
          key: const Key('play-pause-button'),
          tooltip: isPlaying ? 'Pause' : 'Play',
          iconSize: 32,
          onPressed: controller.togglePlayPause,
          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
        ),
        _TextControlButton(
          label: '+1',
          onPressed: () => controller.seekBy(const Duration(seconds: 1)),
        ),
        _TextControlButton(
          label: '+10',
          onPressed: () => controller.seekBy(const Duration(seconds: 10)),
        ),
        _ControlButton(
          tooltip: 'Next cue',
          icon: Icons.skip_next,
          onPressed: controller.nextCue,
        ),
      ],
    );
  }
}

class _FineSyncControls extends StatelessWidget {
  const _FineSyncControls({required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
      child: Column(
        children: [
          _ScrollableControlRow(
            children: [
              const SizedBox(width: 52, child: Text('Rate')),
              _TextControlButton(
                label: '-.001',
                onPressed: () =>
                    controller.adjustRate(-PlayerController.rateStep),
              ),
              TextButton(
                onPressed: controller.resetRate,
                child: const Text('Reset'),
              ),
              _TextControlButton(
                label: '+.001',
                onPressed: () =>
                    controller.adjustRate(PlayerController.rateStep),
              ),
            ],
          ),
          _ScrollableControlRow(
            children: [
              const SizedBox(width: 52, child: Text('Delay')),
              _TextControlButton(
                label: '-1',
                onPressed: () =>
                    controller.adjustSubtitleDelay(const Duration(seconds: -1)),
              ),
              _TextControlButton(
                label: '-.1',
                onPressed: () => controller.adjustSubtitleDelay(
                  const Duration(milliseconds: -100),
                ),
              ),
              TextButton(
                onPressed: controller.resetSubtitleDelay,
                child: const Text('Reset'),
              ),
              _TextControlButton(
                label: '+.1',
                onPressed: () => controller.adjustSubtitleDelay(
                  const Duration(milliseconds: 100),
                ),
              ),
              _TextControlButton(
                label: '+1',
                onPressed: () =>
                    controller.adjustSubtitleDelay(const Duration(seconds: 1)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScrollableControlRow extends StatelessWidget {
  const _ScrollableControlRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(tooltip: tooltip, onPressed: onPressed, icon: Icon(icon));
  }
}

class _TextControlButton extends StatelessWidget {
  const _TextControlButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        minimumSize: const Size(42, 44),
        padding: const EdgeInsets.symmetric(horizontal: 7),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
