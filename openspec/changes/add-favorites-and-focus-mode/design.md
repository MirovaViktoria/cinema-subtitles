## Context

См. `proposal.md` для мотивации. Текущий MVP получает `XFile` через
`file_selector`; Android implementation копирует выбранный документ во временный
app cache, а `SubtitleDocument` хранит только имя, reference и timeline. Такая
reference подходит для best-effort восстановления последнего файла, но не для
постоянного избранного.

Player timing уже изолирован в `PlayerController` и `PlaybackClock`. Новое
состояние видимости controls не должно входить в clock или менять lookup time.

## Goals / Non-Goals

**Goals:**

- Постоянная приватная копия каждого избранного файла.
- Идемпотентное добавление одинакового содержимого.
- Атомарная согласованность metadata и завершённых file copies.
- Один repository API для home screen и player screen.
- Focus mode как локальное UI state без влияния на domain timing.
- Полностью offline implementation без новых storage permissions.

**Non-Goals:**

- Аудио, cloud sync, export избранного и folder import.
- Отдельная playback position для каждой favorite entry.
- Persisted hidden state или автоматический timeout controls.
- Изменение parser/timeline/clock semantics.

## Decisions

### Приватное application support directory

`FavoriteSubtitleRepository` будет копировать bytes в каталог
`<application-support>/favorites/`, полученный через `path_provider`. В отличие от
picker cache, application support directory сохраняется между перезапусками и
доступно без broad storage permissions.

Альтернатива: хранить Android URI permission. `file_selector` не предоставляет
стабильный persistable URI contract, а provider может отозвать доступ, поэтому
эта схема не удовлетворяет требованиям избранного.

### Content-addressed storage

Repository вычисляет SHA-256 исходных bytes через пакет `crypto`. `id` равен
hex digest, а файл сохраняется как `<digest>.srt` или `<digest>.vtt`. Одинаковые
bytes дают одну запись независимо от имени cache-файла.

Metadata model содержит `id`, display name, format, private path и `addedAt`.
User-facing имя сохраняется от первого успешного добавления. При повторном
добавлении существующая запись возвращается без новой копии.

Альтернатива: идентификация по имени. Она создаёт коллизии для разных фильмов и
дубликаты одного содержимого под разными именами.

### Атомарная запись и сериализация операций

Добавление выполняется в следующем порядке:

1. вычислить digest;
2. записать bytes во временный файл внутри favorites directory;
3. atomically rename временный файл в content-addressed path;
4. обновить единый JSON metadata snapshot;
5. при metadata failure удалить только что созданную копию.

Операции repository сериализуются одной queue. Metadata хранится одним JSON
snapshot с version key, аналогично существующему atomic player preferences
snapshot. Startup reconciliation удаляет orphan temporary files, но не удаляет
metadata при пропавшей copy, чтобы UI мог показать ошибку и предложить cleanup.

### Application-owned repository abstraction

Feature layer получает interface с операциями `list`, `add`, `remove`, `findById`
и `openSource`. Infrastructure implementation владеет `path_provider`, hashing,
filesystem и metadata storage. UI и domain timing не импортируют platform types.

Текущий file-loading flow расширяется source payload с исходными bytes и format,
чтобы repository не зависел от нестабильного cache path после открытия player.
Favorite open возвращает обычный subtitle source и повторно использует тот же
parser adapter и `SubtitleTimeline`.

### Один FavoritesController на application scope

Root приложения создаёт `FavoritesController`, который загружает repository list,
предоставляет loading/error state и уведомляет home/player screens после add или
remove. Player screen получает текущий source payload и показывает outline/filled
favorite button. Home screen отображает entries недавно добавленными первыми.

Удаление требует confirmation dialog. Если удаляется текущая favorite entry,
текущая уже разобранная timeline продолжает работать до выхода с player screen,
но запись и будущий quick open исчезают.

### Focus mode остаётся widget state

`PlayerScreen` хранит `controlsVisible`, начально `true`. Кнопка header меняет его
на `false`; hidden layout оставляет только расширенный `SubtitleView` внутри
opaque tap target. Тап устанавливает `true`.

Состояние не добавляется в `PlayerController`, persistence и timer, поэтому
play/pause, position, rate, delay и active cues продолжают вычисляться без
re-anchor или побочных записей. Existing immersive system UI mode сохраняется.

## Risks / Trade-offs

- [Нехватка места во время copy] → temporary file и metadata публикуются только
  после полной записи; ошибка показывается без favorite entry.
- [Process death между rename и metadata update] → startup orphan cleanup по
  отсутствующим digest в metadata.
- [Metadata есть, copy отсутствует] → entry остаётся видимой как broken и может
  быть удалена пользователем.
- [Большой subtitle file блокирует UI] → hashing/copy выполняются асинхронно, UI
  показывает progress и запрещает повторный add до завершения.
- [Удаление файла завершилось неудачно] → metadata скрывается после подтверждения,
  path ставится в cleanup queue; другие favorites не затрагиваются.
- [Application uninstall удаляет favorites] → это ожидаемое свойство private
  storage; backup/export не входит в change.
- [Конфликт с активным MVP change] → используются новые capability paths;
  implementation опирается на текущий код, но архивирование выполняется в
  согласованном порядке после завершения MVP field test.

## Migration Plan

1. Проверить и зафиксировать версии/лицензии `path_provider` и `crypto`.
2. Добавить repository schema `subtitle_favorites.v1`; migration старых данных не нужна.
3. Выпустить UI без автоматического импорта last-file reference в избранное.
4. При rollback metadata и private copies остаются нетронутыми и будут снова
   доступны после возврата версии с favorites support.
5. После успешных tests обновить dependency documentation и Android test report.
