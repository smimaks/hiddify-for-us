# Сборка Android с рабочим VPN (подключение с телефона)

Если с ПК подключение к подписке работает (в логах Marzban видны запросы), а с телефона — «Таймаут» и в Marzban нет логов, значит на телефоне в конфиг не попадает TUN inbound (туннель не поднимается).

**Причина:** готовый AAR с GitHub (при `make android-libs`) не содержит методов `Parse` и `BuildConfig`. Конфиг собирается только из outbounds, без TUN, трафик через прокси не идёт.

**Решение:** собрать нативные библиотеки локально и подложить свой AAR.

## Шаги

1. Установить Go и gomobile (см. libcore/Makefile, цель `lib_install`):
   ```bash
   go install -v github.com/sagernet/gomobile/cmd/gomobile@v0.1.1
   go install -v github.com/sagernet/gomobile/cmd/gobind@v0.1.1
   ```

2. Собрать AAR с пакетом `com.hiddify.core` (Parse + BuildConfig):
   ```bash
   make build-android-libs
   ```
   AAR окажется в `android/app/libs/`.

3. Собрать APK:
   ```bash
   flutter build apk --split-per-abi
   ```

4. Ставить на телефон `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.

После этого при подключении с телефона конфиг будет полным (с TUN), трафик пойдёт через прокси и появится в логах Marzban.
