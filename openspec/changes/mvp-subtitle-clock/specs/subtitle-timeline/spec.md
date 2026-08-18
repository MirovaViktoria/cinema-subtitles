## ADDED Requirements

### Requirement: Полуоткрытый интервал активности

Система SHALL считать cue активным только когда `cue.start <= time < cue.end`.

#### Scenario: Точные границы cue

- **GIVEN** cue начинается в 10.000 seconds и заканчивается в 15.000 seconds
- **WHEN** timeline запрашивается в 10.000, 14.999 и 15.000 seconds
- **THEN** cue активен в первых двух моментах и не активен в 15.000 seconds

### Requirement: Несколько одновременно активных cues

Система SHALL возвращать все cues, активные в запрошенный момент, и не должна
предполагать наличие единственного current cue.

#### Scenario: Пересекающиеся cues

- **GIVEN** cue A активен с 10 до 20 seconds, а cue B с 15 до 18 seconds
- **WHEN** timeline запрашивается в 16 seconds
- **THEN** результат содержит A и B

#### Scenario: Одинаковый временной диапазон

- **GIVEN** два независимых cues имеют одинаковый диапазон с 10 до 15 seconds
- **WHEN** timeline запрашивается в 11 seconds
- **THEN** результат содержит оба cues

### Requirement: Сохранение длинного cue

Система SHALL сохранять длинный cue активным до его собственного end независимо
от начала или завершения вложенных cues.

#### Scenario: Короткий cue внутри длинного

- **GIVEN** cue A активен с 10 до 60 seconds, а cue B с 24 до 27 seconds
- **WHEN** timeline запрашивается в 30 seconds
- **THEN** результат содержит A и не содержит B

### Requirement: Навигация не зависит от истории playback

Система SHALL вычислять active, previous, next и nearby cues из timeline для
любого переданного момента времени.

#### Scenario: Произвольный seek внутрь cue

- **GIVEN** playback находился в 5 seconds и cue активен в 17 seconds
- **WHEN** пользователь выполняет seek непосредственно в 17 seconds
- **THEN** cue отображается при следующем вычислении состояния

#### Scenario: Seek назад внутрь завершившегося cue

- **GIVEN** playback находится после end cue
- **WHEN** пользователь выполняет seek назад внутрь диапазона cue
- **THEN** cue снова отображается немедленно
