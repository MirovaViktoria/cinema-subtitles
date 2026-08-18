import 'package:cinema_subtitles/features/favorites/favorite_subtitle.dart';
import 'package:cinema_subtitles/features/favorites/favorites_controller.dart';
import 'package:cinema_subtitles/features/open_file/open_file_screen.dart';
import 'package:cinema_subtitles/features/settings/player_preferences.dart';
import 'package:cinema_subtitles/features/settings/shared_preferences_store.dart';
import 'package:cinema_subtitles/infrastructure/file_favorite_subtitle_repository.dart';
import 'package:cinema_subtitles/infrastructure/screen_wake_lock.dart';
import 'package:cinema_subtitles/infrastructure/subtitle_document_loader.dart';
import 'package:cinema_subtitles/infrastructure/subtitle_file_loader.dart';
import 'package:cinema_subtitles/infrastructure/subtitle_package_adapter.dart';
import 'package:flutter/material.dart';

class CinemaSubtitlesApp extends StatefulWidget {
  const CinemaSubtitlesApp({
    this.documentSource,
    this.favoriteRepository,
    this.preferencesStore,
    this.wakeLock,
    super.key,
  });

  final SubtitleDocumentSource? documentSource;
  final FavoriteSubtitleRepository? favoriteRepository;
  final PlayerPreferencesStore? preferencesStore;
  final ScreenWakeLock? wakeLock;

  @override
  State<CinemaSubtitlesApp> createState() => _CinemaSubtitlesAppState();
}

class _CinemaSubtitlesAppState extends State<CinemaSubtitlesApp> {
  late final PlayerPreferencesStore _preferencesStore =
      widget.preferencesStore ?? SharedPreferencesPlayerPreferencesStore();
  late final SubtitleDocumentSource _documentSource =
      widget.documentSource ??
      SubtitleDocumentLoader(SubtitleFileLoader(), SubtitlePackageAdapter());
  late final FavoriteSubtitleRepository _favoriteRepository =
      widget.favoriteRepository ?? FileFavoriteSubtitleRepository();
  late final ScreenWakeLock _wakeLock =
      widget.wakeLock ?? WakelockPlusScreenWakeLock();

  @override
  Widget build(BuildContext context) {
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
        documentSource: _documentSource,
        favoriteRepository: _favoriteRepository,
        preferencesStore: _preferencesStore,
        wakeLock: _wakeLock,
      ),
    );
  }
}

class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap({
    required this.documentSource,
    required this.favoriteRepository,
    required this.preferencesStore,
    required this.wakeLock,
  });

  final SubtitleDocumentSource documentSource;
  final FavoriteSubtitleRepository favoriteRepository;
  final PlayerPreferencesStore preferencesStore;
  final ScreenWakeLock wakeLock;

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  late final FavoritesController _favoritesController = FavoritesController(
    widget.favoriteRepository,
  );
  late final Future<PlayerPreferences> _preferences = _initialize();

  Future<PlayerPreferences> _initialize() async {
    final preferences = _loadPreferences();
    await _favoritesController.load();
    return preferences;
  }

  Future<PlayerPreferences> _loadPreferences() async {
    try {
      return await widget.preferencesStore.load();
    } on Object {
      return const PlayerPreferences();
    }
  }

  @override
  void dispose() {
    _favoritesController.dispose();
    super.dispose();
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
          favoritesController: _favoritesController,
          preferencesStore: widget.preferencesStore,
          wakeLock: widget.wakeLock,
          initialPreferences: snapshot.data!,
        );
      },
    );
  }
}
