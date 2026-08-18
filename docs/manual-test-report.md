# Android manual test report

Дата: 18 августа 2026 года.

Устройство: Samsung SM-S918B, Android 16 / API 36, `android-arm64`.

## Выполнено

- Debug APK собран, установлен через ADB и запущен на физическом устройстве.
- Android system document picker открыл реальный локальный SRT без storage permission.
- Exact timestamp jump установил позицию `0:00:16.000`.
- Fixture с диапазонами `10-20s` и `15-18s` показал оба cue в `16s`.
- В `19s` остался только длинный cue `10-20s`.
- Rate control изменил значение на `1.001x` без изменения текущей позиции.
- Delay control изменил значение на `+0.1s` независимо от movie position.
- После HOME в `10.703s` приложение вернулось на pause с той же позицией.
- Android `mHoldScreenWindow` указывает на `MainActivity` на player screen.
- Сохранённая cache reference повторно открывается; недоступность reference
  обрабатывается как ошибка на open screen.

## Осталось для cinema field test

- Проверка синхронизации с реальным фильмом в течение минимум 10 минут.
- Наблюдение и ручная коррекция намеренного progressive drift.
- Визуальная проверка нескольких очень длинных multiline cues при низкой яркости.

Эти сценарии требуют реального фильма и субъективной проверки читаемости, поэтому
не заменяются unit/widget tests или короткой device automation.

## Favorites и focus mode

Автоматическая проверка change `add-favorites-and-focus-mode`:

- полный набор из 89 tests прошёл;
- debug и release APK собраны;
- release APK не запрашивает `INTERNET` или broad storage permissions;
- repository tests покрывают private SRT/VTT copies, restart, SHA-256 deduplication,
  atomic metadata recovery, cleanup queue, missing/damaged copies и disk failures;
- widget tests покрывают add/open/remove, broken entry cleanup, focus hide/show,
  multiple/long cues, неизменные rate/delay/position и compact Android width.

Повторная ручная проверка выполнена на Samsung SM-S918B:

- свежий debug APK установлен через ADB с сохранением app data;
- реальный SRT добавлен в избранное и сохранён отдельной SHA-256 private copy;
- исходный файл удалён из picker cache, после force-stop/restart запись осталась
  на главном экране и успешно открылась из `files/favorites/`;
- playback продолжился во время hide/show controls, после возврата сохранились
  position `0:00:37.728`, rate `1.000x` и delay `+0.0s`;
- device fixture в `0:00:16.000` одновременно показал длинный multiline cue и
  два независимых overlapping cues с одинаковым start time;
- при скрытых controls весь текст остался в полноэкранной subtitle area, а один
  тап вернул меню на той же позиции;
- временный device fixture удалён штатной командой Remove, пользовательская
  private copy осталась нетронутой.
