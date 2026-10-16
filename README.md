# Таро дня

Мобильное приложение для Android (Flutter): карта дня, расклады, коллекция
карт, заметки, фаза луны и натальная карта. Опубликовано в RuStore.

## Лицензия

Исходный код распространяется под лицензией **GNU AGPL-3.0** (см. файл
`LICENSE`). Причина: для расчёта положения планет используется
[Swiss Ephemeris](https://www.astro.com/swisseph/) (Astrodienst AG) через
пакет [`sweph`](https://pub.dev/packages/sweph), которые распространяются
под AGPL. Вы можете изучать, изменять и распространять этот код на условиях
AGPL-3.0.

Приложение также использует Yandex Mobile Ads SDK (рекламу), которое
распространяется на собственных условиях Яндекса и не входит в этот
репозиторий.

## Сборка

Сборка выполняется в Codemagic по файлу `codemagic.yaml`. Для подписи
релиза нужен собственный ключ: он загружается в раздел Code signing
identities в Codemagic под именем `tarot_dnya_keystore` и в репозиторий
не попадает.

Локально: `flutter pub get`, затем `flutter run`. Для рекламы в
`lib/services/ads_service.dart` и `AndroidManifest.xml` нужно подставить
свои идентификаторы Yandex Ads.

## Политика конфиденциальности

https://galimych.github.io/tarot-dnya-legal/
