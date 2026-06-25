# Kaizen — Onboarding Flow (logic & completeness design)

> Status: design proposal for review (2026-06-25). Visuals are placeholder — this doc fixes
> **logic, flow, and completeness**, not pixels. Source of truth for the *what*: `docs/SPEC.md §C1`.
> Reconciled against current code: `onboarding_screen.dart`, `auth_screen.dart`, `setup_flow.dart`,
> `core/router/app_router.dart`.
>
> Branch: `night/2026-06-25-meditation-onboarding-audio`. **No app code changes in this doc** — it is
> handed to a build agent next (see §7).

---

## 1. Goals & principles

The job of onboarding: **in under ~90 seconds, the user understands the value, feels the hook once,
and lands on a Today screen that already has their stuff in it** — with every important setting either
asked (only the high-leverage few) or set to a smart default they can change later in Profile.

Principles, in priority order:

1. **Value first, setup second.** Show the hook (auto-carry-over of unfinished tasks + the "why plans
   fail" promise) *before* asking anything. The current split (value slides → auth → 12-screen quiz)
   front-loads a quiz; we merge it into one arc that keeps proving value between asks.
2. **Minimal friction / one mandatory gate.** Only **one** screen is truly mandatory: auth (and even
   that has an "continue offline" escape). Everything else is **skippable** with a sane default and an
   always-visible *Skip* (the code already has `_skipAllToApp` — keep that safety valve).
3. **Progressive disclosure.** Ask the 6–8 settings that change the *first session* (goals, schedule,
   tone, review time, theme). Defer the long tail (health norms, nutrition macros, food prefs, swipe
   actions, FAB position, text size, app icon, quiet hours) to **smart defaults you can change later**.
   "Surfaced" ≠ "asked up front" — surfaced means *reachable and pre-filled in Profile*, plus pointed at
   by the first-run mini-tour.
4. **Every ask earns its place** with an immediate payoff: schedule import → Today is pre-populated;
   first task → see the priority shield; review time → notifications scheduled; norms → water/calorie
   numbers appear in the summary.
5. **Honest, no dark patterns.** Paywall is a soft, skippable last step (free tier is fully usable —
   ADR-052). The summary screen tells the literal truth about what was set.
6. **Tone-aware from the first slide.** Kai and copy respect the chosen `gentle/harsh` tone, but tone is
   asked early enough (mid-flow) that the celebratory/summary screens already reflect it.

---

## 2. Full feature / settings inventory

Decision legend: **ASK** = collected during onboarding · **DEFAULT** = smart default now, editable in
Profile later · **DEFER-CONTEXTUAL** = not in onboarding; prompt in-context the first time the feature
is opened · **SKIP** = not surfaced at onboarding at all.

| Setting / feature | Pref key (const) · default | File | Decision | Why |
|---|---|---|---|---|
| Onboarding seen flag | `onboarding_done` · false | `onboarding_screen.dart` | system | Router gate |
| Setup seen flag | `setup_done` · false | `setup_flow.dart` | system | Router gate |
| Language / locale | `app_locale` · device locale | `core/l10n/locale_provider.dart` | **ASK (fast, step 1)** | Whole app is unreadable if wrong; 1 tap. Ships EN-first, so auto-detect + confirm. |
| Account (email/password) | auth token (secure store) | `auth_screen.dart` / `auth_controller.dart` | **ASK (mandatory, w/ offline escape)** | Sync + paywall need it. OAuth removed (ADR-031). |
| Tone gentle/harsh | `tone_preference` · gentle | `core/settings/tone_provider.dart` | **ASK** | Defines Kai's whole voice; cheap binary pick; must be set before summary/celebration copy. |
| Theme (focus/black/white/calm/contrast) + custom editor | `app_theme_key` · `white`(light)/`black`(dark) by system mode; custom: `custom_theme_*` | `core/theme/theme_provider.dart`, `custom_theme_provider.dart` | **ASK (skippable, previews)** | First visual impression; a 5-tile preview is a delight moment. Custom-theme editor stays in Profile, not onboarding. **Currently MISSING from flow — gap.** |
| Mascot "Kai" on/off | `show_kai` · true (on) | `core/settings/mascot_provider.dart` | **DEFAULT** | On by default; toggling lives in Profile. Don't ask — Kai *is* the onboarding host. |
| Goals (study/procrastination/routine/free time/exams) | `onboarding_goals` · [] | `setup_flow.dart` | **ASK (skippable)** | Personalizes copy + later AI; multiselect, low friction. |
| Interests | `interests` · [] | `setup_flow.dart` (`interestsKey`) | **SKIP (recommend retire)** | Overlaps with Goals; not consumed by any feature today. See Open Question Q3. |
| Planning time / horizon | `onboarding_plan_minutes`, `onboarding_horizon` | `setup_flow.dart` | **DEFAULT (fold into projection)** | Only feeds the "hours/year" projection slide; keep the slide, infer instead of two extra asks. |
| Schedule import | items in Drift (no single key) | `features/plan/*` | **ASK (skippable, the killer step)** | The student hook. Clone-week / photo-OCR / paste / skip. **Currently MISSING from flow — gap.** |
| First task | row in `ItemsTable` | `setup_flow.dart` (screens 12–13) | **ASK (skippable, value demo)** | Lets the user feel "add → priority shield → carry-over" once. |
| Review times (morning/evening) | `review_morning_hour` · 8, `review_evening_hour` · 20 | `setup_flow.dart` | **ASK (skippable)** | Schedules the core daily-review notifications. |
| Notifications enabled / permission | `notifications_enabled` · (OS perm) | `services/notifications/notification_service.dart` | **ASK (contextual, right after review time)** | Ask OS permission *when* it pays off (right after picking review times), not cold at launch. |
| Sleep schedule (bedtime/wake) | `sleep_bedtime_hour` · 23, `sleep_wake_hour` · 7 | `core/settings/health_profile_provider.dart` | **DEFAULT (offer in "personalize" optional sub-step)** | Used for the night no-notification window; good defaults exist. |
| Anthropometry (age/sex/height/weight/activity) | `user_age`, `user_sex` · other, `user_height_cm`, `user_weight_kg`, `user_activity` · medium | `core/settings/water_goal_provider.dart` | **DEFAULT (optional "personalize health" sub-step)** | Only needed for water/calorie numbers (Phase-1 Food). Heavy to ask cold; make it one opt-in expandable, not 3 mandatory screens. See Q1. |
| Water goal | `water_goal_ml` · `kDefaultWaterGoalMl` | `core/settings/water_goal_provider.dart` | **DEFAULT (derived)** | Auto-computed from anthropometry if given, else default; editable in Health. |
| Nutrition / calorie / protein goals | `calorie_goal_kcal`, `protein_goal_g` | `core/settings/nutrition_goals_provider.dart` | **DEFER-CONTEXTUAL** | Phase-1 Food feature; ask when Food tab first opened. |
| Macro overrides / auto-balance | `macro_*` keys | `core/settings/macro_override_provider.dart` | **DEFER-CONTEXTUAL** | Advanced Food setting; never in onboarding. |
| Food prefs (diet/goal/likes/dislikes/meals) | `food_diet`, `food_goal`, `food_likes`, `food_dislikes`, `food_meals_per_day` | `core/settings/food_preferences_provider.dart` | **DEFER-CONTEXTUAL** | Collected by a Food mini-setup on first Food visit. |
| Health profile (allergies/healing/deficiencies) | `health_allergies`, `health_healing`, `health_deficiencies` | `core/settings/health_profile_provider.dart` | **DEFER-CONTEXTUAL** | Sensitive + Phase-1/2; ask in Health, not onboarding. |
| Text size | `text_size_preference` · system | `core/settings/text_scale_provider.dart` | **DEFAULT** | Respect system scale; Profile to override. |
| Swipe actions (left/right) | `swipe_left_action` · skip, `swipe_right_action` · done | `core/settings/swipe_action_provider.dart` | **DEFAULT** | Good defaults; surfaced by mini-tour swipe hint. |
| Default reminder mode/minutes | `reminder_default_mode` · none, `reminder_default_minutes` · 15 | `core/settings/reminder_default_provider.dart` | **DEFAULT** | Per-task reminders; Profile to change global default. |
| Completion sound | `completion_sound_enabled` · true | `core/settings/sound_provider.dart` | **DEFAULT** | On by default; Profile toggle. |
| Workout rest default | `rest_default_seconds` · 120 | `core/settings/rest_default_provider.dart` | **DEFER-CONTEXTUAL** | Phase-2 Workouts; set in trainer mode. |
| Swipe hint seen | `seen_swipe_hint` · false | `core/settings/swipe_hint_provider.dart` | **system (mini-tour)** | This is the existing first-run hint primitive — reuse for the tour (§5). |
| FAB position | `fab_position` · default | `core/settings/fab_position_provider.dart` | **DEFAULT** | Power-user tweak; Profile only. |
| Timezone override | `timezone_override` | `core/settings/timezone_provider.dart` | **DEFAULT** | Auto from device; advanced override in Profile. |
| Quiet hours | (not yet implemented) | — (SPEC C7) | **DEFAULT/future** | Derive from sleep schedule; Profile later. |
| App icon | (not yet implemented) | — (SPEC C7) | **SKIP** | Cosmetic; Profile only. |
| Soft nutrition mode (hide calories) | (not yet implemented) | — (SPEC C7) | **DEFER-CONTEXTUAL** | Offer in Food. |
| Streak freeze | `StreakTable` | DB | **SKIP** | Earned/used in-app, not configured. |
| Subscription / Premium | paywall | `features/paywall/paywall_screen.dart` | **ASK (soft, last, skippable)** | Free tier fully usable; paywall is the honest last beat. |

**Net result:** onboarding *asks* ~7 things (language, account, goals, schedule, first-task, tone+review,
theme) plus an *optional* health personalize block; everything else ships as a smart default or a
contextual ask. That satisfies "all settings surfaced" without a 16-screen quiz.

---

## 3. The unified flow (recommended)

One coherent arc, replacing today's three separate destinations (`/onboarding` → `/auth` → `/setup` →
`/paywall`). Numbered as the user experiences them. **M = mandatory, S = skippable.**

