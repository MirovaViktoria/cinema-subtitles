## 1. Dependencies и data contracts

- [x] 1.1 Проверить актуальные версии и лицензии `path_provider` и `crypto`, зафиксировать их в `pubspec.yaml` и `docs/dependencies.md`.
- [x] 1.2 Расширить subtitle source payload исходными bytes и format без утечки `XFile` или parser-package types в feature/domain layers.
- [x] 1.3 Добавить tests, подтверждающие одинаковый payload для picker cache и private favorite source.
- [x] 1.4 Реализовать application-owned `FavoriteSubtitle` model и repository interface для list/add/remove/open operations.

## 2. Persistent favorites repository

- [x] 2.1 Реализовать private favorites directory через `path_provider` и injectable directory provider для tests.
- [x] 2.2 Реализовать SHA-256 content identity, temporary write и atomic rename для SRT/VTT copies.
- [x] 2.3 Реализовать единый versioned JSON metadata snapshot и сериализованную operation queue.
- [x] 2.4 Реализовать idempotent add и сортировку entries от недавно добавленных к старым.
- [x] 2.5 Реализовать open private source, missing/corrupt copy failures и startup cleanup orphan temporary files.
- [x] 2.6 Реализовать confirmed remove, best-effort file cleanup и cleanup queue для неудачного удаления.
- [x] 2.7 Покрыть repository tests: SRT/VTT copy, deduplication, restart, concurrent operations, disk/write failure, missing copy и remove.

## 3. Favorites application state

- [x] 3.1 Реализовать application-scoped `FavoritesController` с immutable loading/data/error state.
- [x] 3.2 Реализовать add/remove/open commands и синхронизацию favorite state между home и текущим player screen.
- [x] 3.3 Покрыть controller tests для success, duplicate add, operation-in-progress guard и recoverable errors.
- [x] 3.4 Подключить repository/controller в app bootstrap без изменения playback clock, timeline и delay semantics.

## 4. Favorites UI

- [x] 4.1 Добавить на главный экран секцию избранных с filename, format и recently-added ordering.
- [x] 4.2 Реализовать открытие favorite entry через существующий parser/player flow.
- [x] 4.3 Добавить удаление с confirmation dialog и отдельное действие cleanup для broken entry.
- [x] 4.4 Добавить на player header outline/filled favorite button, progress state и понятный success/error feedback.
- [x] 4.5 Реализовать удаление текущего favorite через filled button с подтверждением, не прерывая текущую timeline.
- [x] 4.6 Добавить widget/integration tests: persistent home list, favorite open, add state, duplicate, confirmed/cancelled remove и broken copy UI.

## 5. Player focus mode

- [x] 5.1 Добавить локальное `controlsVisible = true` в lifecycle каждого `PlayerScreen`.
- [x] 5.2 Добавить header button, скрывающую header, timestamp, readouts и playback/sync controls с расширением subtitle area.
- [x] 5.3 Добавить opaque tap target на скрытой subtitle area для восстановления controls одним тапом.
- [x] 5.4 Покрыть widget tests: hide/show, initial visible state, playback без position jump, неизменные rate/delay и multiple/long cues в focus mode.

## 6. Verification и документация

- [x] 6.1 Запустить `dart format`, `flutter analyze`, полный `flutter test --coverage` и strict OpenSpec validation.
- [x] 6.2 Собрать debug/release APK и проверить отсутствие новых network/broad-storage permissions.
- [x] 6.3 На физическом Android проверить add → process restart → favorite open после удаления picker cache.
- [x] 6.4 На физическом Android проверить focus mode во время playback, overlaps, long text и возврат controls тапом.
- [x] 6.5 Обновить README, dependency documentation и Android manual test report.
