## ADDED Requirements

### Requirement: OLED-интерфейс проигрывателя

Система SHALL по умолчанию показывать белый текст субтитров на чёрном фоне с
минимумом отвлекающих элементов и крупными touch targets.

#### Scenario: Открытие корректного файла

- **WHEN** пользователь успешно открывает файл субтитров
- **THEN** player screen показывает позицию, subtitle area, rate, delay и основные controls

### Requirement: Отображение всех активных cues

Система SHALL отображать каждый active cue независимо, сохраняя весь текст и
стабильный порядок по start time и source index.

#### Scenario: Несколько активных cues

- **GIVEN** timeline возвращает три одновременно активных cues
- **WHEN** player screen обновляется
- **THEN** текст всех трёх cues присутствует на экране

#### Scenario: Длинный текст не помещается

- **GIVEN** active cues не помещаются с выбранным font size
- **WHEN** renderer выполняет layout
- **THEN** renderer уменьшает размер до безопасного минимума до использования scrolling
- **THEN** ни один cue не удаляется молча

### Requirement: Управление размером текста

Система SHALL позволять пользователю увеличить или уменьшить font size субтитров.

#### Scenario: Увеличение текста

- **WHEN** пользователь нажимает control увеличения font size
- **THEN** последующий render использует увеличенный размер и сохраняет настройку локально

### Requirement: Wake lock ограничен player screen

Система SHALL удерживать экран включённым только пока player screen активен.

#### Scenario: Переход на player screen

- **WHEN** player screen становится активным
- **THEN** система включает wake lock

#### Scenario: Выход с player screen

- **WHEN** пользователь покидает player screen
- **THEN** система выключает wake lock

### Requirement: Безопасный Android lifecycle

Система SHALL ставить playback на pause и сохранять доступное состояние, когда
приложение перестаёт быть active.

#### Scenario: Приложение уходит в background

- **GIVEN** playback запущен
- **WHEN** Android переводит приложение в background
- **THEN** playback останавливается на актуальной позиции
- **THEN** position, delay, rate, font size и OLED setting сохраняются локально

#### Scenario: Сохранённый URI недоступен

- **GIVEN** Android отозвал доступ к ранее выбранному файлу
- **WHEN** приложение восстанавливает состояние
- **THEN** система предлагает выбрать файл снова без аварийного завершения
