# GLAVNOE — MVP Board

> Lightweight status board. Orchestrator updates checkboxes as work lands.
> Statuses: `[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked
> Full task detail lives in `/docs/agents/*-tasks.md`.

## Foundations (do first — everyone depends on these)
- [x] Product spec — `docs/SPEC.md`
- [x] Data model + Prisma — `docs/data-model.md`
- [x] API contract — `docs/api-spec.yaml`
- [x] Design tokens — `docs/design-tokens.json`
- [x] Orchestration + agent guides — `AGENTS.md`, `*/CLAUDE.md`

## Backend (see docs/agents/backend-tasks.md)
- [ ] SETUP-01 Project scaffolding (Fastify + TS)
- [ ] SETUP-02 Prisma schema + migration
- [ ] SETUP-03 Fastify server + health check
- [ ] AUTH-01..04 Register / Login / JWT middleware / Me
- [ ] ITEMS-01..04 CRUD + ownership
- [ ] STREAK-01..02 Get streak + update helper
- [ ] SYNC-01 Sync endpoint (last-write-wins)
- [ ] ENGINE-01 Rule redistribution (POST /api/v1/redistribute)

## Flutter (see docs/agents/flutter-tasks.md)
- [ ] FL-SETUP-01..03 Project + Focus theme + 4-tab nav (profile = AppBar leading)
- [ ] FL-DB-01..02 Drift schema + DAOs
- [ ] FL-TODAY-01..05 Today screen (ring, streak, list, add sheet)
- [ ] FL-PLAN-01..02 Week strip + day timeline
- [ ] FL-DIARY-01 Diary form
- [ ] FL-API-01 / FL-SYNC-01 Dio client + sync service
- [ ] Themes Black + White; schedule import (template/photo/paste/voice); home widget

## QA (see docs/agents/qa-tasks.md)
- [ ] QA-01 Auth flow
- [ ] QA-02 Items CRUD
- [ ] QA-03 Streaks
- [ ] QA-04 Redistribution engine
- [ ] QA-05 Sync conflict resolution
- [ ] DoD: all suites pass, ≥80% coverage on src/engine/, ai/ fully mocked

## Landing (see landing/CLAUDE.md)
- [ ] index.html — hero, problem/solution, features, pricing, footer
- [ ] Smart [Download] button (platform detection)

## AI — Phase 1 (not MVP; see docs/agents/ai-tasks.md)
- [ ] AI-01 Smart redistribute · AI-02 morning message · AI-03 food photo · AI-04 diary insight · AI-05 weekly wrapped

## MVP Definition of Done
A free, no-AI app you use daily: accounts + sync, Today/Plan/Diary, rule-based review
(morning + evening + variants), schedule import, streaks + freeze, onboarding,
themes Focus/Black/White, home widget. All QA suites green.
