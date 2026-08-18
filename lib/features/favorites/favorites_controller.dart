import 'package:cinema_subtitles/domain/subtitle_source.dart';
import 'package:cinema_subtitles/features/favorites/favorite_subtitle.dart';
import 'package:flutter/foundation.dart';

final class FavoritesState {
  FavoritesState({
    this.isLoading = true,
    Iterable<FavoriteSubtitle> entries = const [],
    this.operationId,
    this.error,
    Iterable<String> brokenIds = const [],
  }) : entries = List.unmodifiable(entries),
       brokenIds = Set.unmodifiable(brokenIds);

  static const _unchanged = Object();

  final bool isLoading;
  final List<FavoriteSubtitle> entries;
  final String? operationId;
  final String? error;
  final Set<String> brokenIds;

  bool get isOperating => operationId != null;

  FavoritesState copyWith({
    bool? isLoading,
    Iterable<FavoriteSubtitle>? entries,
    Object? operationId = _unchanged,
    Object? error = _unchanged,
    Iterable<String>? brokenIds,
  }) {
    return FavoritesState(
      isLoading: isLoading ?? this.isLoading,
      entries: entries ?? this.entries,
      operationId: identical(operationId, _unchanged)
          ? this.operationId
          : operationId as String?,
      error: identical(error, _unchanged) ? this.error : error as String?,
      brokenIds: brokenIds ?? this.brokenIds,
    );
  }
}

final class FavoritesController extends ChangeNotifier {
  FavoritesController(this._repository);

  final FavoriteSubtitleRepository _repository;
  FavoritesState _state = FavoritesState();
  bool _disposed = false;

  FavoritesState get state => _state;

  Future<void> load() async {
    if (_disposed || _state.isOperating) {
      return;
    }
    _setState(
      _state.copyWith(isLoading: true, operationId: 'load', error: null),
    );
    try {
      final entries = await _repository.list();
      final unavailable = entries
          .where((entry) => !entry.isAvailable)
          .map((entry) => entry.id);
      _setState(
        _state.copyWith(
          entries: entries,
          brokenIds: {..._state.brokenIds, ...unavailable},
        ),
      );
    } on Object catch (error) {
      _setState(_state.copyWith(error: error.toString()));
    } finally {
      _setState(_state.copyWith(isLoading: false, operationId: null));
    }
  }

  Future<FavoriteSubtitle?> add(SubtitleSource source) async {
    if (_disposed || _state.isLoading || _state.isOperating) {
      return null;
    }
    _setState(_state.copyWith(operationId: 'add', error: null));
    try {
      final entry = await _repository.add(source);
      final entries = [
        entry,
        ..._state.entries.where((current) => current.id != entry.id),
      ]..sort((left, right) => right.addedAt.compareTo(left.addedAt));
      final brokenIds = {..._state.brokenIds}..remove(entry.id);
      _setState(
        _state.copyWith(entries: entries, brokenIds: brokenIds, error: null),
      );
      return entry;
    } on Object catch (error) {
      _setState(_state.copyWith(error: error.toString()));
      rethrow;
    } finally {
      _setState(_state.copyWith(operationId: null));
    }
  }

  Future<bool> remove(String id) async {
    if (_disposed || _state.isLoading || _state.isOperating) {
      return false;
    }
    _setState(_state.copyWith(operationId: id, error: null));
    try {
      await _repository.remove(id);
      final brokenIds = {..._state.brokenIds}..remove(id);
      _setState(
        _state.copyWith(
          entries: _state.entries.where((entry) => entry.id != id),
          brokenIds: brokenIds,
          error: null,
        ),
      );
      return true;
    } on Object catch (error) {
      _setState(_state.copyWith(error: error.toString()));
      rethrow;
    } finally {
      _setState(_state.copyWith(operationId: null));
    }
  }

  Future<SubtitleSource> openSource(String id) async {
    if (_disposed || _state.isLoading || _state.isOperating) {
      throw const FavoriteSubtitleException(
        FavoriteSubtitleFailureKind.storage,
        'Another favorites operation is still in progress.',
      );
    }
    _setState(_state.copyWith(operationId: id, error: null));
    try {
      final source = await _repository.openSource(id);
      final brokenIds = {..._state.brokenIds}..remove(id);
      _setState(_state.copyWith(brokenIds: brokenIds, error: null));
      return source;
    } on Object catch (error) {
      markBroken(id, error);
      rethrow;
    } finally {
      _setState(_state.copyWith(operationId: null));
    }
  }

  FavoriteSubtitle? findById(String id) {
    for (final entry in _state.entries) {
      if (entry.id == id) {
        return entry;
      }
    }
    return null;
  }

  void markBroken(String id, Object error) {
    _setState(
      _state.copyWith(
        brokenIds: {..._state.brokenIds, id},
        error: error.toString(),
      ),
    );
  }

  void clearError() {
    if (_state.error != null) {
      _setState(_state.copyWith(error: null));
    }
  }

  void _setState(FavoritesState state) {
    if (_disposed) {
      return;
    }
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
