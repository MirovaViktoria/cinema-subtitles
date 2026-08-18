# Разработка Cinema Subtitles

## Процесс

1. Для нового поведения создайте или обновите OpenSpec change.
2. Согласуйте `proposal.md`, delta specs, `design.md` и `tasks.md` до реализации.
3. Реализуйте задачи небольшими проверяемыми шагами.
4. Добавьте unit/widget tests для каждого изменения поведения.
5. Запустите локальный quality gate перед pull request.

Исправление очевидной опечатки или внутренняя реорганизация без изменения
поведения не требуют отдельного OpenSpec change.

## Quality gate

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
openspec validate --all --strict --no-interactive
```

## Правила реализации

- Domain-логика времени и timeline не должна импортировать Flutter widgets.
- Сторонние типы парсера не должны выходить за пределы adapter layer.
- UI timer может запрашивать новое состояние, но не должен увеличивать позицию.
- Активность cue определяется полуинтервалом `start <= time < end`.
- Любой момент времени может иметь ноль, один или несколько активных cues.
- Seek, subtitle delay и playback rate должны оставаться независимыми.
- MVP не должен требовать сеть или широкие разрешения файловой системы.

## Pull request

В описании PR укажите OpenSpec change, пользовательский результат, выполненные
проверки и оставшиеся ограничения. Не смешивайте несвязанные изменения.
