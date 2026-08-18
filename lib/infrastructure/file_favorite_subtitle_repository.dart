import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cinema_subtitles/domain/subtitle_source.dart';
import 'package:cinema_subtitles/features/favorites/favorite_subtitle.dart';
import 'package:cinema_subtitles/infrastructure/subtitle_file_loader.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

typedef SupportDirectoryProvider = Future<Directory> Function();
typedef FavoriteFileDelete = Future<void> Function(File file);

final class FileFavoriteSubtitleRepository
    implements FavoriteSubtitleRepository {
  FileFavoriteSubtitleRepository({
    SupportDirectoryProvider? supportDirectory,
    DateTime Function()? now,
    FavoriteFileDelete? deleteFile,
  }) : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
       _now = now ?? DateTime.now,
       _deleteFile = deleteFile ?? _defaultDelete;

  static const _schemaVersion = 1;
  static const _metadataName = 'subtitle_favorites.v1.json';
  static const _backupName = 'subtitle_favorites.v1.json.bak';
  static final _digestPattern = RegExp(r'^[0-9a-f]{64}$');
  static final _favoriteFilePattern = RegExp(r'^[0-9a-f]{64}\.(srt|vtt)$');

  final SupportDirectoryProvider _supportDirectory;
  final DateTime Function() _now;
  final FavoriteFileDelete _deleteFile;

  Future<void> _queue = Future.value();
  Directory? _directory;
  List<FavoriteSubtitle> _entries = const [];
  Set<String> _cleanupFiles = const {};
  bool _loaded = false;

  @override
  Future<List<FavoriteSubtitle>> list() {
    return _serial(() async {
      await _ensureLoaded();
      return _entriesWithAvailability();
    });
  }

  @override
  Future<FavoriteSubtitle> add(SubtitleSource source) {
    return _serial(() async {
      await _ensureLoaded();
      if (source.name.trim().isEmpty) {
        throw const FavoriteSubtitleException(
          FavoriteSubtitleFailureKind.unreadable,
          'The subtitle file name is invalid.',
        );
      }
      final id = sha256.convert(source.bytes).toString();
      final existing = _find(id);
      if (existing != null) {
        try {
          final file = File(existing.privatePath);
          final copyIsCurrent =
              await file.exists() &&
              sha256.convert(await file.readAsBytes()).toString() == id;
          if (!copyIsCurrent) {
            await _deleteBestEffort(file);
            await _writeCopy(file, source.bytes);
          }
          final fileName = _fileName(existing.privatePath);
          if (_cleanupFiles.contains(fileName)) {
            final cleanupFiles = {..._cleanupFiles}..remove(fileName);
            await _writeMetadata(entries: _entries, cleanupFiles: cleanupFiles);
            _cleanupFiles = cleanupFiles;
          }
          return existing.copyWith(isAvailable: true);
        } on FavoriteSubtitleException {
          rethrow;
        } on Object catch (error) {
          throw FavoriteSubtitleException(
            FavoriteSubtitleFailureKind.storage,
            'The private subtitle copy could not be verified.',
            error,
          );
        }
      }

      final directory = _directory!;
      final fileName = '$id.${_extension(source.format)}';
      final target = File(_join(directory.path, fileName));
      var createdCopy = false;
      try {
        final targetIsCurrent =
            await target.exists() &&
            sha256.convert(await target.readAsBytes()).toString() == id;
        if (!targetIsCurrent) {
          await _deleteBestEffort(target);
          await _writeCopy(target, source.bytes);
          createdCopy = true;
        }
        final entry = FavoriteSubtitle(
          id: id,
          displayName: source.name,
          format: source.format,
          privatePath: target.path,
          addedAt: _now().toUtc(),
        );
        final updated = _sort([entry, ..._entries]);
        final cleanupFiles = {..._cleanupFiles}..remove(fileName);
        await _writeMetadata(entries: updated, cleanupFiles: cleanupFiles);
        _entries = updated;
        _cleanupFiles = cleanupFiles;
        return entry;
      } on FavoriteSubtitleException {
        if (createdCopy) {
          await _deleteBestEffort(target);
        }
        rethrow;
      } on Object catch (error) {
        if (createdCopy) {
          await _deleteBestEffort(target);
        }
        throw FavoriteSubtitleException(
          FavoriteSubtitleFailureKind.storage,
          'The subtitle could not be added to favorites.',
          error,
        );
      }
    });
  }

  @override
  Future<void> remove(String id) {
    return _serial(() async {
      await _ensureLoaded();
      final entry = _find(id);
      if (entry == null) {
        throw const FavoriteSubtitleException(
          FavoriteSubtitleFailureKind.notFound,
          'The favorite subtitle no longer exists.',
        );
      }

      final fileName = _fileName(entry.privatePath);
      final remaining = _entries.where((item) => item.id != id).toList();
      final pendingCleanup = {..._cleanupFiles, fileName};
      await _writeMetadata(entries: remaining, cleanupFiles: pendingCleanup);
      _entries = _sort(remaining);
      _cleanupFiles = pendingCleanup;
      await _retryCleanup();
    });
  }

  @override
  Future<FavoriteSubtitle?> findById(String id) {
    return _serial(() async {
      await _ensureLoaded();
      final entry = _find(id);
      if (entry == null) {
        return null;
      }
      return entry.copyWith(
        isAvailable: await File(entry.privatePath).exists(),
      );
    });
  }

  @override
  Future<SubtitleSource> openSource(String id) {
    return _serial(() async {
      await _ensureLoaded();
      final entry = _find(id);
      if (entry == null) {
        throw const FavoriteSubtitleException(
          FavoriteSubtitleFailureKind.notFound,
          'The favorite subtitle no longer exists.',
        );
      }
      try {
        final bytes = await File(entry.privatePath).readAsBytes();
        SubtitleFileLoader.decodeUtf8(bytes);
        if (sha256.convert(bytes).toString() != entry.id) {
          throw const FavoriteSubtitleException(
            FavoriteSubtitleFailureKind.unreadable,
            'The favorite subtitle copy is damaged.',
          );
        }
        return SubtitleSource(
          name: entry.displayName,
          reference: entry.privatePath,
          bytes: bytes,
          format: entry.format,
          favoriteId: entry.id,
        );
      } on FavoriteSubtitleException {
        rethrow;
      } on SubtitleFileException catch (error) {
        throw FavoriteSubtitleException(
          FavoriteSubtitleFailureKind.unreadable,
          'The favorite subtitle copy is damaged.',
          error,
        );
      } on Object catch (error) {
        throw FavoriteSubtitleException(
          FavoriteSubtitleFailureKind.unreadable,
          'The favorite subtitle copy is unavailable.',
          error,
        );
      }
    });
  }

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        result.complete(await operation());
      } on Object catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) {
      return;
    }
    try {
      final supportDirectory = await _supportDirectory();
      final directory = Directory(_join(supportDirectory.path, 'favorites'));
      await directory.create(recursive: true);
      _directory = directory;
      await _recoverMetadataBackup();
      await _readMetadata();
      await _reconcileFiles();
      _loaded = true;
    } on FavoriteSubtitleException {
      rethrow;
    } on Object catch (error) {
      throw FavoriteSubtitleException(
        FavoriteSubtitleFailureKind.storage,
        'Favorites storage is unavailable.',
        error,
      );
    }
  }

  Future<void> _readMetadata() async {
    final metadata = File(_join(_directory!.path, _metadataName));
    if (!await metadata.exists()) {
      _entries = const [];
      _cleanupFiles = const {};
      return;
    }

    late final String encoded;
    try {
      encoded = await metadata.readAsString();
    } on Object catch (error) {
      throw FavoriteSubtitleException(
        FavoriteSubtitleFailureKind.storage,
        'Favorites metadata could not be read.',
        error,
      );
    }

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, Object?> ||
          decoded['version'] != _schemaVersion ||
          decoded['entries'] is! List<Object?> ||
          decoded['cleanupFiles'] is! List<Object?>) {
        throw const FormatException('Unsupported favorites metadata.');
      }
      final entries = (decoded['entries']! as List<Object?>)
          .map(_entryFromJson)
          .toList();
      final cleanupFiles = (decoded['cleanupFiles']! as List<Object?>).map((
        value,
      ) {
        if (value is! String ||
            !_favoriteFilePattern.hasMatch(value) ||
            value != _fileName(value)) {
          throw const FormatException('Invalid cleanup path.');
        }
        return value;
      }).toSet();
      final ids = entries.map((entry) => entry.id).toSet();
      final referencedFiles = entries
          .map((entry) => _fileName(entry.privatePath))
          .toSet();
      if (ids.length != entries.length ||
          referencedFiles.length != entries.length ||
          cleanupFiles.any(referencedFiles.contains)) {
        throw const FormatException('Conflicting favorites metadata.');
      }
      _entries = _sort(entries);
      _cleanupFiles = cleanupFiles;
    } on Object catch (error) {
      throw FavoriteSubtitleException(
        FavoriteSubtitleFailureKind.invalidMetadata,
        'Favorites metadata is damaged.',
        error,
      );
    }
  }

  FavoriteSubtitle _entryFromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const FormatException('Invalid favorite entry.');
    }
    final id = value['id'];
    final displayName = value['displayName'];
    final formatName = value['format'];
    final fileName = value['fileName'];
    final addedAtValue = value['addedAt'];
    if (id is! String ||
        !_digestPattern.hasMatch(id) ||
        displayName is! String ||
        displayName.isEmpty ||
        formatName is! String ||
        fileName is! String ||
        addedAtValue is! String) {
      throw const FormatException('Invalid favorite fields.');
    }
    final format = switch (formatName) {
      'srt' => SubtitleFormat.srt,
      'webVtt' => SubtitleFormat.webVtt,
      _ => throw const FormatException('Invalid subtitle format.'),
    };
    if (fileName != '$id.${_extension(format)}') {
      throw const FormatException('Invalid favorite file name.');
    }
    final addedAt = DateTime.tryParse(addedAtValue);
    if (addedAt == null) {
      throw const FormatException('Invalid favorite timestamp.');
    }
    return FavoriteSubtitle(
      id: id,
      displayName: displayName,
      format: format,
      privatePath: _join(_directory!.path, fileName),
      addedAt: addedAt.toUtc(),
    );
  }

  Future<void> _reconcileFiles() async {
    final referenced = _entries
        .map((entry) => _fileName(entry.privatePath))
        .toSet();
    await for (final entity in _directory!.list()) {
      if (entity is! File) {
        continue;
      }
      final name = _fileName(entity.path);
      final isTemporary = name.endsWith('.tmp');
      final isOrphanCopy =
          (name.endsWith('.srt') || name.endsWith('.vtt')) &&
          !referenced.contains(name);
      if (isTemporary || isOrphanCopy) {
        await _deleteBestEffort(entity);
      }
    }
    await _retryCleanup();
  }

  Future<void> _retryCleanup() async {
    if (_cleanupFiles.isEmpty) {
      return;
    }
    final remaining = <String>{};
    for (final fileName in _cleanupFiles) {
      final file = File(_join(_directory!.path, fileName));
      try {
        if (await file.exists()) {
          await _deleteFile(file);
        }
      } on Object {
        remaining.add(fileName);
      }
    }
    if (remaining.length != _cleanupFiles.length) {
      try {
        await _writeMetadata(entries: _entries, cleanupFiles: remaining);
      } on FavoriteSubtitleException {
        return;
      }
    }
    _cleanupFiles = remaining;
  }

  Future<void> _writeCopy(File target, List<int> bytes) async {
    final temporary = File(
      '${target.path}.${_now().toUtc().microsecondsSinceEpoch}.tmp',
    );
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(target.path);
    } on Object catch (error) {
      await _deleteBestEffort(temporary);
      throw FavoriteSubtitleException(
        FavoriteSubtitleFailureKind.storage,
        'The private subtitle copy could not be written.',
        error,
      );
    }
  }

  Future<void> _writeMetadata({
    required List<FavoriteSubtitle> entries,
    required Set<String> cleanupFiles,
  }) async {
    final directory = _directory!;
    final metadata = File(_join(directory.path, _metadataName));
    final backup = File(_join(directory.path, _backupName));
    final temporary = File(
      _join(
        directory.path,
        '.$_metadataName.${_now().toUtc().microsecondsSinceEpoch}.tmp',
      ),
    );
    final encoded = jsonEncode({
      'version': _schemaVersion,
      'entries': entries
          .map(
            (entry) => {
              'id': entry.id,
              'displayName': entry.displayName,
              'format': entry.format.name,
              'fileName': _fileName(entry.privatePath),
              'addedAt': entry.addedAt.toUtc().toIso8601String(),
            },
          )
          .toList(),
      'cleanupFiles': cleanupFiles.toList()..sort(),
    });

    var committed = false;
    try {
      await temporary.writeAsString(encoded, flush: true);
      if (await backup.exists()) {
        await backup.delete();
      }
      if (await metadata.exists()) {
        await metadata.rename(backup.path);
      }
      try {
        await temporary.rename(metadata.path);
        committed = true;
      } on Object {
        if (await backup.exists() && !await metadata.exists()) {
          await backup.rename(metadata.path);
        }
        rethrow;
      }
      await _deleteBestEffort(backup);
    } on Object catch (error) {
      await _deleteBestEffort(temporary);
      if (committed) {
        return;
      }
      throw FavoriteSubtitleException(
        FavoriteSubtitleFailureKind.storage,
        'Favorites metadata could not be saved.',
        error,
      );
    }
  }

  Future<void> _recoverMetadataBackup() async {
    final metadata = File(_join(_directory!.path, _metadataName));
    final backup = File(_join(_directory!.path, _backupName));
    if (!await backup.exists()) {
      return;
    }
    if (await metadata.exists()) {
      await _deleteBestEffort(backup);
    } else {
      await backup.rename(metadata.path);
    }
  }

  Future<List<FavoriteSubtitle>> _entriesWithAvailability() async {
    final result = <FavoriteSubtitle>[];
    for (final entry in _entries) {
      result.add(
        entry.copyWith(isAvailable: await File(entry.privatePath).exists()),
      );
    }
    return List.unmodifiable(result);
  }

  FavoriteSubtitle? _find(String id) {
    for (final entry in _entries) {
      if (entry.id == id) {
        return entry;
      }
    }
    return null;
  }

  static List<FavoriteSubtitle> _sort(Iterable<FavoriteSubtitle> entries) {
    final sorted = entries.toList()
      ..sort((left, right) {
        final addedComparison = right.addedAt.compareTo(left.addedAt);
        return addedComparison != 0
            ? addedComparison
            : left.id.compareTo(right.id);
      });
    return List.unmodifiable(sorted);
  }

  static String _extension(SubtitleFormat format) {
    return switch (format) {
      SubtitleFormat.srt => 'srt',
      SubtitleFormat.webVtt => 'vtt',
    };
  }

  static String _join(String parent, String child) {
    return '$parent${Platform.pathSeparator}$child';
  }

  static String _fileName(String path) {
    return path.split(RegExp(r'[/\\]')).last;
  }

  static Future<void> _defaultDelete(File file) => file.delete();

  static Future<void> _deleteBestEffort(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on Object {
      // A later reconciliation retries cleanup where metadata tracks the file.
    }
  }
}
