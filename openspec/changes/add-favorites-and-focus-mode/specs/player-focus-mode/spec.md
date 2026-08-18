## Purpose

Focus mode освобождает экран для текста субтитров, скрывая отвлекающие controls
без изменения позиции фильма, синхронизации или активных cues.

## ADDED Requirements

### Requirement: Явное скрытие player controls

Система SHALL предоставлять на player screen кнопку, которая скрывает header,
timestamp, rate/delay readout, playback controls и synchronization controls.

#### Scenario: Пользователь скрывает меню

- **GIVEN** player controls видимы
- **WHEN** пользователь нажимает кнопку скрытия меню
- **THEN** все player controls исчезают
- **THEN** subtitle area занимает освобождённое пространство

#### Scenario: Скрытие во время playback

- **GIVEN** playback запущен на определённой позиции, rate и subtitle delay
- **WHEN** пользователь скрывает controls
- **THEN** playback продолжает идти без скачка позиции
- **THEN** rate, subtitle delay и active cues не изменяются

### Requirement: Восстановление controls тапом

Система SHALL возвращать скрытые controls после одного тапа по subtitle area.

#### Scenario: Пользователь возвращает меню

- **GIVEN** player controls скрыты
- **WHEN** пользователь один раз нажимает на subtitle area
- **THEN** все player controls снова отображаются
- **THEN** playback state и synchronization state сохраняются

### Requirement: Субтитры остаются доступными в focus mode

Система SHALL продолжать отображать все active cues и применять правила layout
для длинного текста, пока controls скрыты.

#### Scenario: Overlapping cues при скрытом меню

- **GIVEN** несколько cues активны одновременно и player controls скрыты
- **WHEN** player screen обновляет состояние
- **THEN** все active cues остаются видимыми независимо друг от друга

#### Scenario: Длинный текст при скрытом меню

- **GIVEN** длинный текст не помещается с выбранным font size
- **WHEN** controls скрыты и subtitle area выполняет layout
- **THEN** применяются те же minimum font size и scrolling fallback, что и при видимом меню

### Requirement: Начальное состояние focus mode

Система SHALL открывать каждый новый player screen с видимыми controls и не
должна сохранять hidden state между сессиями.

#### Scenario: Повторное открытие player screen

- **GIVEN** пользователь покинул player screen со скрытыми controls
- **WHEN** пользователь снова открывает файл субтитров
- **THEN** новый player screen показывает controls
