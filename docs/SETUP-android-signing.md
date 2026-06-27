# Android release signing — Kaizen

> Настроено 2026-06-27. Подпись релизной сборки реальным upload-ключом (не debug).
> ⚠️ Пароль keystore в этот файл НЕ записан и в git НЕ хранится — он только у владельца.

## Что где лежит

| Что | Путь | В git? |
|-----|------|--------|
| Keystore (ключ) | `app/android/upload-keystore.jks` | ❌ нет (`.gitignore`) |
| Пароль + алиас | `app/android/key.properties` | ❌ нет (`.gitignore`) |
| Конфиг подписи | `app/android/app/build.gradle.kts` | ✅ да |

- **Алиас ключа:** `upload`
- **Алгоритм:** RSA 2048, срок действия до **2053-11-12** (10000 дней)
- **SHA-1:** `6E:6F:54:60:5A:CC:DD:08:16:53:7A:19:03:35:45:D9:4B:EE:15:BB`
- **SHA-256:** `8A:29:E0:7F:BD:59:54:CD:C6:F7:96:A8:BE:CC:55:75:84:18:4F:E8:91:A7:A6:CF:FA:24:A9:39:97:A8:DC:6C`

## 🔴 Критично: бэкап ключа

Если потерять `upload-keystore.jks` ИЛИ пароль — **обновлять приложение в магазине станет невозможно навсегда**
(придётся публиковать как новое приложение, теряя пользователей/отзывы). Поэтому:

1. Скопировать `app/android/upload-keystore.jks` в **2–3 надёжных места** (облако/менеджер паролей/флешка).
2. Пароль хранить в **менеджере паролей** (не в репозитории, не в этом файле).
3. Никому не передавать и не коммитить.

## Как собрать подписанный релиз

```bash
cd app
flutter build apk --release         # APK (для RuStore / прямой раздачи)
flutter build appbundle --release   # AAB (для Google Play)
```
Результат:
- APK → `app/build/app/outputs/flutter-apk/app-release.apk`
- AAB → `app/build/app/outputs/bundle/release/app-release.aab`

## Как проверить, что подпись реальная (не debug)

```bash
# отпечаток собранного APK должен совпасть с SHA-256 выше
keytool -printcert -jarfile app/build/app/outputs/flutter-apk/app-release.apk
```
Если SHA-256 совпадает с указанным — подпись наша, всё верно.

## Восстановление key.properties (если потерялся, но keystore цел)

`app/android/key.properties`:
```
storePassword=<пароль>
keyPassword=<тот же пароль>
keyAlias=upload
storeFile=../upload-keystore.jks
```
