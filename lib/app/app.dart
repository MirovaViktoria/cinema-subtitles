import 'package:cinema_subtitles/features/open_file/open_file_screen.dart';
import 'package:cinema_subtitles/features/settings/player_preferences.dart';
import 'package:cinema_subtitles/features/settings/shared_preferences_store.dart';
import 'package:cinema_subtitles/infrastructure/screen_wake_lock.dart';
import 'package:cinema_subtitles/infrastructure/subtitle_document_loader.dart';
import 'package:cinema_subtitles/infrastructure/subtitle_file_loader.dart';
import 'package:cinema_subtitles/infrastructure/subtitle_package_adapter.dart';
import 'package:flutter/material.dart';

class CinemaSubtitlesApp extends StatelessWidget {
  const CinemaSubtitlesApp({
    this.documentSource,
    this.preferencesStore,
    this.wakeLock,
    super.key,
  });

  final SubtitleDocumentSource? documentSource;
  final PlayerPreferencesStore? preferencesStore;
  final ScreenWakeLock? wakeLock;

  @override
  Widget build(BuildContext context) {
    final resolvedPreferencesStore =
        preferencesStore ?? SharedPreferencesPlayerPreferencesStore();
    final resolvedDocumentSource =
        documentSource ??
        SubtitleDocumentLoader(SubtitleFileLoader(), SubtitlePackageAdapter());

    return MaterialApp(
      title: 'Cinema Subtitles',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE6FF55),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
      home: _AppBootstrap(
        documentSource: resolvedDocumentSource,
        preferencesStore: resolvedPreferencesStore,
        wakeLock: wakeLock ?? WakelockPlusScreenWakeLock(),
      ),
    );
  }
}

class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap({
    required this.documentSource,
    required this.preferencesStore,
    required this.wakeLock,
  });

  final SubtitleDocumentSource documentSource;
  final PlayerPreferencesStore preferencesStore;
  final ScreenWakeLock wakeLock;

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  late final Future<PlayerPreferences> _preferences = _loadPreferences();

  Future<PlayerPreferences> _loadPreferences() async {
    try {
      return await widget.preferencesStore.load();
    } on Object {
      return const PlayerPreferences();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PlayerPreferences>(
      future: _preferences,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return OpenFileScreen(
          documentSource: widget.documentSource,
          preferencesStore: widget.preferencesStore,
          wakeLock: widget.wakeLock,
          initialPreferences: snapshot.data!,
        );
      },
    );
  }
}
