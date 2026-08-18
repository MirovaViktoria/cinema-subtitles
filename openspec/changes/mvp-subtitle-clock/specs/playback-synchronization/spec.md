## ADDED Requirements

### Requirement: Монотонные anchor-based часы

Система SHALL вычислять playback position из anchor position, монотонного elapsed
time и playback rate, не накапливая периодические UI timer ticks.

#### Scenario: Пропущенный UI refresh

- **GIVEN** playback запущен с позиции 30 seconds при rate 1.000x
- **WHEN** UI не обновляется 5 real seconds, а затем запрашивает позицию
- **THEN** рассчитанная позиция равна примерно 35 seconds

#### Scenario: Pause фиксирует позицию

- **GIVEN** playback поставлен на pause
- **WHEN** проходит произвольное real time
- **THEN** playback position не изменяется

### Requirement: Seek сохраняет состояние playback

Система SHALL немедленно менять playback position при absolute или relative seek
и сохранять предыдущее состояние play/pause.

#### Scenario: Seek во время playback

- **GIVEN** playback запущен
- **WHEN** пользователь выполняет seek на 10 seconds вперёд
- **THEN** позиция сдвигается на 10 seconds и playback продолжает идти

#### Scenario: Seek на pause

- **GIVEN** playback находится на pause
- **WHEN** пользователь задаёт точный timestamp
- **THEN** позиция меняется на этот timestamp и остаётся на pause

### Requirement: Изменение playback rate без скачка

Система SHALL поддерживать точную регулировку rate с шагом 0.001x и не должна
немедленно менять текущую позицию при установке нового rate.

#### Scenario: Смена rate во время playback

- **GIVEN** playback идёт при rate 1.010x
- **WHEN** rate меняется на 0.990x
- **THEN** позиции непосредственно до и после изменения практически равны
- **THEN** только последующее продвижение использует rate 0.990x

### Requirement: Независимый subtitle delay

Система SHALL применять delay только к времени timeline lookup по формуле
`lookupTime = playbackPosition - subtitleDelay`.

#### Scenario: Положительный delay

- **GIVEN** playback position равна 20 seconds и delay равен +2 seconds
- **WHEN** система запрашивает активные cues
- **THEN** timeline lookup time равен 18 seconds
- **THEN** playback position остаётся равной 20 seconds

### Requirement: Быстрая синхронизация по cue

Система SHALL позволять выбрать nearby cue и синхронизировать playback position
с его start, сохраняя состояние play/pause.

#### Scenario: Sync here во время playback

- **GIVEN** playback запущен и пользователь выбрал cue со start 42 seconds
- **WHEN** пользователь выполняет `Sync here`
- **THEN** playback position становится равной 42 seconds и playback продолжается
