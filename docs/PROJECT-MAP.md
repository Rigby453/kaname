# Карта проекта Kaizen («Главное») — что где лежит и зачем

> Обновлено 2026-06-18 (карта документации). Один файл — одна строка. Генерированные файлы (`*.g.dart`,
> `package-lock.json`, `pubspec.lock`) не описываются: их создают инструменты,
> руками не править. Структура: 4 продукта в одном репо — бэкенд (backend/),
> приложение (app/), лендинг (landing/), тесты бэкенда (tests/) + документация (docs/).

## Корень
| Файл | Зачем |
|---|---|
| `CLAUDE.md` | Входная точка для AI-сессий: что за продукт, фазы, глобальные правила |
| `AGENTS.md` | Оркестрация: роли агентов, порядок сборки MVP, точки синхронизации |
| `.gitignore` | Исключения git: секреты (.env), node_modules, сборки, coverage |
| `scripts/run-phone.ps1` | Запуск приложения на телефоне: находит LAN-IP ПК и подставляет его как API_BASE_URL |

## docs/ — документация (источники истины)
| Файл | Зачем |
|---|---|
| `SPEC.md` | Полное продуктовое ТЗ по разделам C1–C8 и фазам MVP/Ф1/Ф2/Ф3 |
| `api-spec.yaml` | Контракт API (OpenAPI 3.0) — все эндпоинты, поля snake_case; бэкенд и клиент обязаны совпадать с ним |
| `data-model.md` | Схема БД (+Prisma) — имена таблиц/колонок |
| `design-tokens.json` | Цвета/шрифты/отступы/радиусы всех 5 тем + зеркало таймингов анимаций |
| `ANIMATIONS.md` | ТЗ на все анимации: длительности (120–300мс), кривые, поэлементно. Источник истины по моушену |
| `decisions.md` | ADR-журнал: 30 архитектурных решений с обоснованиями (почему Gemini, почему JWT-шеринг и т.д.) |
| `STATUS.md` | Статус: сводка (готово/осталось/баги/нужна помощь) + журнал работ по блокам |
| `PROJECT-MAP.md` | Этот файл |
| `SETUP-IDE.md` | Как открыть проект в другой IDE: SDK, расширения, команды, промт продолжения |
| `agents/ai-tasks.md` | Описания AI-промптов/эндпоинтов (Ф1+). MVP-чеклисты backend/flutter/qa убраны — статус в `STATUS.md` |

