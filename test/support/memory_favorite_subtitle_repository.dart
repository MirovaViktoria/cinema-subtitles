import 'dart:async';

import 'package:cinema_subtitles/domain/subtitle_source.dart';
import 'package:cinema_subtitles/features/favorites/favorite_subtitle.dart';
import 'package:crypto/crypto.dart';

final class MemoryFavoriteSubtitleRepository
    implements FavoriteSubtitleRepository {
  MemoryFavoriteSubtitleRepository({
    Iterable<FavoriteSubtitle> entries = const [],
    Map<String, SubtitleSource> sources = const {},
  }) : _entries = List.of(entries),
       _sources = Map.of(sources);

  final List<FavoriteSubtitle> _entries;
  final Map<String, SubtitleSource> _sources;

  Object? listError;
  Object? addError;
  Object? removeError;
  Object? openError;
  Completer<void>? addGate;
  Completer<void>? listGate;
  Completer<void>? openGate;
  int listCount = 0;
  int addCount = 0;
  int removeCount = 0;
  int openCount = 0;

  @override
  Future<List<FavoriteSubtitle>> list() async {
    listCount++;
    await listGate?.future;
    if (listError case final error?) {
      throw error;
    }
    return List.unmodifiable(_sorted());
  }

  @override
  Future<FavoriteSubtitle> add(SubtitleSource source) async {
    addCount++;
    if (addError case final error?) {
      throw error;
    }
    await addGate?.future;
    final id = sha256.convert(source.bytes).toString();
    final existing = await findById(id);
    if (existing != null) {
      return existing;
    }
    final entry = FavoriteSubtitle(
      id: id,
      displayName: source.name,
      format: source.format,
      privatePath: 'memory/favorites/$id.${source.format.name}',
      addedAt: DateTime.utc(2026, 8, 18, 12, _entries.length),
    );
    _entries.add(entry);
    _sources[id] = SubtitleSource(
      name: source.name,
      reference: entry.privatePath,
      bytes: source.bytes,
      format: source.format,
      favoriteId: id,
    );
    return entry;
  }

  @override
  Future<void> remove(String id) async {
    removeCount++;
    if (removeError case final error?) {
      throw error;
    }
    _entries.removeWhere((entry) => entry.id == id);
    _sources.remove(id);
  }

  @override
  Future<FavoriteSubtitle?> findById(String id) async {
    for (final entry in _entries) {
      if (entry.id == id) {
        return entry;
      }
    }
    return null;
  }

  @override
  Future<SubtitleSource> openSource(String id) async {
    openCount++;
    if (openError case final error?) {
      throw error;
    }
    await openGate?.future;
    final source = _sources[id];
    if (source == null) {
      throw const FavoriteSubtitleException(
        FavoriteSubtitleFailureKind.notFound,
        'Missing favorite',
      );
    }
    return source;
  }

  List<FavoriteSubtitle> _sorted() {
    return [..._entries]
      ..sort((left, right) => right.addedAt.compareTo(left.addedAt));
  }
}
