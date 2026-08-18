# Cinema Subtitles

Android-first офлайн-приложение для показа локальных субтитров во время
просмотра фильма. Приложение работает как независимые часы субтитров и не
воспроизводит видео или аудио.

## Статус

Первый MVP реализован в OpenSpec change
`openspec/changes/mvp-subtitle-clock/`. Приложение открывает локальные SRT и
WebVTT, ведёт независимые часы и работает без сети.

Поддерживается:

- одновременное отображение нескольких overlapping cues;
- play/pause и seek на `-10`, `-1`, `+1`, `+10` секунд;
- переход к точному timestamp;
- playback rate с шагом `0.001x` без скачка позиции;
- независимый subtitle delay;
- previous/next cue и nearby browser с `Sync here`;
- изменение font size и OLED mode;
- постоянное избранное с приватными offline-копиями SRT/WebVTT;
- focus mode: скрытие controls и возврат одним тапом по subtitle area;
- pause при уходе приложения в background;
- сохранение позиции и настроек;
- wake lock только на player screen.

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
flutter devices
flutter run -d <device-id>
```

На стартовом экране выберите UTF-8 файл `.srt` или `.vtt`. Android system
document picker не требует широкого разрешения на доступ к хранилищу.

Звезда на player screen сохраняет приватную копию файла в избранное. Список на
стартовом экране доступен после перезапуска и не зависит от picker cache. Кнопка
fullscreen скрывает controls; один тап по области субтитров возвращает их.

Нажатие на timestamp открывает точный переход в формате `H:MM:SS.mmm`.
Позиция фильма, subtitle delay и playback rate изменяются независимо.

## Android build

```powershell
flutter build apk --debug
flutter build apk --release
```

APK создаются в `build/app/outputs/flutter-apk/`.

## Проверки

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --coverage
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
- [`docs/dependencies.md`](docs/dependencies.md) — версии и лицензии зависимостей
- [`docs/manual-test-report.md`](docs/manual-test-report.md) — Android test report
