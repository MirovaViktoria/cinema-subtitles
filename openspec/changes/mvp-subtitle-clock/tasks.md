# Задачи первого MVP

## 1. Основа проекта

- [x] 1.1 Инициализировать Android-only Flutter project и базовый OLED theme.
- [x] 1.2 Настроить OpenSpec на русский язык и создать change для MVP.
- [x] 1.3 Добавить format, analyze, test, OpenSpec validation и GitHub Actions CI.

## 2. Domain layer

- [x] 2.1 Реализовать `SubtitleCue` и валидацию временного диапазона.
- [x] 2.2 Реализовать anchor-based `PlaybackClock` с внедряемым monotonic time source.
- [x] 2.3 Покрыть clock unit tests: play/pause, seek, rate, отсутствие скачка и drift.
- [x] 2.4 Реализовать `SubtitleTimeline` с active/next/previous/nearby queries.
- [x] 2.5 Покрыть timeline tests для границ, overlaps, long cues и произвольного seek.

## 3. Импорт субтитров

- [x] 3.1 Выбрать и зафиксировать parser/file-picker packages после проверки API и licenses.
- [x] 3.2 Реализовать parser abstraction и adapter для SRT и WebVTT.
- [x] 3.3 Добавить fixtures и tests для overlaps, long cues, encoding и malformed input.
- [x] 3.4 Реализовать Android document picker и понятные application-level errors.

## 4. Синхронизация

- [x] 4.1 Реализовать player state/controller и UI refresh без инкремента позиции.
- [x] 4.2 Добавить play/pause, seek -10/-1/+1/+10 seconds и exact timestamp jump.
- [x] 4.3 Добавить rate step 0.001x, reset и tests отсутствия position jump.
- [x] 4.4 Добавить независимый subtitle delay, reset и lookup tests.
- [x] 4.5 Добавить previous/next, nearby cue browser и действие `Sync here`.

## 5. Cinema UI и lifecycle

- [x] 5.1 Реализовать OLED player screen и независимый render всех active cues.
- [x] 5.2 Добавить адаптацию длинного текста и ручное изменение font size.
- [x] 5.3 Управлять wake lock строго в lifecycle player screen.
- [x] 5.4 Приостанавливать playback при уходе приложения из active lifecycle.
- [x] 5.5 Сохранять настройки, позицию и доступную ссылку на последний файл.
- [x] 5.6 Добавить widget/integration tests controls, multiple cues и parse error UI.

## 6. Проверка релиза

- [ ] 6.1 Выполнить manual Android scenarios из `03-implementation-and-tests.md`.
- [x] 6.2 Проверить отсутствие обязательного network access и лишних permissions.
- [x] 6.3 Запустить format, analyze, все tests и strict OpenSpec validation.
- [x] 6.4 Обновить README пользовательскими инструкциями и подготовить Android build.
