import 'dart:async';

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
    super.key,
  });

  final PlayerController controller;
  final ScreenWakeLock wakeLock;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with WidgetsBindingObserver {
  bool _canPop = false;
  bool _isPopping = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(widget.wakeLock.enable());
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.wakeLock.enable());
      return;
    }
    widget.controller.pause();
    unawaited(widget.wakeLock.disable());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.wakeLock.disable());
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        final background = state.oledMode
            ? Colors.black
            : const Color(0xFF111315);

        return PopScope(
          canPop: _canPop,
          onPopInvokedWithResult: _persistBeforePop,
          child: Scaffold(
            backgroundColor: background,
            body: SafeArea(
              child: Column(
                children: [
                  _PlayerHeader(
                    fileName: state.fileName,
                    oledMode: state.oledMode,
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
                  Expanded(
                    child: SubtitleView(
                      cues: state.activeCues,
                      preferredFontSize: state.fontSize,
                    ),
                  ),
                  _SyncReadout(
                    rate: state.playbackRate,
                    delay: state.subtitleDelay,
                  ),
                  _PlaybackControls(controller: widget.controller),
                  _FineSyncControls(controller: widget.controller),
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

class _PlayerHeader extends StatelessWidget {
  const _PlayerHeader({
    required this.fileName,
    required this.oledMode,
    required this.onToggleOled,
    required this.onDecreaseFont,
    required this.onIncreaseFont,
    required this.onBrowseCues,
  });

  final String fileName;
  final bool oledMode;
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
        IconButton(
          tooltip: 'Nearby cues',
          onPressed: onBrowseCues,
          icon: const Icon(Icons.format_list_bulleted),
        ),
        IconButton(
          tooltip: 'Decrease font size',
          onPressed: onDecreaseFont,
          icon: const Icon(Icons.text_decrease),
        ),
        IconButton(
          tooltip: 'Increase font size',
          onPressed: onIncreaseFont,
          icon: const Icon(Icons.text_increase),
        ),
        IconButton(
          tooltip: oledMode ? 'Disable OLED mode' : 'Enable OLED mode',
          onPressed: onToggleOled,
          icon: Icon(oledMode ? Icons.contrast : Icons.contrast_outlined),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
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
