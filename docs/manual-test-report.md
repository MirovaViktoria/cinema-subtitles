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