| # | Step | M/S | Purpose | What's asked | Default if skipped | Why here |
|---|---|---|---|---|---|---|
| 0 | **Splash** | M | Brand beat while prefs/auth load | nothing | — | Covers the async gate; no decisions. |
| 1 | **Language** | S | Make app readable | pick language | device locale → EN | Must precede all copy. Auto-detect, 1 tap to confirm/change. |
| 2 | **Value slide 1 — Kai + hook** | S | Emotional hook | nothing | — | "The important stuff won't slip." Kai introduces self. |
| 3 | **Value slide 2 — the problem/solution** | S | Show *why plans fail* + auto-carry-over | nothing | — | The differentiator before any ask. |
| 4 | **Value slide 3 — what you get** | S | Concrete promise (review, streak, health) | nothing | — | Sets expectation for the asks that follow. |
| 5 | **Account** | M* | Identity for sync + premium | email + password (login/register) | *or* "continue offline" | Gate per SPEC; offline escape keeps it from being a wall. OAuth removed (ADR-031). |
| 6 | **Goals** | S | Personalize tone/AI | multiselect goals | none | Cheap, motivating, drives later copy. |
| 7 | **Time-cost projection** | S | Aha-moment ("~X hrs/year planning") | infers from a single "how much do you plan now?" tap | "almost never" branch (no number, motivating copy) | Pure payoff screen; justifies the app. Folds old plan-minutes+horizon into one. |
| 8 | **Schedule import** | S | Pre-fill the week (student killer feature) | choose: Clone-week builder · Photo/OCR · Paste text · Skip for now | empty week | The single biggest "Today already has my life in it" moment. **NEW vs current flow.** |
| 9 | **First task + priority demo** | S | Feel "add → shield → carry-over" once | type one task | none | The hook made tangible; inserts a real Drift row. |
| 10 | **Review time** | S | Schedule daily review notifications | morning / evening / both | both, 08:00 / 20:00 | Directly wires the core loop. |
| 11 | **Notifications permission** | S | OS permission at peak relevance | system permission prompt | enabled=false, no crash | Asked *because* step 10 just promised reminders — high grant rate. |
| 12 | **Tone** | S | Kai's voice | gentle / harsh | gentle | Set before celebration/summary copy renders. **NEW vs current flow.** |
| 13 | **Theme** | S | First-impression personalization | pick from 5 live previews | focus | Delightful, low-risk. **NEW vs current flow.** |
| 14 | **Personalize health (optional block)** | S | Real water/calorie numbers | age/sex, height/weight, activity, sleep window — one expandable card, all optional | medium activity, default water, sleep 23:00–07:00 | Heavy stuff made opt-in, not 3 mandatory screens. See Q1. |
| 15 | **Summary** | S | Honest recap + confidence | nothing (review) | — | Shows exactly what was set (lang, goal, water, calories, review, sleep, theme, tone). |
| 16 | **Paywall (soft)** | S | Offer Premium honestly | subscribe *or* "continue free" | free tier | Free tier fully usable (ADR-052); never a wall. |
| 17 | **Land on Today + mini-tour** | — | Arrive with content | — | — | First-run coach marks (§5). |

