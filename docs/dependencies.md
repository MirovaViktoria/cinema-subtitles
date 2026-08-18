# Зависимости MVP

Версии зафиксированы 18 августа 2026 года.

| Пакет | Версия | Лицензия | Назначение |
|---|---:|---|---|
| `subtitle` | 0.2.0 | MIT | Низкоуровневый разбор SRT и WebVTT |
| `file_selector` | 1.1.0 | BSD-3-Clause | Android system document picker |
| `wakelock_plus` | 1.7.0 | BSD-3-Clause | Wake lock на player screen |
| `shared_preferences` | 2.5.5 | BSD-3-Clause | Локальные настройки playback |

`subtitle` используется только через `SubtitlePackageAdapter`. Его
`SubtitleController` не используется, потому что удаляет cues с одинаковым
диапазоном и применяет закрытую правую границу. Application-owned
`SubtitleTimeline` сохраняет каждый cue и использует `[start, end)`.

`file_selector` на Android копирует выбранный документ во временный app cache.
Сохранённый `XFile.path` может стать недоступным после очистки cache; повторное
открытие поэтому всегда обрабатывается как fallible operation.
