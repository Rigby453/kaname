# ИИ-онбординг + быстрое добавление — техническая архитектура (Волна 6)

> Инженерный план реализации задачи №1. Вопросы/гейт-решения — в `docs/AI-ONBOARDING-QUESTIONS-DRAFT.md`
> (на утверждение). Концепция — `docs/VISION-AI-VOICE-PLANNING.md`. Здесь — контракты, файлы, маппинг,
> переиспользование. Дефолты помечены; правятся утром.

## Переиспользуем (НЕ строим заново)
- **Голос/текст ввод:** `app/lib/core/widgets/voice_text_field.dart` (speech_to_text, locale-aware, web-safe).
- **NL-парсер дат:** `app/lib/core/utils/nl_datetime.dart` (`parseNaturalDateTime`, RU/EN/DE) — быстрый предпроход.
- **Провайдер ИИ:** `backend/src/ai/provider.ts` `generateText({system,user,tier,json})` (Groq/Gemini/Anthropic по env; tier:'smart' → claude-sonnet-4-6/Gemini Pro). НИКОГДА не звать ИИ из роутов/клиента.
- **Шаблон эндпоинта:** `backend/src/ai/smartRedistribute.ts` (Zod + `withAiRetry` + `langDirective` + `stripJsonFences`).
- **Гейт премиума:** backend `ensurePremium()` (routes/ai.ts) → `resolveEntitlement`; app `isPremiumProvider` + `showPremiumUpsell`.
- **Форма задачи + сохранение:** `app/lib/features/today/widgets/add_task_sheet.dart` (полный набор полей + Drift insert + sync) — превью/подтверждение переиспользует её путь сохранения.
- **Превью-подтверждение как UX-эталон:** morning_review_card (одобренный «ИИ предлагает — юзер подтверждает»).

## Контракты (snake_case в payload, как весь API)

### POST /api/v1/ai/onboarding-plan  (premium)
```
req:  { answers: string, date: string(ISO), timezone: string, locale: string }
resp: {
  goals: [{ title: string, horizon?: 'week'|'month'|'quarter'|'year' }],
  tasks: [{
    title: string,
    type: 'task'|'event'|'exam'|'deadline',
    priority: 'low'|'medium'|'high'|'main',
    scheduled_at?: string(ISO),          // для event/task со временем
    deadline?: string(ISO),              // маплю в type='deadline' + scheduled_at (дефолт C)
    duration_minutes?: number,
    note?: string
  }],
  food_prefs?: { tracks_food: bool, tracks_water: bool, tracks_sleep: bool }
}
```
- Валидация Zod, `thinkingBudget:0` (Gemini), `langDirective(locale)`, `tier:'smart'`.
- Ограничение: max ~3 priority='main' (правило приложения) — при превышении понизить лишние до 'high'.

### POST /api/v1/ai/quick-add  (premium)
```
req:  { text: string, date: string(ISO), timezone: string, locale: string }
resp: { task: { title, type, priority, scheduled_at?, deadline?, duration_minutes?, note? } }
```
- «на работу через час в Бутово» → type=event, scheduled_at=now+1h, note/location=«Бутово».
- Клиент может предзаполнить `nl_datetime` и отдать ИИ на доуточнение (ИИ — авторитет по типу/важности).

## Backend файлы
- `backend/src/ai/onboardingPlan.ts` — по образцу smartRedistribute.ts: system-промпт (роль: планировщик студента; вернуть СТРОГО JSON по схеме; язык = locale; не выдумывать даты — только явные/относительные из ответов; помечать важное как 'main' экономно), Zod-схема ответа, `withAiRetry`.
- `backend/src/ai/quickAdd.ts` — аналогично, одна задача.
- Роуты в `backend/src/routes/ai.ts`: два `POST`, `preHandler: requireAuth` + `ensurePremium()`.
- Тесты `tests/integration/ai.test.ts`: 403 (free) / 200 (premium), мок провайдера (как schedule-import).

## App файлы
- **api_client** `app/lib/services/api/api_client.dart`: `aiOnboardingPlan(...)`, `aiQuickAdd(...)` рядом с `aiRedistribute`/`scheduleImportFromPhoto`.
- **Брейндамп-экран** (новый, в `app/lib/features/onboarding/`): большое поле = `VoiceTextField`; чип-строка/список из 6 вопросов-подсказок (гаснут при ответе); кнопка «Собрать план» → лоадер → **превью плана** (цели + задачи с временем/важностью/дедлайном, редактируемые) → «Принять» → запись в Drift + sync (НЕ автосейв). Вставка в setup_flow как новая страница ИЛИ отдельный post-registration экран (решаю по UX). Экран согласия перед первым ИИ-вызовом (приватность #13).
- **ИИ-кнопка быстрого добавления** на Today/Plan (рядом с FAB): открывает голос/текст-поле → `/ai/quick-add` → confirm-sheet, переиспользующий путь сохранения add_task_sheet.
- Гейт: `final premium = await ref.read(isPremiumProvider.future); if(!premium){ showPremiumUpsell(context, context.s('...')); return; }` (строки — локализованные, как в Волне 1). Триал-разблокировка — тонкий слой поверх (после решения A).

## Маппинг plan→Drift (без смены схемы, дефолт C)
- type/priority/scheduled_at/duration_minutes/note → синхронизируемые колонки Item.
- deadline → type='deadline' + scheduled_at=срок (отдельной колонки нет).
- color/location — локальные колонки (не синхро).
- goals[] → существующая модель Целей (проверить `plan/goals_*`); при отсутствии простого API — сохранить как задачи с note, а Цели связать позже.

## Открытые (решения к утру, дефолты в QUESTIONS-DRAFT)
- A: гейт кнопки (дефолт: триал всем, потом premium). B: авто-vs-подтверждение (дефолт: всегда превью). C: deadline (дефолт: type=deadline). Модель: tier:'smart'. Триал-механизм: нет в коде — тонкий слой после решения A.

## Порядок сборки (Волна 6, multi-stage)
1. Backend: 2 эндпоинта + промпты + Zod + тесты (мок провайдера) — самодостаточно, без продукт-блокеров.
2. App quick-add (проще онбординга): кнопка → confirm — меньше риска переделки.
3. App брейндамп-онбординг: экран + превью + согласие.
4. Верификация + адверсариальный ревью промптов/схем.
