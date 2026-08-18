# Дизайн первого MVP

## Контекст

Приложение запускает независимые часы одновременно с фильмом и отображает cues,
активные в рассчитанный момент. Ошибки синхронизации исправляются тремя
независимыми операциями: seek, subtitle delay и playback rate. UI refresh не
должен быть источником времени.

Подробные исходные решения описаны в `02-architecture.md`.

## Цели

- Детерминированная и тестируемая domain-логика времени.
- Корректная работа при произвольном seek и пересечении нескольких cues.
- Полностью офлайн-MVP с минимальными Android permissions.
- Разделение domain-моделей и типов стороннего subtitle parser.

## Non-goals

- Универсальный media player.
- Фоновое воспроизведение при неактивном приложении.
- Сложное форматирование ASS/SSA или TTML.
- Выбор окончательной архитектуры для будущих iOS/desktop clients.

## Решения

### Монотонные anchor-based часы

`PlaybackClock` хранит anchor position, monotonic elapsed anchor, rate и флаг
play/pause. Текущая позиция во время проигрывания вычисляется как
`anchorPosition + elapsedSinceAnchor * rate`. Play, pause, seek и изменение rate
сначала фиксируют текущую позицию и создают новый anchor.

Это исключает накопление ошибок UI timer и скачок позиции при изменении rate.

### Application-owned timeline

Parser adapter преобразует сторонние модели в `SubtitleCue` с `start`, `end`,
`text` и `sourceIndex`. Timeline определяет активность по правилу
`start <= position < end` и возвращает список, а не единственный cue.
Пересекающиеся и длинные cues не объединяются в domain layer.

### Независимый subtitle delay

Playback position представляет время фильма. Delay применяется только перед
timeline query: `lookupTime = playbackPosition - subtitleDelay`. Тimestamps cues
не переписываются.

### UI и state

Feature controller объединяет clock, timeline и настройки в immutable view state.
Периодический UI refresh только читает актуальную позицию. Player screen
рендерит каждый active cue независимо, включает wake lock на время присутствия
экрана и выключает его при выходе.

### Файлы и offline mode

Android system document picker предоставляет выбранный файл без широкого storage
permission. Infrastructure adapter определяет SRT/VTT, декодирует содержимое и
конвертирует ошибки в application-level failure. Сетевые API не добавляются.

### Lifecycle и persistence

При потере active lifecycle MVP ставит часы на pause и сохраняет позицию.
Локально сохраняются rate, delay, font size, OLED setting, позиция и ссылка на
последний файл, если Android разрешает повторный доступ к URI.

## Риски и компромиссы

- Поддержка encoding зависит от выбранного parser/decoder; ошибки должны быть явными.
- Доступ к сохранённому URI может быть отозван; приложение вернётся к выбору файла.
- Частый UI refresh расходует батарею; 50-100 ms достаточно для визуальной точности.
- Конкретные package versions и licenses проверяются непосредственно перед добавлением.

## План проверки

- Unit tests clock и timeline с управляемым monotonic time source.
- Parser fixtures для overlaps, long cues, одинакового start/range и malformed input.
- Widget tests controls и одновременного отображения нескольких cues.
- Manual Android tests длительной синхронизации, lifecycle и file picker URI.
