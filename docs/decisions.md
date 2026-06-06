# Architecture Decision Records — GLAVNOE

> Append here whenever you make a significant architectural choice.
> Format: ## ADR-NNN: Title | Date | Decision | Reason

---

## ADR-001: Flutter for all platforms
**Date:** 2025-01
**Decision:** Flutter (iOS + Android + Web) over React Native or separate codebases
**Reason:** Single codebase, strong offline support via Drift, good animation control for themes

## ADR-002: Claude API models
**Date:** 2025-01
**Decision:** Haiku 4.5 for bulk/frequent, Sonnet 4.6 for complex reasoning
**Reason:** Cost balance — Haiku is 3× cheaper, sufficient for morning messages and food ID; Sonnet for redistribution reasoning and diary insights

## ADR-003: Offline-first with Drift
**Date:** 2025-01
**Decision:** Write to local SQLite (Drift) first, sync to backend async
**Reason:** Students use app in lecture halls with poor connectivity; data must never be lost

## ADR-004: Last-write-wins sync
**Date:** 2025-01
**Decision:** Sync conflict resolution = newer updatedAt wins
**Reason:** Simple to implement for MVP; revisit if users report data loss (Phase 2)

## ADR-005: Redistribution is proposals only
**Date:** 2025-01
**Decision:** Engine returns proposed changes; user must confirm before items are moved
**Reason:** Autonomy is core to the product — the app suggests, the user decides

## ADR-006: Claude API key on backend only
**Date:** 2025-01
**Decision:** Flutter client never calls Claude API directly — always via backend proxy endpoints
**Reason:** Security (key exposure), rate limiting, cost control, ability to add caching/batching

## ADR-007: Rule-based redistribution endpoint
**Date:** 2026-06
**Decision:** Expose the MVP rule engine as `POST /api/v1/redistribute` returning `{ proposed, skipped }` (proposals only, nothing saved). The premium AI variant is `POST /api/v1/ai/redistribute`.
**Reason:** The task files defined the engine logic but no REST endpoint for the client to fetch proposals. The Today morning-review UI needs one. Kept separate from the AI endpoint so the free tier works without AI.

## ADR-008: API payloads use snake_case
**Date:** 2026-06
**Decision:** All API request/response fields use snake_case (e.g. `scheduled_at`, `is_protected`, `access_token`, `updated_items`). Prisma models stay camelCase internally and are mapped at the route boundary.
**Reason:** The task-file examples already use snake_case; `api-spec.yaml` codifies it as the single source of truth to avoid client/server drift.

---

<!-- Add new ADRs below this line -->
