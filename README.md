# AniLiberty
iOS клиент для сайта [AniLiberty](https://aniliberty.top)

## Информация
|Версия приложения |iOS/iPad.           |macOS                 |
|------------------|--------------------|----------------------|
| 1.0.1..<1.1.4    | iOS 11.2 и новее   | macOS 10.15 и новее  | 
| 1.2.0...         | iOS 13.0 и новее   | macOS 11 и новее     |
| сборка в Xcode 27 | iOS 15.0 и новее  | macOS 12 и новее     |


## Установка
Приложение вы можете собрать самостоятельно, либо скачать посдедний релиз [отсюда](https://github.com/anilibria/anilibria-ios/releases).

Установить ipa на ваш девайс вы можете c помощью AltStore
  - Офф сайт: [altstore.io](https://altstore.io/)

Другие способы можете поискать в интернете.

## tvOS
Приложение для Apple TV (tvOS 17.0 и новее) собирается из того же проекта: цель `AniLibertyTV`, код экранов лежит в папке `AniLibertyTV`. Сетевой слой, модели и логика плеера общие с iOS.

Сборка для симулятора. Сертификат разработчика не нужен: такую сборку Xcode подписывает локально.

```sh
xcodebuild -project Anilibria.xcodeproj -scheme AniLibertyTV -destination 'generic/platform=tvOS Simulator' build
```

Так же собирается iOS-приложение:

```sh
xcodebuild -project Anilibria.xcodeproj -scheme AniLiberty -destination 'generic/platform=iOS Simulator' build
```

Не отключайте подпись (`CODE_SIGNING_ALLOWED=NO`) в сборке, которую будете запускать: без подписи приложение не получает доступа к связке ключей, где хранится токен входа.

Чтобы установить приложение на Apple TV, откройте проект в Xcode, выберите схему `AniLibertyTV` и запустите её на приставке. Проверить, что приложение компилируется для приставки, можно без сертификата:

```sh
xcodebuild -project Anilibria.xcodeproj -scheme AniLibertyTV -destination 'generic/platform=tvOS' CODE_SIGNING_ALLOWED=NO build
```

## Планы на будущее
- ~~Адаптация интерфейса для iPad~~.
- ~~Темная тема~~.
- Скачивание сериалов через торрент.

# Лицензия #
Исходный код распостраняется под лицензией GPL v3

> Copyright (C) 2020 [Ivan Morozov](https://github.com/Allui)
> 
> This program is free software; you can redistribute it and/or modify
> it under the terms of the GNU General Public License as published by
> the Free Software Foundation; either version 3 of the License.