## backend/ — сервер (Node 22 + Fastify 4 + Prisma 5 + PostgreSQL/Neon)
| Файл | Зачем |
|---|---|
| `package.json` | Зависимости и скрипты: `npm run dev` (tsx watch), `build`, `start` |
| `tsconfig.json` | TypeScript: Node16-модули, strict |
| `jest.config.js` / `jest.setup.ts` | Конфиг тестов: грузит .env, ts-jest |
| `.env` | Секреты (НЕ в git): DATABASE_URL, GEMINI_API_KEY, JWT_SECRET |
| `CLAUDE.md` | Правила backend-агента: порядок эндпоинтов, HTTP-коды, запреты |
| `prisma/schema.prisma` | Модели БД: User, Item, Streak, WaterLog, DayLog, FoodLog, Tombstone |
| `prisma/migrations/*` | SQL-миграции (применяются `npx prisma migrate deploy`) |
| `src/index.ts` | Точка входа: поднимает сервер на PORT |
| `src/app.ts` | Сборка Fastify: CORS, JWT, регистрация всех роутов, /health |
| `src/routes/auth.ts` | Регистрация / вход / `GET /me` (bcrypt + JWT 30 дней) |
| `src/routes/items.ts` | CRUD задач + проверка владельца (404 для чужих) |
| `src/routes/streaks.ts` | Текущая серия пользователя |
| `src/routes/sync.ts` | Дельта-синхронизация: items (LWW), water/food (append-only), day_logs, удаления через tombstones |
| `src/routes/redistribute.ts` | Бесплатное rule-перераспределение (предложения, ничего не сохраняет) |
| `src/routes/ai.ts` | Все AI-эндпоинты (premium-гейт): расписание с фото, утреннее сообщение, умный план, инсайт дневника, еда по фото (3/день), wrapped-абзац, сборка меню |
| `src/routes/food.ts` | Поиск продуктов и штрихкод через Open Food Facts |
| `src/routes/share.ts` | Веб-шеринг плана: создание JWT-ссылки + публичная HTML/JSON-страница |
| `src/routes/subscription.ts` | Dev-переключение тарифа (только не-production) — пока нет RevenueCat |
| `src/routes/middleware/auth.ts` | requireAuth: проверка Bearer-токена |
| `src/engine/redistributor.ts` | Правиловой движок: слоты 30 мин 08:00–22:00, приоритеты, protected не трогаем |
| `src/engine/streaks.ts` | Серверный пересчёт стрика (зеркало клиентской логики) |
| `src/ai/provider.ts` | Абстракция AI: Gemini или Claude по ключу в .env — ЕДИНСТВЕННОЕ место вызова моделей |
| `src/ai/scheduleImport.ts` | Фото расписания → список пар (multimodal) |
| `src/ai/morningMessage.ts` | Tone-aware утреннее сообщение |
| `src/ai/smartRedistribute.ts` | Умное перераспределение: 2–3 варианта плана |
| `src/ai/diaryInsight.ts` | Инсайт по 7 дням дневника |
| `src/ai/foodRecognize.ts` | Фото еды → название блюда (числа НЕ от модели) |
| `src/ai/wrappedSummary.ts` | Недельный итог одним абзацем |
| `src/ai/menuBuild.ts` | «Собрать ИИ»: меню дня из продуктов пользователя (модель выбирает, числа считает код) |
| `src/food/openFoodFacts.ts` | HTTP-клиент Open Food Facts (поиск + штрихкод) |
| `src/models/*.ts` | Сериализаторы моделей в snake_case ответы (user, item, streak, waterLog, dayLog, foodLog, prisma-клиент) |
| `src/types/fastify-jwt.d.ts` | Типы JWT-полей для TypeScript |

## tests/ — интеграционные и юнит-тесты бэкенда (Jest, 80 шт.)
| Файл | Зачем |
|---|---|
| `CLAUDE.md` | Правила QA: мокать AI, не звать реальные API |
| `helpers/index.ts` | registerUser/cleanupUser — общие помощники |
| `integration/auth.test.ts` | Регистрация/вход/JWT/дубликаты |
| `integration/items.test.ts` | CRUD + владелец |
| `integration/sync.test.ts` | LWW, append-only, удаления, last_sync_at |
| `integration/ai.test.ts` | Все AI-эндпоинты: гейтинг 403/200, формы ответов, лимит 3/день (моки) |
| `integration/food.test.ts` | Поиск/штрихкод (моки OFF) |
| `integration/share.test.ts` | Шеринг-ссылки: создание, HTML/JSON, протухание |
| `integration/subscription.test.ts` | Dev-апгрейд тарифа |
| `unit/engine.test.ts` | Движок перераспределения (100% покрытие) |
| `unit/streak-logic.test.ts` | Логика серий: инкремент, заморозка, сброс |

## app/ — Flutter-приложение (iOS/Android/Web)
Конфигурация: `pubspec.yaml` (зависимости), `analysis_options.yaml` (линтер),
`android/` и `ios/` — нативные обёртки (манифест с разрешениями, домашний виджет Android).

