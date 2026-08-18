import 'package:cinema_subtitles/domain/subtitle_source.dart';

final class FavoriteSubtitle {
  const FavoriteSubtitle({
    required this.id,
    required this.displayName,
    required this.format,
    required this.privatePath,
    required this.addedAt,
    this.isAvailable = true,
  });

  final String id;
  final String displayName;
  final SubtitleFormat format;
  final String privatePath;
  final DateTime addedAt;
  final bool isAvailable;

  FavoriteSubtitle copyWith({bool? isAvailable}) {
    return FavoriteSubtitle(
      id: id,
      displayName: displayName,
      format: format,
      privatePath: privatePath,
      addedAt: addedAt,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}

abstract interface class FavoriteSubtitleRepository {
  Future<List<FavoriteSubtitle>> list();

  Future<FavoriteSubtitle> add(SubtitleSource source);

  Future<void> remove(String id);

  Future<FavoriteSubtitle?> findById(String id);

  Future<SubtitleSource> openSource(String id);
}

enum FavoriteSubtitleFailureKind {
  notFound,
  unreadable,
  invalidMetadata,
  storage,
}

final class FavoriteSubtitleException implements Exception {
  const FavoriteSubtitleException(this.kind, this.message, [this.cause]);

  final FavoriteSubtitleFailureKind kind;
  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
