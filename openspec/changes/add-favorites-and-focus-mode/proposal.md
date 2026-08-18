## Why

Во время просмотра фильма controls занимают значительную часть экрана и отвлекают
от субтитров. Кроме того, повторный поиск уже использованного SRT/VTT через
Android document picker неудобен, а текущая cache reference может исчезнуть после
перезапуска или очистки временных файлов.

## What Changes

- Player screen получит кнопку скрытия всех controls; subtitle area расширится,
  а один тап по ней вернёт меню.
- Текущий файл субтитров можно будет добавить в избранное с player screen.
- При добавлении приложение скопирует SRT/VTT в приватное постоянное хранилище,
  не зависящее от временного Android picker cache.
- Главный экран покажет список избранных файлов с быстрым открытием и удалением.
- Повторное добавление того же содержимого не создаст дубликат.
- Повреждённая или отсутствующая приватная копия будет показана как понятная
  ошибка с возможностью удалить неработающую запись.

## Capabilities

### New Capabilities

- `player-focus-mode`: скрытие player controls и восстановление меню тапом без
  влияния на playback clock, active cues и synchronization state.
- `subtitle-favorites`: постоянное offline-хранилище копий SRT/VTT, список
  избранного на главном экране, открытие и удаление записей.

### Modified Capabilities

Нет. Основные capabilities MVP ещё находятся в активном change
`mvp-subtitle-clock`, поэтому новые требования изолированы в отдельных
capabilities и не объявляют уже реализованное поведение завершённым.

## Non-goals

- Сохранение или воспроизведение аудиофайлов и аудиодорожек.
- Cloud sync, аккаунты, network backup или обмен избранным.
- Импорт целых папок и автоматический поиск субтитров.
- Сохранение позиции playback отдельно для каждого избранного файла в этом change.
- Автоматическое скрытие controls по таймеру.

## Impact

- Новая repository abstraction для избранного и приватных копий файлов.
- Новые metadata и file lifecycle rules поверх локального persistence.
- Дополнительные open-source зависимости для application support directory и
  content hash (`path_provider`, `crypto`) после проверки версий и лицензий.
- Изменения home screen, player header и UI state видимости controls.
- Новые unit/widget/device tests; сетевые API и broad storage permissions не нужны.
- Основные риски: неполная запись при сбое, orphan files, нехватка места и
  рассинхронизация metadata с приватной копией.
