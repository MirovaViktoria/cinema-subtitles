import 'dart:async';
import 'dart:convert';

import 'package:cinema_subtitles/domain/subtitle_source.dart';
import 'package:cinema_subtitles/features/favorites/favorite_subtitle.dart';
import 'package:cinema_subtitles/features/favorites/favorites_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/memory_favorite_subtitle_repository.dart';

void main() {
  SubtitleSource source({String name = 'movie.srt'}) {
    return SubtitleSource(
      name: name,
      reference: 'cache/$name',
      bytes: utf8.encode('1\n00:00:01,000 --> 00:00:02,000\nHello\n'),
      format: SubtitleFormat.srt,
    );
  }

  test('loads immutable entries and unavailable state', () async {
    final entry = FavoriteSubtitle(
      id: 'id',
      displayName: 'movie.srt',
      format: SubtitleFormat.srt,
      privatePath: 'memory/movie.srt',
      addedAt: DateTime.utc(2026, 8, 18),
      isAvailable: false,
    );
    final controller = FavoritesController(
      MemoryFavoriteSubtitleRepository(entries: [entry]),
    );

    await controller.load();

    expect(controller.state.isLoading, isFalse);
    expect(controller.state.entries, [entry]);
    expect(controller.state.brokenIds, contains('id'));
    expect(() => controller.state.entries.add(entry), throwsUnsupportedError);
  });

  test('adds once and keeps duplicate content as one entry', () async {
    final repository = MemoryFavoriteSubtitleRepository();
    final controller = FavoritesController(repository);
    await controller.load();

    final first = await controller.add(source());
    final duplicate = await controller.add(source(name: 'renamed.srt'));

    expect(first?.id, duplicate?.id);
    expect(controller.state.entries, hasLength(1));
    expect(controller.state.error, isNull);
  });

  test('guards against a second operation while add is pending', () async {
    final repository = MemoryFavoriteSubtitleRepository();
    final gate = Completer<void>();
    repository.addGate = gate;
    final controller = FavoritesController(repository);
    await controller.load();

    final first = controller.add(source());
    await Future<void>.delayed(Duration.zero);
    final second = await controller.add(source(name: 'other.srt'));

    expect(second, isNull);
    expect(repository.addCount, 1);
    gate.complete();
    expect(await first, isNotNull);
    expect(controller.state.isOperating, isFalse);
  });

  test('removes an entry and updates all observers', () async {
    final repository = MemoryFavoriteSubtitleRepository();
    final controller = FavoritesController(repository);
    await controller.load();
    final entry = await controller.add(source());

    expect(await controller.remove(entry!.id), isTrue);

    expect(controller.state.entries, isEmpty);
    expect(repository.removeCount, 1);
  });

  test('marks an unreadable open as recoverable broken state', () async {
    final repository = MemoryFavoriteSubtitleRepository();
    final controller = FavoritesController(repository);
    await controller.load();
    final entry = await controller.add(source());
    repository.openError = const FavoriteSubtitleException(
      FavoriteSubtitleFailureKind.unreadable,
      'Damaged copy',
    );

    await expectLater(
      controller.openSource(entry!.id),
      throwsA(isA<FavoriteSubtitleException>()),
    );

    expect(controller.state.brokenIds, contains(entry.id));
    expect(controller.state.error, 'Damaged copy');
    expect(controller.state.isOperating, isFalse);
    controller.clearError();
    expect(controller.state.error, isNull);
  });

  test('does not turn a committed add into a list refresh failure', () async {
    final repository = MemoryFavoriteSubtitleRepository();
    final controller = FavoritesController(repository);
    await controller.load();
    repository.listError = StateError('refresh failed');

    final entry = await controller.add(source());

    expect(entry, isNotNull);
    expect(controller.state.entries.single.id, entry!.id);
    expect(controller.state.error, isNull);
  });

  test('does not notify after disposal while add is pending', () async {
    final repository = MemoryFavoriteSubtitleRepository();
    final gate = Completer<void>();
    repository.addGate = gate;
    final controller = FavoritesController(repository);
    await controller.load();
    final pending = controller.add(source());
    await Future<void>.delayed(Duration.zero);

    controller.dispose();
    gate.complete();

    expect(await pending, isNotNull);
  });

  test('blocks mutations while the initial load is pending', () async {
    final repository = MemoryFavoriteSubtitleRepository();
    final gate = Completer<void>();
    repository.listGate = gate;
    final controller = FavoritesController(repository);

    final loading = controller.load();
    await Future<void>.delayed(Duration.zero);

    expect(await controller.add(source()), isNull);
    expect(repository.addCount, 0);
    gate.complete();
    await loading;
    expect(controller.state.isLoading, isFalse);
  });

  test('does not start repository operations after disposal', () async {
    final repository = MemoryFavoriteSubtitleRepository();
    final controller = FavoritesController(repository);
    await controller.load();
    controller.dispose();

    expect(await controller.add(source()), isNull);
    expect(await controller.remove('id'), isFalse);
    expect(repository.addCount, 0);
    expect(repository.removeCount, 0);
  });
}
