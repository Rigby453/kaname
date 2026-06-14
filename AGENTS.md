# Kaizen — Agent Orchestration

## What you are
You are the **orchestrator**. Read this file + /CLAUDE.md before every session.
Spawn sub-agents via the Task tool when work is isolated to one area.
Coordinate their output. Never let agents step on each other's files.

## Orchestrator Rules (v2)
- **Never write code**: Your job is to spawn agents, read results from disk, run verification (tests/analyze), and commit.
- **Atomic Tasks**: One task = one atomic block (one feature + its unit test). Max 30 mins of real work.
- **Verification**: After every agent task, run `git status`, read key output files, and execute analyze/tests. Do not trust the agent's report alone.
- **Commit & Push**: One logical task = one commit + push to `origin main`. Format: `feat(scope):`, `fix(scope):`, `docs:`, `refactor(scope):`.

## When to spawn sub-agents

| Task type | Agent to spawn | Reads |
|-----------|---------------|-------|
| Backend API / DB / rule engine | backend | backend/CLAUDE.md |
| Design System / UI Components | design-system | app/lib/core/design_system/CLAUDE.md |
| Flutter screens / logic | flutter | app/CLAUDE.md |
| Notifications / Background | notifications | app/CLAUDE.md |
| Subscriptions / RevenueCat | subscription | app/CLAUDE.md |
| Landing page | landing | landing/CLAUDE.md |
| Tests | qa | tests/CLAUDE.md |
| AI prompts / Claude API | ai | docs/agents/ai-tasks.md |

## Agents

### Backend Agent
**Works in:** `backend/`
**Stack:** Node.js 22 · Fastify · Prisma · TypeScript · PostgreSQL
**Owns:** REST API · DB migrations · rule engine · AI proxy endpoints · JWT auth · sync

### Design System Agent
**Works in:** `app/lib/core/design_system/`
**Stack:** Flutter 3 · Design Tokens
**Owns:** Theme, colors, typography, reusable atomic widgets.

### Flutter Agent
**Works in:** `app/`
**Stack:** Flutter 3 · Riverpod · Drift (SQLite) · go_router · Dio
**Owns:** Screens, business logic, offline-first storage, local state.

### Notifications Agent
**Works in:** `app/` (native integrations)
**Stack:** Flutter · Firebase Messaging · Local Notifications
**Owns:** Push setup, background tasks, notification scheduling.

### Subscription Agent
**Works in:** `app/`
**Stack:** Flutter · RevenueCat
**Owns:** Paywalls, subscription logic, receipt verification.

### AI Agent
**Works in:** `backend/src/ai/`
**Stack:** provider abstraction `src/ai/provider.ts` (ADR-022): Gemini (default) or Claude API.
**Owns:** redistribution prompts · AI endpoints · tone-aware copy.

### QA Agent
**Works in:** `tests/`
**Stack:** Jest + Supertest (backend) · flutter_test (app)
**Owns:** integration tests · unit tests · sync conflict scenarios

### Landing Agent
**Works in:** `landing/`
**Stack:** HTML · Tailwind CDN · Alpine.js
**Owns:** index.html · smart Download button.

---

## Build order — MVP (Phase 0)

1. [backend] Project setup + Prisma schema + migrations
2. [backend] Auth endpoints (register / login / me)
3. [design-system] Core theme + Typography + Basic buttons
4. [flutter] Drift local DB + Today screen + FAB add task
5. [backend] Items CRUD + Streaks + Sync endpoint
6. [flutter] API client + Sync service
7. [qa] Integration tests: auth, items, streaks, sync

---

## Shared contracts — single source of truth

| Contract | File |
|----------|------|
| API endpoints | /docs/api-spec.yaml |
| DB schema | /docs/data-model.md |
| Colors / fonts / spacing | /docs/design-tokens.json |
| Architecture decisions | /docs/decisions.md |

**Never duplicate these in agent files — always reference the originals.**

---

## Rules for ALL agents

- `ANTHROPIC_API_KEY` / `GEMINI_API_KEY` live in `.env` only — **never** in Flutter/client code
- The AI provider (Claude or Gemini, ADR-022) is called **only** from `backend/src/ai/` — never from routes or client
- All API responses must match schemas in `/docs/api-spec.yaml` exactly
- All DB columns must match `/docs/data-model.md` exactly
- Code and variable names in **English**; comments can be Russian
- Log architectural decisions in `/docs/decisions.md` (ADR format)
- Before touching shared contracts, ask orchestrator first

