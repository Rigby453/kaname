# Redesign — Landing & legal pages «Kaname»

> ТЗ на приведение публичного сайта (landing/index.html + privacy.html + terms.html) к
> новой дизайн-системе «Kaname». Токены: `docs/design-tokens.json` (v4). Принципы:
> `docs/REDESIGN-KANAME.md`. Сайт = чистый HTML + Tailwind CDN + Alpine (без сборки).
> Деплой: GitHub Pages **только с `main`** (`.github/workflows/deploy-web.yml`).

## Цель
Старый лендинг = тёмная «Focus»-тема (лайм `#D9F24B` на `#141009`) — она **снята с производства**.
Новый сайт должен ощущаться как приложение: **Day-тема** (светлый тёплый off-white), calm premium
minimalism (Things 3 / Linear), один акцент, Geist, Phosphor-иконки, sentence case, плоско и тихо.

## Глобальные токены → web (Day-тема, default)
| Роль | Значение |
|------|----------|
| bg | `#F6F5F2` |
| surface1 (карточки) | `#FFFFFF` |
| surface2 | `#FCFBF9` |
| ink (текст) | `#1B1A18` |
| text secondary | `#6E6B66` |
| text muted | `#8E8A85` |
| border hairline | `#E6E4DE` (0.5–1px) |
| border strong | `#D8D5CE` |
| **accent** (default = indigo) | `#4B57C9`, tint `#ECEDFA`, ink-on-tint `#3A45A8`, on-accent `#FFFFFF` |
| status ember (цена/срочное) | `#C2510C` |
| status success | `#1A7A3E` |

- **Один акцент = indigo** (`#4B57C9`) — совпадает с дефолтом приложения. Лайм НЕ использовать.
  Можно показать палитру из 6 акцентов как **фичу** («сделай своим — 6 акцентов»), но сам сайт
  оформлен в indigo.
- **Шрифт:** Geist (Google Fonts CDN: `Geist`), fallback Hanken Grotesk. Один шрифт на весь сайт.
  Веса 400/500, 600 редко. Цифры — tabular. **Sentence case везде, НИКАКОГО ALL-CAPS.**
- **Иконки:** Phosphor через CDN `@phosphor-icons/web` (regular по умолчанию, fill+accent на active).
  Убрать emoji/случайные SVG. Размеры 16/20/24.
- **Spacing** 4·8·12·16·24·32·48 (паддинг секций 24–32, контентная колонка max 1160px, центр).
- **Radius** кнопки/инпуты 12, карточки 14–16, большие блоки/«листы» 20, чипы pill.
  **Без односторонних скруглений.**
- **Плоско:** карточки = surface1 + hairline border, без теней. Тень только на «плавающих»
  элементах (sticky-CTA/поповер): `0 8 24 / 12%`.
- **Motion:** сдержанно (180–240ms ease), spring только на «радости». Уважать `prefers-reduced-motion`.

## Tailwind config (inline, в `<script>` перед CDN-классами)
Переопределить тему: `colors` (bg/surface1/surface2/ink/secondary/muted/border/borderStrong/accent/
accentTint/accentInk/ember/success), `fontFamily.sans = ['Geist', 'Hanken Grotesk', ...]`,
`borderRadius` (control 12, card 14, card-lg 16, sheet 20, pill 999), `maxWidth.content 1160px`.
Классы в разметке должны ссылаться на эти токены (`bg-bg`, `text-ink`, `text-secondary`,
`border-border`, `bg-accent`, `text-accent`, `bg-accent-tint` …), НЕ хардкодить hex в классах.

## Секции (порядок сохранить, переоформить)
1. **Хедер/néav:** прозрачный→`bg/80` blur на скролле, hairline снизу. Слева вордмарк «Kaname»
   (Geist 500). Справа: links (Features · Pricing · Privacy) + один accent-кнопка «Open app».
2. **Hero:** крупный display-заголовок (Geist 500, 40–56px, tight letter-spacing, sentence case),
   подзаголовок text-secondary, **одна** первичная кнопка (accent fill, R12, h≥52) + вторичная ghost.
   Под ней — чистый мокап приложения в **Day-теме** (рамка телефона, surface1, hairline, скриншот/
   плейсхолдер таймлайна Today). Лёгкое присутствие **Kai** — бесформенная «капля» (superellipse/blob)
   одним accent-заливом, БЕЗ лица. Не перекрывает текст.
3. **Problem / Solution (3 карточки):** surface1 + hairline + R16, Phosphor-иконка сверху (accent),
   заголовок + 1–2 строки. Тексты — как в landing/CLAUDE.md, sentence case.
4. **Features (3 плитки):** morning review · plan-as-spine/timeline · tone toggle (gentle/harsh).
   Плитки = surface1, hairline, скриншот-плейсхолдер в Day-теме.
5. **Pricing (Free vs Premium $10/mo):**
   - ⚠️ **ИСПРАВИТЬ КРИТИЧНО:** приложение **БЕЗ РЕКЛАМЫ ВЕЗДЕ** (ADR-052). Убрать любое
     «Ads / non-intrusive ads». Free = полностью пригоден, БЕЗ ИИ, без рекламы. Premium = ИИ-фичи
     (умное перераспределение, варианты планов, глубокие инсайты дневника), без рекламы.
   - Цена `$10/mo` — бейдж в ember. Две карточки, Premium слегка выделена accent-border.
   - Одна первичная CTA на карточку: «Start free» (ghost/outlined) и «Go Premium» (accent fill).
6. **Footer:** вордмарк + tagline, links (App Store · Google Play · Web App · Privacy · Terms · Contact),
   `© 2026 Kaizen`. **СОХРАНИТЬ строку: «Самозанятый Лунёв А. А. · ИНН 772792313532»** (требование
   ЮKassa, не удалять). Email-плейсхолдер оставить.

## Smart Download/Open кнопка (Alpine)
Сохранить определение платформы (iOS/Android/web → store/web-app). Плейсхолдер-URL оставить с TODO.
На web-кнопке текст «Open app», на мобиле «Get the app».

## Legal pages (privacy.html, terms.html)
Переоформить под Day-тему теми же токенами (bg/surface/ink/border, Geist, hairline, R14/16).
Контент НЕ переписывать. Футер с **ИНН — сохранить**. Кнопка «Back to Kaizen» → вордмарк «Kaname».

## Анти-регресс / приёмка
- 320px без горизонтального скролла; responsive sm/md/lg; tap-таргеты ≥44px.
- Контраст AA (ink/secondary на bg/surface). `prefers-reduced-motion` отключает анимации.
- Lighthouse a11y/perf не хуже текущего; только CDN, без сборки.
- Все 3 страницы консистентны; ИНН-строка на каждой.
- Английский для всего пользовательского текста (RU только юридическая ИНН-строка).

## Раздача агентам
- **L1 — index.html** (главная, один файл — один агент): Tailwind-конфиг токенов + хедер + hero +
  problem/solution + features + pricing(исправить рекламу) + footer(сохранить ИНН) + Alpine-кнопка.
- **L2 — legal** (параллельно L1, другие файлы): privacy.html + terms.html под токены.
- Деплой на живой сайт = перенести готовый лендинг в `main` (cherry-pick/merge), Pages соберёт.
