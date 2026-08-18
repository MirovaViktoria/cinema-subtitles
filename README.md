# Cinema Subtitles

Android-first офлайн-приложение для показа локальных субтитров во время
просмотра фильма. Приложение работает как независимые часы субтитров и не
воспроизводит видео или аудио.

## Статус

Проект инициализирован. Реализация MVP описана в OpenSpec change
`openspec/changes/mvp-subtitle-clock/`.

## Стек

- Flutter 3.47.0 / Dart 3.13.0
- Android как первая целевая платформа
- OpenSpec для spec-driven разработки
- GitHub Actions для format, analyze, test и проверки OpenSpec

## Подготовка окружения

Установите:

- [Flutter SDK](https://docs.flutter.dev/get-started/install/windows/mobile)
- Android Studio с Android SDK и эмулятором либо подключённым устройством
- Node.js 20.19+ и `@fission-ai/openspec`

```powershell
npm install -g @fission-ai/openspec@1.9.0
flutter doctor
flutter pub get
```

## Запуск

```powershell
flutter run
```

## Проверки

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
openspec validate --all --strict --no-interactive
```

## OpenSpec workflow

Команды OpenSpec CLI выполняются в терминале, а `/opsx-*` — в чате OpenCode.
Артефакты по умолчанию пишутся на русском языке.

```text
/opsx-explore
/opsx-propose "описание изменения"
/opsx-apply
/opsx-sync
/opsx-archive
```

## Документация

- [`01-product-requirements.md`](01-product-requirements.md) — продуктовые требования
- [`02-architecture.md`](02-architecture.md) — архитектура
- [`03-implementation-and-tests.md`](03-implementation-and-tests.md) — этапы и тест-план
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — процесс разработки
