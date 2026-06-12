# Переезд в другую IDE / новую машину

> Проект самодостаточен: вся правда в репозитории + один файл секретов `backend/.env`.
> «Открыть папку» — да, этого почти достаточно. Ниже — что должно стоять в системе
> и какие расширения поставить.

## Что должно быть установлено в системе (не зависит от IDE)
| Инструмент | Зачем | Проверка |
|---|---|---|
| **Flutter SDK** (3.x, канал stable) | приложение | `flutter doctor` |
| **Node.js 22+** и npm | бэкенд | `node -v` |
| **Android Studio + Android SDK** | сборка под Android (нужен только SDK + эмулятор/телефон; сама студия как IDE не обязательна) | `flutter doctor` покажет |
| **Git** | репозиторий | `git -v` |
| (опц.) JDK ставится вместе с Android Studio | Gradle | — |

## Первый запуск на новом месте
```powershell
git clone <репозиторий> ; cd glavnoe

# Бэкенд
cd backend
npm install
# положить backend/.env (его НЕТ в git — перенести вручную!):
#   DATABASE_URL=postgresql://...  (Neon)
#   GEMINI_API_KEY=...   JWT_SECRET=...   PORT=3000
npm run dev          # сервер на :3000, проверка: http://localhost:3000/health

# Приложение
cd ../app
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # генерация Drift
flutter run -d windows|chrome|<device>
# На телефоне: ../scripts/run-phone.ps1 (подставит IP ПК вместо localhost)

# Тесты
cd ../backend ; npx jest          # 80 тестов бэкенда
cd ../app ; flutter test          # 119 тестов приложения
```

⚠️ Единственное, что НЕ переедет через git: **`backend/.env`** (секреты) и
локальные базы. Скопируй .env вручную или заведи новые ключи.

## Расширения по IDE

### VS Code (рекомендую — текущая конфигурация уже в .vscode/)
- **Flutter** (Dart-Code.flutter) — автоматически тянет **Dart**
- **Prisma** (Prisma.prisma) — подсветка schema.prisma
- (опц.) **ESLint**, **YAML** (для api-spec.yaml), **GitLens**

### Android Studio / IntelliJ
- Плагины **Flutter** + **Dart** (Settings → Plugins)
- Бэкенд удобнее держать в отдельном окне VS Code или WebStorm

### Cursor / Windsurf / другие VS Code-форки
- Те же расширения, что VS Code (маркетплейс совместим)

## Промт для продолжения работы с AI в новой среде
Скопируй это первым сообщением новой AI-сессии (Claude Code, Cursor и т.п.):

```
Ты — оркестратор проекта Kaizen («Главное») в этом репозитории.
Прочитай в таком порядке: CLAUDE.md → AGENTS.md → docs/BOARD.md →
docs/AUDIT.md → docs/PROJECT-MAP.md. Правила: .claude/rules/rules.md.
Статус: MVP+Ф1+Ф2 закрыты, Ф3-шеринг и цели сделаны; текущий бэклог —
секция «Ревью 2026-06-11» в BOARD.md (баги/новые функции/co-study).
Контракты (docs/api-spec.yaml, data-model.md, design-tokens.json,
ANIMATIONS.md) не менять без ADR в docs/decisions.md. Тесты держать
зелёными: backend `npx jest` (80), app `flutter analyze` + `flutter test`
(119). Коммить после каждого блока. Работай по бэклогу сверху вниз,
вопросы — только когда реально блокирован.
```

## Что ещё может понадобиться
- **Телефон по USB** + включённая отладка — для проверки камеры/микрофона/уведомлений.
- **Доступ к Neon** (база) — миграции применяются `npx prisma migrate deploy` из backend/.
- Перед публикацией: аккаунты Google Play / App Store (OAuth, RevenueCat, ссылки лендинга).