\* Step 5 is the only hard gate, and even it offers offline mode.

### 1-line copy examples (EN + RU)

- **Step 2 (hook):** EN "The important stuff won't slip — I'll make sure of it." · RU "Главное не потеряется — я прослежу."
- **Step 3 (problem):** EN "Plans don't fail because you're lazy. They fail because nobody rebuilds the day. I do." · RU "Планы рушатся не от лени, а потому что день никто не пересобирает. Я пересоберу."
- **Step 5 (account):** EN "Create an account to sync — or just start offline." · RU "Создай аккаунт для синхронизации — или начни офлайн."
- **Step 6 (goals):** EN "What brings you here? Pick all that fit." · RU "Зачем ты здесь? Выбери всё подходящее."
- **Step 7 (projection):** EN "~18 hours a year — that's what planning gives back." · RU "~18 часов в год — вот что даёт планирование."
- **Step 8 (schedule):** EN "Let's get your week in. Clone it, snap a photo, or paste it." · RU "Добавим твою неделю. Клонируй, сфотографируй или вставь текстом."
- **Step 9 (first task):** EN "Name one thing that matters today." · RU "Назови одно главное дело на сегодня."
- **Step 10 (review):** EN "When should I rebuild your day?" · RU "Когда пересобирать твой день?"
- **Step 12 (tone):** EN "Want me gentle, or honest and blunt?" · RU "Мне быть мягким или честным и прямым?"
- **Step 13 (theme):** EN "Pick a look. Change it anytime." · RU "Выбери вид. Поменяешь когда угодно."
- **Step 14 (health):** EN "Want real water & calorie targets? Tell me a bit about you (optional)." · RU "Нужны точные нормы воды и калорий? Расскажи о себе (по желанию)."
- **Step 15 (summary):** EN "Here's your setup. All of it is editable later." · RU "Вот твои настройки. Всё можно поменять позже."
- **Step 16 (paywall):** EN "Everything here is free. Premium just adds the smart AI." · RU "Всё это бесплатно. Премиум добавляет умный ИИ."

