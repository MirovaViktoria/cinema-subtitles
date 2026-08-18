# Задачи первого MVP

## 1. Основа проекта

- [x] 1.1 Инициализировать Android-only Flutter project и базовый OLED theme.
- [x] 1.2 Настроить OpenSpec на русский язык и создать change для MVP.
- [x] 1.3 Добавить format, analyze, test, OpenSpec validation и GitHub Actions CI.

## 2. Domain layer

- [ ] 2.1 Реализовать `SubtitleCue` и валидацию временного диапазона.
- [ ] 2.2 Реализовать anchor-based `PlaybackClock` с внедряемым monotonic time source.
- [ ] 2.3 Покрыть clock unit tests: play/pause, seek, rate, отсутствие скачка и drift.
- [ ] 2.4 Реализовать `SubtitleTimeline` с active/next/previous/nearby queries.
- [ ] 2.5 Покрыть timeline tests для границ, overlaps, long cues и произвольного seek.

## 3. Импорт субтитров

- [ ] 3.1 Выбрать и зафиксировать parser/file-picker packages после проверки API и licenses.
- [ ] 3.2 Реализовать parser abstraction и adapter для SRT и WebVTT.
- [ ] 3.3 Добавить fixtures и tests для overlaps, long cues, encoding и malformed input.
- [ ] 3.4 Реализовать Android document picker и понятные application-level errors.

## 4. Синхронизация

- [ ] 4.1 Реализовать player state/controller и UI refresh без инкремента позиции.
- [ ] 4.2 Добавить play/pause, seek -10/-1/+1/+10 seconds и exact timestamp jump.
- [ ] 4.3 Добавить rate step 0.001x, reset и tests отсутствия position jump.
- [ ] 4.4 Добавить независимый subtitle delay, reset и lookup tests.
- [ ] 4.5 Добавить previous/next, nearby cue browser и действие `Sync here`.

## 5. Cinema UI и lifecycle

- [ ] 5.1 Реализовать OLED player screen и независимый render всех active cues.
- [ ] 5.2 Добавить адаптацию длинного текста и ручное изменение font size.
- [ ] 5.3 Управлять wake lock строго в lifecycle player screen.
- [ ] 5.4 Приостанавливать playback при уходе приложения из active lifecycle.
- [ ] 5.5 Сохранять настройки, позицию и доступную ссылку на последний файл.
- [ ] 5.6 Добавить widget/integration tests controls, multiple cues и parse error UI.

## 6. Проверка релиза

- [ ] 6.1 Выполнить manual Android scenarios из `03-implementation-and-tests.md`.
- [ ] 6.2 Проверить отсутствие обязательного network access и лишних permissions.
- [ ] 6.3 Запустить format, analyze, все tests и strict OpenSpec validation.
- [ ] 6.4 Обновить README пользовательскими инструкциями и подготовить Android build.
