# VocalSegments — iOS-версия

Приложение для вокалистов: открываете аудио/видео, выделяете сегмент на волне,
записываете свой голос на этот сегмент и сравниваете с оригиналом.

## Структура

- `Sources/` — весь код (SwiftUI, без сторонних зависимостей)
- `project.yml` — конфиг XcodeGen (генерирует Xcode-проект при сборке)
- `codemagic.yaml` — сценарий облачной сборки: собирает неподписанный `VocalSegments.ipa`

## Сборка (Codemagic)

1. Загрузите репозиторий на GitHub.
2. В Codemagic: Add application → GitHub → выберите репозиторий.
   Codemagic сам найдёт `codemagic.yaml` (workflow **iOS unsigned IPA**).
3. Запустите сборку. Артефакт: `build/VocalSegments.ipa`.

## Установка на iPhone (Sideloadly, Windows)

1. Скачайте Sideloadly (sideloadly.io), установите.
2. Подключите iPhone кабелем, разблокируйте.
3. Перетащите `VocalSegments.ipa` в Sideloadly, введите Apple ID, Start.
4. На iPhone: Настройки → Основные → VPN и управление устройством → доверять разработчику.

Ограничение бесплатного Apple ID: подпись действует 7 дней, затем повторите шаг 3
(данные и проекты внутри приложения сохраняются при перевыпуске с тем же Apple ID).