---

## 4. Where each existing piece maps (reconciliation)

### `onboarding_screen.dart` (today: language + 3 value slides → `/auth`)
- **KEEP** the language slide → becomes step 1. Note: it currently lists **all 12 languages**; since we
  ship EN-first, auto-detect device locale and make this a *confirm/change*, not a 12-item scroll.
- **KEEP** the 3 editorial value slides + Kai → steps 2–4. Reword toward the *hook* (auto-carry-over),
  not generic "flag/twilight/book" icons.
- **CHANGE** the `_finish()` handoff: instead of `context.go('/auth')` ending the screen, the whole arc
  becomes one flow (see §7 — either a shared shell or sequential routes that no longer feel like 3 apps).

### `auth_screen.dart` (today: phone/email toggle, password, offline)
- **KEEP** email/password + "continue offline" → step 5.
- **CHANGE per spec/ADR-031:** SPEC C1 says **email/password** (OAuth removed). The screen still defaults
  to **phone** with a phone/email SegmentedButton citing 406-ФЗ. Decision needed (Q2): the spec text in
  the task says email/password — recommend **email primary, phone optional**, or drop the toggle. Either
  way Google/Apple stay removed.
- **KEEP** forgot-password, error/ember styling, KaiLoader.

### `setup_flow.dart` (today: 12 screens, the "quiz")
| Current screen | Fate |
|---|---|
| 5 Goals (multiselect) | **KEEP** → step 6 |
| 6 Planning minutes + 7 Horizon | **MERGE** into one infer-tap feeding step 7 projection |
| 8 Projection (hours/year) | **KEEP** → step 7 |
| 9 Age/sex, 10 Height/weight, 11 Activity | **MERGE → one optional "personalize health" card** → step 14 (no longer 3 mandatory screens) |
| 12 First task (no-skip) | **KEEP but make skippable** → step 9 |
| 13 Carry-over demo | **KEEP** → folded into step 9's payoff |
| 14 Review time + sleep schedule | **SPLIT**: review time → step 10; sleep → optional part of step 14 |
| 15 Summary | **KEEP** → step 15 (add theme + tone rows) |
| 16 Paywall handoff | **KEEP** → step 16 |

