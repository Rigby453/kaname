# QA Tasks — MVP

> Run with: `npx jest --runInBand` (serial — shares test DB)
> Setup: `DATABASE_URL_TEST` in `.env.test`, mock `backend/src/ai/`

---

## QA-01: Auth flow
`tests/integration/auth.test.ts`

```
✓ POST /register → 201, returns { access_token, user: { id, email, name } }
✓ POST /register same email → 409 { error: "Email already exists" }
✓ POST /register no email → 400 (zod validation)
✓ POST /login correct → 200, returns JWT
✓ POST /login wrong password → 401
✓ POST /login unknown email → 401
✓ GET /me with valid JWT → 200, user object (no passwordHash field)
✓ GET /me without JWT → 401
✓ GET /me expired JWT → 401
```

## QA-02: Items CRUD
`tests/integration/items.test.ts`

```
✓ POST /items → 201, returns Item with id
✓ POST /items priority=main → is_protected=true in response
✓ POST /items without title → 400
✓ GET /items?from=&to= → only items in date range
✓ GET /items another user's token → returns empty (not 403 — user sees nothing)
✓ PATCH /items/:id title → updated in response
✓ PATCH /items/:id status=done → status updated
✓ PATCH /items/:id other user's item → 404
✓ DELETE /items/:id → 204
✓ DELETE /items/:id again → 404
✓ DELETE /items/:id other user's item → 404
```

## QA-03: Streaks
`tests/unit/streak-logic.test.ts`

```
Setup: helper createTestUser(), createMainItem(userId, date, status)

✓ All main items done for today → streak.current increments by 1
✓ Some main items pending → streak NOT updated
✓ No main items today → streak NOT updated (no main = no requirement)
✓ streak.longest updates when current > longest
✓ Consecutive days: complete today after completing yesterday → streak += 1
✓ Miss a day, freeze_count=1 → streak stays, freeze_count becomes 0
✓ Miss a day, freeze_count=0 → streak resets to 1 (not 0, because completing today counts)
✓ streak.lastCompletedDate = today after completion
```

## QA-04: Redistribution engine
`tests/unit/engine.test.ts`

```
✓ 3 pending items [main, high, low] → proposed order: main first, then high, then low
✓ is_protected=true item → appears in skipped[], not proposed[]
✓ Enough free slots → all non-protected items in proposed[]
✓ No free slots → all items in skipped[] (or appended at end of day)
✓ Empty pending → { proposed: [], skipped: [] }
✓ Mix protected + non-protected → protected in skipped, rest in proposed by priority
✓ proposed items have valid scheduledAt in target day
✓ proposed items do not overlap with existing items
```

## QA-05: Sync conflict resolution
`tests/integration/sync.test.ts`

```
Setup: create user, create item on server

✓ Local item (same id), updatedAt newer than server → server item gets updated to local version
✓ Server item updated after local version → response contains server version, client should use it
✓ Local item id doesn't exist on server → created on server, returned in updated_items
✓ Sync with empty items array → returns server-side new items since last_sync_at
✓ Sync without auth → 401
✓ last_sync_at in future → no server changes returned
```

---

## Test helpers to create
`tests/helpers/`

```typescript
// auth-helper.ts
export async function registerAndLogin(app): Promise<string> // returns JWT

// item-helper.ts
export async function createItem(app, jwt, overrides): Promise<Item>

// streak-helper.ts  
export async function completeAllMainItems(app, jwt, date): Promise<void>
```

---

## Definition of done
All 5 test suites pass on clean DB.
`npx jest --coverage` shows ≥80% coverage on `src/engine/`.
No real Claude API calls in any test (ai/ fully mocked).
