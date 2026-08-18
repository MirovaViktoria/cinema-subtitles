import 'dart:convert';
import 'dart:io';

import 'package:cinema_subtitles/domain/subtitle_source.dart';
import 'package:cinema_subtitles/features/favorites/favorite_subtitle.dart';
import 'package:cinema_subtitles/infrastructure/file_favorite_subtitle_repository.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory supportDirectory;
  late DateTime now;
  late FileFavoriteSubtitleRepository repository;

  SubtitleSource source({
    String name = 'movie.srt',
    String contents = '1\n00:00:01,000 --> 00:00:02,000\nHello\n',
    SubtitleFormat format = SubtitleFormat.srt,
  }) {
    return SubtitleSource(
      name: name,
      reference: 'cache/$name',
      bytes: utf8.encode(contents),
      format: format,
    );
  }

  FileFavoriteSubtitleRepository createRepository({
    FavoriteFileDelete? deleteFile,
  }) {
    return FileFavoriteSubtitleRepository(
      supportDirectory: () async => supportDirectory,
      now: () => now,
      deleteFile: deleteFile,
    );
  }

  setUp(() async {
    supportDirectory = await Directory.systemTemp.createTemp(
      'cinema_subtitles_favorites_',
    );
    now = DateTime.utc(2026, 8, 18, 12);
    repository = createRepository();
  });

  tearDown(() async {
    if (await supportDirectory.exists()) {
      await supportDirectory.delete(recursive: true);
    }
  });

  test('copies SRT bytes into content-addressed private storage', () async {
    final input = source();
    final expectedId = sha256.convert(input.bytes).toString();

    final entry = await repository.add(input);

    expect(entry.id, expectedId);
    expect(entry.privatePath, endsWith('$expectedId.srt'));
    expect(await File(entry.privatePath).readAsBytes(), input.bytes);
    expect(entry.addedAt, now);
  });

  test('uses the VTT extension and opens an equivalent source', () async {
    final input = source(
      name: 'movie.vtt',
      contents: 'WEBVTT\n\n00:01.000 --> 00:02.000\nHello\n',
      format: SubtitleFormat.webVtt,
    );
    final entry = await repository.add(input);

    final reopened = await repository.openSource(entry.id);

    expect(entry.privatePath, endsWith('.vtt'));
    expect(reopened.name, input.name);
    expect(reopened.bytes, input.bytes);
    expect(reopened.format, input.format);
    expect(reopened.favoriteId, entry.id);
  });

  test('deduplicates identical bytes and preserves the first name', () async {
    final first = await repository.add(source());
    final duplicate = await repository.add(source(name: 'renamed.srt'));

    expect(duplicate.id, first.id);
    expect(duplicate.displayName, 'movie.srt');
    expect(await repository.list(), hasLength(1));
  });

  test('replaces an unreferenced target with the expected bytes', () async {
    final input = source();
    final id = sha256.convert(input.bytes).toString();
    await repository.list();
    final orphan = File(
      '${supportDirectory.path}${Platform.pathSeparator}favorites'
      '${Platform.pathSeparator}$id.srt',
    );
    await orphan.writeAsString('wrong but valid UTF-8', flush: true);

    final entry = await repository.add(input);

    expect(entry.id, id);
    expect(await File(entry.privatePath).readAsBytes(), input.bytes);
  });

  test('rejects an empty display name before writing a copy', () async {
    await expectLater(
      repository.add(source(name: '')),
      throwsA(
        isA<FavoriteSubtitleException>().having(
          (error) => error.kind,
          'kind',
          FavoriteSubtitleFailureKind.unreadable,
        ),
      ),
    );
    expect(await repository.list(), isEmpty);
  });

  test('persists entries across restart in recently-added order', () async {
    final older = await repository.add(source(name: 'older.srt'));
    now = now.add(const Duration(minutes: 1));
    final newer = await repository.add(
      source(
        name: 'newer.srt',
        contents: '1\n00:00:03,000 --> 00:00:04,000\nNew\n',
      ),
    );

    final restarted = createRepository();
    final entries = await restarted.list();

    expect(entries.map((entry) => entry.id), [newer.id, older.id]);
  });

  test('serializes concurrent additions without losing metadata', () async {
    final results = await Future.wait([
      repository.add(source()),
      repository.add(source(name: 'duplicate.srt')),
      repository.add(
        source(
          name: 'other.srt',
          contents: '1\n00:00:03,000 --> 00:00:04,000\nOther\n',
        ),
      ),
    ]);

    expect(results[0].id, results[1].id);
    expect(await repository.list(), hasLength(2));
    expect(await createRepository().list(), hasLength(2));
  });

  test('reports a storage failure without publishing an entry', () async {
    final favoritesPath =
        '${supportDirectory.path}${Platform.pathSeparator}favorites';
    await File(favoritesPath).writeAsString('not a directory');

    await expectLater(
      repository.add(source()),
      throwsA(
        isA<FavoriteSubtitleException>().having(
          (error) => error.kind,
          'kind',
          FavoriteSubtitleFailureKind.storage,
        ),
      ),
    );
    expect(await File(favoritesPath).readAsString(), 'not a directory');
  });

  test('keeps missing metadata entries visible and rejects open', () async {
    final entry = await repository.add(source());
    await File(entry.privatePath).delete();

    final listed = await repository.list();

    expect(listed.single.isAvailable, isFalse);
    await expectLater(
      repository.openSource(entry.id),
      throwsA(
        isA<FavoriteSubtitleException>().having(
          (error) => error.kind,
          'kind',
          FavoriteSubtitleFailureKind.unreadable,
        ),
      ),
    );
  });

  test('reports a damaged private copy', () async {
    final entry = await repository.add(source());
    await File(entry.privatePath).writeAsBytes([0xC3, 0x28], flush: true);

    await expectLater(
      repository.openSource(entry.id),
      throwsA(
        isA<FavoriteSubtitleException>().having(
          (error) => error.kind,
          'kind',
          FavoriteSubtitleFailureKind.unreadable,
        ),
      ),
    );
  });

  test('detects a valid UTF-8 copy with the wrong content hash', () async {
    final input = source();
    final entry = await repository.add(input);
    await File(
      entry.privatePath,
    ).writeAsString('1\n00:00:03,000 --> 00:00:04,000\nChanged\n', flush: true);

    await expectLater(
      repository.openSource(entry.id),
      throwsA(
        isA<FavoriteSubtitleException>().having(
          (error) => error.kind,
          'kind',
          FavoriteSubtitleFailureKind.unreadable,
        ),
      ),
    );

    await repository.add(input);
    expect((await repository.openSource(entry.id)).bytes, input.bytes);
  });

  test('removes metadata and the private copy', () async {
    final entry = await repository.add(source());

    await repository.remove(entry.id);

    expect(await repository.list(), isEmpty);
    expect(await File(entry.privatePath).exists(), isFalse);
    expect(await createRepository().findById(entry.id), isNull);
  });

  test('persists failed cleanup and retries it after restart', () async {
    var deleteAttempts = 0;
    repository = createRepository(
      deleteFile: (file) async {
        deleteAttempts++;
        throw const FileSystemException('busy');
      },
    );
    final entry = await repository.add(source());

    await repository.remove(entry.id);

    expect(deleteAttempts, 1);
    expect(await File(entry.privatePath).exists(), isTrue);
    expect(await repository.list(), isEmpty);

    expect(await createRepository().list(), isEmpty);
    expect(await File(entry.privatePath).exists(), isFalse);
  });

  test('re-add clears a pending cleanup tombstone', () async {
    final input = source();
    repository = createRepository(
      deleteFile: (file) async {
        throw const FileSystemException('busy');
      },
    );
    final removed = await repository.add(input);
    await repository.remove(removed.id);

    final restored = await repository.add(input);
    final restarted = createRepository();

    expect(restored.id, removed.id);
    expect((await restarted.list()).single.id, restored.id);
    expect((await restarted.openSource(restored.id)).bytes, input.bytes);
  });

  test('removes orphan temporary and content files on startup', () async {
    await repository.list();
    final favorites = Directory(
      '${supportDirectory.path}${Platform.pathSeparator}favorites',
    );
    final temporary = File(
      '${favorites.path}${Platform.pathSeparator}unfinished.tmp',
    );
    final orphan = File('${favorites.path}${Platform.pathSeparator}orphan.srt');
    await temporary.writeAsString('partial');
    await orphan.writeAsString('orphan');

    await createRepository().list();

    expect(await temporary.exists(), isFalse);
    expect(await orphan.exists(), isFalse);
  });

  test('reports invalid metadata instead of discarding it', () async {
    await repository.add(source());
    final metadata = File(
      '${supportDirectory.path}${Platform.pathSeparator}favorites'
      '${Platform.pathSeparator}subtitle_favorites.v1.json',
    );
    await metadata.writeAsString('{broken', flush: true);

    await expectLater(
      createRepository().list(),
      throwsA(
        isA<FavoriteSubtitleException>().having(
          (error) => error.kind,
          'kind',
          FavoriteSubtitleFailureKind.invalidMetadata,
        ),
      ),
    );
  });

  test('rejects cleanup metadata that targets an active copy', () async {
    final entry = await repository.add(source());
    final metadata = File(
      '${supportDirectory.path}${Platform.pathSeparator}favorites'
      '${Platform.pathSeparator}subtitle_favorites.v1.json',
    );
    final value =
        jsonDecode(await metadata.readAsString()) as Map<String, Object?>;
    value['cleanupFiles'] = [entry.privatePath.split(RegExp(r'[/\\]')).last];
    await metadata.writeAsString(jsonEncode(value), flush: true);

    await expectLater(
      createRepository().list(),
      throwsA(
        isA<FavoriteSubtitleException>().having(
          (error) => error.kind,
          'kind',
          FavoriteSubtitleFailureKind.invalidMetadata,
        ),
      ),
    );
    expect(await File(entry.privatePath).exists(), isTrue);
  });
}