### Gaps the recon found (must be ADDED — they are in SPEC C1 but absent from code today)
1. **Schedule import** — SPEC C1 lists it; `setup_flow.dart` never imports a schedule. **Add step 8.**
   (Plan-tab import constructor/OCR/paste already exists in `features/plan` — onboarding should *enter*
   that, not reinvent it.)
2. **Tone** — `tone_preference` exists and Kai reads it, but onboarding never asks it. **Add step 12.**
3. **Theme** — `app_theme_key` exists with 5 themes, but onboarding never asks it. **Add step 13.**
4. **Notifications permission** is implicitly assumed (review scheduling wrapped in a try/catch) but never
   explicitly requested with context. **Add step 11.**

### Keep these existing safety behaviors
- The always-visible **Skip** (`_skipAllToApp` writing `setup_done` and going to `/today`) — keep on every
  skippable step.
- Local water recompute on weight/height/activity change — keep inside step 14.
- Inserting the first task as a real Drift row (`local` user) — keep.

---

## 5. First-run mini-tour (coach marks)

SPEC C1 says "(опц.) мини-тур подсказок при первом заходе на экраны." Recommendation: **lightweight,
per-tab, dismissible, one hint per tab, gated by its own pref flag** (reuse the existing
`seen_swipe_hint` pattern from `swipe_hint_provider.dart`; add sibling flags per tab).

| Tab | First-visit hint (EN / RU) | Gate key (proposed) |
|---|---|---|
| Today | "Swipe right = done, left = skip. The ring fills as you close 'Main'." / "Свайп вправо — готово, влево — пропустить." | `seen_swipe_hint` (exists) |
| Plan | "Tap [+] to add, or import your whole week here." / "Жми [+] или импортируй неделю." | `seen_tour_plan` |
| Health | "Track water in one tap. Food, sleep & workouts live here too." / "Вода в один тап. Тут же еда, сон и тренировки." | `seen_tour_health` |
| Diary | "End the day in 30s: mood + what went wrong → patterns." / "Заверши день за 30 сек: настроение + что пошло не так." | `seen_tour_diary` |
| Profile (avatar) | "Everything's editable: theme, tone, language, norms." / "Здесь всё меняется: тема, тон, язык, нормы." | `seen_tour_profile` |

Rules: show **once per tab**, never block interaction (overlay with a single "Got it"), respect
`MediaQuery.disableAnimations`, and never appear during the onboarding flow itself. This is how deferred
settings stay *surfaced* without being asked up front.

---

## 6. Open questions for the user

1. **Health norms aggressiveness (Q1):** Do you want step 14 (age/sex/height/weight/sleep) as a *single
   optional expandable* (my recommendation — low friction, numbers only for those who want them), or
   keep it as today's 3 fuller screens because Food/Water are central to the product? Cold-asking body
   metrics before any payoff is the riskiest part of the current flow.