### app/lib/core/ — ядро
| Файл | Зачем |
|---|---|
| `theme/app_theme.dart` | Все 5 тем (Focus/Calm/Black/White/Contrast) из design-tokens |
| `theme/theme_provider.dart` | Выбор темы + sharedPreferencesProvider |
| `router/app_router.dart` | Все маршруты: 4 таба + 15 push-экранов, redirect онбординг→auth→setup |
| `router/scaffold_with_nav_bar.dart` | Нижняя навигация 4 таба, профиль в AppBar |
| `database/database.dart` | Drift-схема v9: 11 таблиц (items, streak, water, day_logs, food_logs, sync_queue, shopping, recipes×2, sleep, workouts×2, goals×2) + миграции |
| `database/database_providers.dart` | Riverpod-провайдеры БД и всех DAO |
| `database/daos/*.dart` | По DAO на домен: запросы/мутации (items, streak, day_logs, water, food_logs, shopping, recipes, sleep, workouts, goals) |
| `animations/constants.dart` | Тайминги/кривые из ANIMATIONS.md §0 + reduce-motion хелперы |
| `animations/pressable.dart` | Scale 0.97 при нажатии + lift при наведении (§1) |
| `animations/animated_check.dart` | Рисующаяся галочка (§2.3) |
| `animations/app_toast.dart` | Тосты done/deadline/removed+Undo (§3) |
| `animations/app_sheet.dart` | Обёртка bottom sheet 300/220мс (§8.2) |
| `animations/ai_pulse_dot.dart` | Пульс-точка ожидания AI (§7.1) |
| `animations/ai_skeleton.dart` | Shimmer-скелетон загрузки (§7.2) |
| `animations/ai_insight_reveal.dart` | Fade-in появления AI-контента (§7.3) |
| `settings/tone_provider.dart` | Тон gentle/harsh (влияет только на тексты) |
| `settings/text_scale_provider.dart` | Размер текста (доступность) |
| `settings/water_goal_provider.dart` | Норма воды + расчёт по весу/активности |
| `settings/nutrition_goals_provider.dart` | Цели калорий/белка |
| `settings/recent_subjects.dart` | Недавние названия пар/экзаменов для быстрого добавления |
| `utils/id.dart` | Генератор UUID v4 |

### app/lib/features/ — экраны по разделам
| Файл | Зачем |
|---|---|
| `onboarding/onboarding_screen.dart` | 3 слайда ценности при первом запуске |
| `onboarding/setup_flow.dart` | 6 шагов настройки: интересы → импорт → время разборов → тон → тема → нормы (вода по весу/росту), кнопка Назад |
| `auth/auth_screen.dart` | Вход/регистрация + офлайн-режим (Google/Apple — заглушки) |
| `auth/auth_controller.dart` | Состояние авторизации + isPremiumProvider |
| `today/today_screen.dart` | Главный экран: приветствие, кольцо, стрик, разборы, списки задач |
| `today/widgets/progress_ring.dart` | Кольцо прогресса главного с пружиной на 100% |
| `today/widgets/streak_row.dart` | 🔥N + 7 точек последних дней |
| `today/widgets/task_list.dart` | Списки задач: свайпы done/skip, галочка, тосты |
| `today/widgets/add_task_sheet.dart` | Шит добавления/правки задачи: тип, приоритет (лимит 3 main), длительность (ручная + время конца) |
| `today/widgets/morning_review_card.dart` | Утренний разбор: перенос вчерашнего + варианты (free + AI) |
| `today/widgets/evening_review_card.dart` | Вечерний разбор: план на завтра |
| `today/widgets/review_engine.dart` | Чистая логика разборов: carry-over, варианты раскладки |
| `today/widgets/review_variant_card.dart` | Карточка варианта плана с кнопкой Apply |
| `today/widgets/celebration_overlay.dart` | Полноэкранный «День завершён»: оверлей, галочка, конфетти, стрик (§5) |
| `plan/plan_screen.dart` | Вкладка План: переключатель День/Неделя/Месяц + вход в цели |
| `plan/widgets/week_strip.dart` | Лента недель + выбранный день |
| `plan/widgets/day_timeline.dart` | Таймлайн дня по часам |
| `plan/widgets/week_agenda.dart` | Повестка недели + «Клонировать неделю» |
| `plan/widgets/month_view.dart` | Месячный календарь с точками задач |
| `plan/widgets/plan_providers.dart` | Режим вида + диапазон задач месяца |
| `plan/goals_screen.dart` | Долгосрочные цели: Месяц/Год/5/10 лет, шаги, «Plan today» |
| `plan/goal_progress.dart` | Чистый расчёт прогресса цели |
| `import/import_sheet.dart` | Импорт расписания: текст/шаблон + фото (AI) |
| `health/health_screen.dart` | Хаб здоровья: вода (+бар+график), сон, еда, фокус, тренировки, дыхание, осанка |
| `health/sleep_stats.dart` | Чистая математика сна (ночь через полночь и т.д.) |
| `health/breathing_screen.dart` / `breathing_engine.dart` | Дыхательные сессии: 3 пресета, круг по фазам |
| `health/posture_screen.dart` / `posture_exercises.dart` | Осанка: 6 упражнений + напоминания «выпрямись» |
| `health/workouts_screen.dart` | Шаблоны тренировок + история сессий |
| `health/workout_editor_screen.dart` | Редактор упражнений (подходы/повторы/вес/отдых) |
| `health/workout_trainer_screen.dart` | Режим «тренер»: подход → отдых-таймер → «Did it as planned» |
| `food/food_screen.dart` | Еда: итоги дня КБЖУ+сахар/клетчатка, баланс, поиск/штрихкод/фото/голос, AI-меню |
| `food/food_nutrition.dart` | Чистая математика КБЖУ (масштабирование порций) |
| `food/food_balance.dart` | Rule-based «Баланс рациона» с мягкими подсказками |
| `food/barcode_scanner_screen.dart` | Сканер штрихкодов (камера + фонарик) |
| `food/recipes_screen.dart` / `recipe_editor_screen.dart` | Рецепты: список + редактор ингредиентов, «Log this recipe» |
| `food/recipe_nutrition.dart` | Итоги рецепта и пересчёт «на 100 г» |
| `food/ai_menu.dart` / `ai_menu_sheet.dart` | «Собрать ИИ»: кандидаты, разбор ответа (числа считает код), применение |
| `food/shopping_list_screen.dart` | Список покупок: галочки, Undo, Clear checked |
| `diary/diary_screen.dart` | Дневник: настроение, заметка, чипы «что пошло не так», AI-инсайт |
| `diary/diary_insight.dart` | Бесплатный rule-based недельный инсайт |
| `wrapped/wrapped_screen.dart` | Итоги Недели/Месяца + AI-абзац |
| `focus/focus_screen.dart` | Фокус-сессии: пресеты 25/5…67/15, трение при выходе |
| `paywall/paywall_screen.dart` | Подписка $10/мес: Subscribe (работает через PurchaseService) + Restore |
| `profile/profile_screen.dart` | Профиль: аккаунт, стрик, premium, шеринг (мой план + «поделились со мной»), темы, настройки, версия |
| `profile/shared_plan.dart` | Чистый разбор шеринг-ссылки/токена |

