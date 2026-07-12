# Kaname («Главное»)

A planner for students that re-assembles the day around what actually matters —
and helps you understand *why* plans fail. Unfinished tasks auto-carry over and
get re-prioritised **with your confirmation** (rule-based and free; AI-smarter on
the paid tier).

> Working title: **«Главное»** (RU). **Kaname** is the codename used in code and packages.

## Stack
- **App** — Flutter 3 / Dart 3 (iOS · Android · Web), offline-first via Drift (SQLite),
  Riverpod, go_router.
- **Backend** — Node.js 22 / Fastify 4 / Prisma 5 / PostgreSQL, JWT auth.
- **AI** (paid features) — backend-only, provider-abstracted: Gemini or Claude by `.env`.
- **Landing** — single static `index.html`.

## Status
MVP + Phase 1 (paid contour) + Phase 2 (workouts, sleep, breathing, posture) closed.
Phase 3 sharing (web links, "shared with me"), co-study and long-term goals done.
Tests green — see [docs/STATUS.md](docs/STATUS.md).

## Structure
| Folder | What |
|---|---|
| `app/` | Flutter app — screens, themes, offline DB, sync |
| `backend/` | Fastify API — auth, items, sync, rule engine, AI endpoints |
| `landing/` | Marketing landing page |
| `tests/` | Backend integration + unit tests |
| `docs/` | Spec, API contract, data model, design tokens, ADRs, status board |

## Getting started
See **[docs/SETUP-IDE.md](docs/SETUP-IDE.md)** for SDKs, first-run commands and per-IDE
extensions. Quick version:

```bash
# backend  (needs backend/.env — not in git)
cd backend && npm install && npm run dev

# app
cd app && flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

## Docs map
- Product spec → [docs/SPEC.md](docs/SPEC.md)
- File-by-file map → [docs/PROJECT-MAP.md](docs/PROJECT-MAP.md)
- Status / backlog → [docs/STATUS.md](docs/STATUS.md)
- Architecture decisions → [docs/decisions.md](docs/decisions.md)

## License
Proprietary — all rights reserved. Not licensed for reuse.