2. **Auth identifier (Q2):** SPEC C1 says email/password; the code defaults to **phone** (406-ФЗ). Keep
   phone-primary with email option, make **email primary**, or single-field? (OAuth stays removed.)
3. **Interests (Q3):** Retire the `interests` step entirely (recommended — it duplicates Goals and nothing
   consumes it), or keep and actually wire it to personalization?
4. **Flow length tolerance (Q4):** 17 beats is lean but not tiny. Are you OK with all skippable, or do you
   want an even shorter "express path" (slides → account → schedule → done) with the rest moved to a
   "finish setting up" card on Today?
5. **Paywall placement (Q5):** Soft paywall as the last onboarding beat (current), or move it to a Today
   banner after the user has felt one full daily cycle (often converts better)?

---

## 7. Implementation notes (for the build agent)

**Goal:** collapse `/onboarding` + `/auth` + `/setup` into one coherent flow without breaking the router
gates, and fill the 4 gaps (schedule, tone, theme, notif permission).

**Recommended structure:** keep three *route segments* (so deep-link/back behavior stays sane) but make
them feel like one arc — shared progress affordance, shared Kai host, no jarring "new app" transitions.
Order enforced by `app_router.dart` redirect, which already chains `onboarding_done → auth → setup_done`.

**Files to touch (in order):**
1. `app/lib/features/onboarding/onboarding_screen.dart` — trim language to auto-detect+confirm; reword the
   3 value slides toward the hook; keep `onboarding_done` write.
2. `app/lib/features/auth/auth_screen.dart` — resolve Q2 (email-primary per SPEC); keep offline path.
3. `app/lib/features/onboarding/setup_flow.dart` — the big one:
   - add **schedule-import** step (route into existing `features/plan` import, don't duplicate),
   - add **tone** step → write `tone_preference` via `toneProvider`,
   - add **theme** step (5 live previews) → write `app_theme_key` via `themeProvider`,
   - add **notification-permission** step right after review-time,
   - collapse age/sex/height/weight/activity/sleep into **one optional card** (step 14),
   - make first-task **skippable**,
   - extend the **summary** to include theme + tone rows.
4. `app/lib/core/router/app_router.dart` — verify redirect order still holds; no new route needed if
   reusing `/setup`, but consider a `/setup` sub-step index so Back works within the arc.
5. **Mini-tour:** extend `swipe_hint_provider.dart` pattern with `seen_tour_<tab>` flags; add a small
   coach-mark overlay widget consumed by each tab's first build.

**Riverpod / prefs keys involved:**
- Flags: `onboarding_done`, `setup_done`, `seen_swipe_hint`, new `seen_tour_{plan,health,diary,profile}`.
- Asked: `app_locale` (`localeNotifierProvider`), `tone_preference` (`toneProvider`), `app_theme_key`
  (`themeProvider`), `onboarding_goals`, `review_morning_hour`/`review_evening_hour`,
  `notifications_enabled` (`notificationsEnabledProvider`).
- Optional health: `user_age`, `user_sex`, `user_height_cm`, `user_weight_kg`, `user_activity`,
  `water_goal_ml` (`waterGoalProvider`), `sleep_bedtime_hour`, `sleep_wake_hour`.
- Derived/defaulted (do **not** ask): `show_kai`, `text_size_preference`, `swipe_*_action`,
  `fab_position`, `timezone_override`, all `food_*` / `macro_*` / `health_*` / nutrition keys
  (DEFER-CONTEXTUAL — collected on first Food/Health visit).

**Anti-regression gates (from `app/CLAUDE.md`):** every new onboarding string goes through `context.s()`
with `en` + `ru`; test each new step at width 320px, textScale 1.5–2.0, and keyboard-open. The schedule
and first-task steps have text fields — apply the keyboard-collapse rule.

**Suggested build order:** (a) tone + theme steps (smallest, pure pref writes, fill 2 gaps); (b) notif
permission step; (c) collapse health into one optional card; (d) schedule-import step (largest — reuses
Plan import); (e) summary + mini-tour. Ship and verify each as its own atomic task.