### app/lib/services/ — сервисы
| Файл | Зачем |
|---|---|
| `api/api_client.dart` | Dio-клиент всех эндпоинтов: токен, 401-обработка, методы API |
| `sync/sync_service.dart` | Офлайн-синк: собирает изменённое, шлёт /sync, мёржит ответ |
| `notifications/notification_service.dart` | Локальные уведомления: утро/вечер + осанка |
| `streak/streak_service.dart` | Офлайн-пересчёт стрика (зеркало серверного) |
| `purchases/purchase_service.dart` | Срез под RevenueCat: сейчас заглушка (debug → dev-upgrade) |
| `widget/widget_service.dart` | Передача данных в Android-виджет через MethodChannel |
| `main.dart` | Точка входа: ProviderScope, prefs, роутер, синк на старте |

### app/test/ — тесты приложения (119 шт.)
Юниты чистой логики (review_engine, food_balance/nutrition, recipe/ai_menu,
sleep_stats, breathing, goals, water_goal, diary_insight, shared_plan, recent_subjects),
DAO-тесты на in-memory БД (shopping, recipes, workouts, goals) и
смоук-тесты экранов (`screens_smoke_test.dart`: Today/Plan/Diary/Shopping; паттерн
in-memory Drift + размонтирование в конце — см. комментарии в файле).

## landing/ — лендинг
`index.html` — одностраничник (Tailwind CDN): hero, фичи, прайсинг, умная кнопка
Download по платформе. TODO: реальные ссылки сторов перед релизом.

## .claude/ и .vscode/
`.claude/rules/rules.md` — рабочие правила AI-сессий (читаются автоматически).
`.vscode/` — настройки редактора для текущей IDE.
