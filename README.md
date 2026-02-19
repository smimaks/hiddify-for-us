# Для Своих

Форк [Hiddify](https://github.com/hiddify/hiddify-app) для **безопасного и удобного использования всеми русскоязычными пользователями**. Открытый исходный код, без скрытой телеметрии и без отправки данных на сторонние сервера.

---

## Что это за приложение

**Для Своих** — кроссплатформенный прокси/VPN-клиент на движке [Sing-box](https://github.com/SagerNet/sing-box). По сути это универсальный фронтенд для настройки и использования прокси: подписки по ссылке, выбор узлов по задержке, режим TUN, поддержка популярных протоколов и форматов конфигов.

- **Платформы:** Android, Windows, Linux (сборка только под эти ОС).
- **Без рекламы**, без встроенной аналитики и краш-репортов в облако (Sentry и прочее удалены).
- Подходит для безопасного и приватного доступа в интернет при использовании своих или доверенных подписок.

---

## Основные возможности

- Подключение по подписке (ссылка или конфиг): Sing-box, V2ray, Clash, Clash Meta.
- Протоколы: VLESS, VMess, Reality, TUIC, Hysteria, WireGuard, SSH и др.
- Автовыбор узла по задержке, ручной выбор прокси.
- Режим TUN (системный VPN на Android), режим системного прокси (Windows, Linux).
- Автообновление подписок, отображение срока и трафика по профилю.
- Тёмная и светлая темы, русский интерфейс.
- Совместимость с типичными панелями прокси.

---

## Скачать

Сборки только для **Android**, **Windows** и **Linux**:

| Платформа | Ссылка |
|-----------|--------|
| **Android** | [Releases](https://github.com/smimaks/hiddify-or-us/releases) — APK (универсальный) |
| **Windows** | [Releases](https://github.com/smimaks/hiddify-or-us/releases) — exe / msix |
| **Linux** | [Releases](https://github.com/smimaks/hiddify-or-us/releases) — AppImage, deb, rpm |

Конкретные файлы смотри в [релизах репозитория](https://github.com/smimaks/hiddify-or-us/releases).

---

## Сборка из исходников

- **Android:** `flutter pub get && make android-libs && flutter build apk --release`  
  APK: `build/app/outputs/flutter-apk/app-release.apk`
- **Linux:** `make linux-prepare && make linux-release`  
  Пакеты в `dist/` (deb, rpm, AppImage).
- **Windows:** `make windows-prepare && make windows-release`  
  exe/msix в `dist/`.

Нужны: Flutter 3.24.x, Dart 3.3+, для Android — NDK и JDK 17, для Linux — зависимости из `make linux-install-dependencies`.

---

## О форке и безопасности

Этот форк сделан так, чтобы приложение можно было **безопасно использовать всем русскоязычным пользователям**:

- Убрана отправка логов и крашей в Sentry и любые другие сторонние сервисы аналитики.
- Проверка обновлений идёт только на GitHub этого репозитория (по желанию).
- Исходный код открыт: можно проверить, что именно делает приложение и под чьим контролем находятся обновления.

Оригинальный проект: [Hiddify](https://github.com/hiddify/hiddify-app). Ядро: [Sing-box](https://github.com/SagerNet/sing-box).

---

## Лицензия

См. [LICENSE.md](LICENSE.md).
