/**
 * QA-02: Items CRUD + ownership + date filters.
 */
import { buildServer } from '../../backend/src/app';
import type { FastifyInstance } from 'fastify';
import { registerUser, createItem, cleanupUser } from '../helpers';

let app: FastifyInstance;
const userIds: string[] = [];

beforeAll(async () => {
  app = await buildServer();
  await app.ready();
});

afterAll(async () => {
  for (const id of userIds) {
    await cleanupUser(id);
  }
  await app.close();
});

describe('POST /api/v1/items', () => {
  test('create task → 201 with id, is_protected=false by default', async () => {
    const user = await registerUser(app);
    userIds.push(user.userId);
    const item = await createItem(app, user.token, { title: 'Buy milk' });
    expect(item.id).toBeDefined();
    expect(item.title).toBe('Buy milk');
    expect(item.is_protected).toBe(false);
  });

  test('priority=main → is_protected forced true', async () => {
    const user = await registerUser(app);
    userIds.push(user.userId);
    const item = await createItem(app, user.token, {
      title: 'Final exam',
      priority: 'main',
    });
    expect(item.priority).toBe('main');
    expect(item.is_protected).toBe(true);
  });

  test('missing title → 400', async () => {
    const user = await registerUser(app);
    userIds.push(user.userId);
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/items',
      headers: { Authorization: `Bearer ${user.token}` },
      payload: { type: 'task', scheduled_at: new Date().toISOString() },
    });
    expect(res.statusCode).toBe(400);
  });
});

describe('GET /api/v1/items', () => {
  test('date range returns only items inside the range', async () => {
    const user = await registerUser(app);
    userIds.push(user.userId);
    const inRange = await createItem(app, user.token, {
      title: 'In range',
      scheduled_at: '2026-06-15T10:00:00.000Z',
    });
    await createItem(app, user.token, {
      title: 'Out of range',
      scheduled_at: '2026-06-20T10:00:00.000Z',
    });

    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/items?from=2026-06-15T00:00:00.000Z&to=2026-06-15T23:59:59.000Z',
      headers: { Authorization: `Bearer ${user.token}` },
    });
    expect(res.statusCode).toBe(200);
    const items = res.json<Array<{ id: string }>>();
    const ids = items.map((i) => i.id);
    expect(ids).toContain(inRange.id);
    expect(ids).toHaveLength(1);
  });

  test("another user's token sees none of the first user's items", async () => {
    const owner = await registerUser(app);
    userIds.push(owner.userId);
    await createItem(app, owner.token, { title: 'Private' });

    const other = await registerUser(app);
    userIds.push(other.userId);
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/items',
      headers: { Authorization: `Bearer ${other.token}` },
    });
    expect(res.statusCode).toBe(200);
    expect(res.json<unknown[]>()).toEqual([]);
  });
});

describe('PATCH /api/v1/items/:id', () => {
  test('update title → reflected in response', async () => {
    const user = await registerUser(app);
    userIds.push(user.userId);
    const item = await createItem(app, user.token, { title: 'Old' });
    const res = await app.inject({
      method: 'PATCH',
      url: `/api/v1/items/${item.id}`,
      headers: { Authorization: `Bearer ${user.token}` },
      payload: { title: 'New' },
    });
    expect(res.statusCode).toBe(200);
    expect(res.json<{ title: string }>().title).toBe('New');
  });

  test('status=done → updated', async () => {
    const user = await registerUser(app);
    userIds.push(user.userId);
    const item = await createItem(app, user.token, { title: 'Do it' });
    const res = await app.inject({
      method: 'PATCH',
      url: `/api/v1/items/${item.id}`,
      headers: { Authorization: `Bearer ${user.token}` },
      payload: { status: 'done' },
    });
    expect(res.statusCode).toBe(200);
    expect(res.json<{ status: string }>().status).toBe('done');
  });

  test("another user's item → 404", async () => {
    const owner = await registerUser(app);
    userIds.push(owner.userId);
    const item = await createItem(app, owner.token, { title: 'Owned' });

    const other = await registerUser(app);
    userIds.push(other.userId);
    const res = await app.inject({
      method: 'PATCH',
      url: `/api/v1/items/${item.id}`,
      headers: { Authorization: `Bearer ${other.token}` },
      payload: { title: 'hacked' },
    });
    expect(res.statusCode).toBe(404);
  });
});

describe('DELETE /api/v1/items/:id', () => {
  test('delete → 204, then second delete → 404', async () => {
    const user = await registerUser(app);
    userIds.push(user.userId);
    const item = await createItem(app, user.token, { title: 'Temp' });

    const first = await app.inject({
      method: 'DELETE',
      url: `/api/v1/items/${item.id}`,
      headers: { Authorization: `Bearer ${user.token}` },
    });
    expect(first.statusCode).toBe(204);

    const second = await app.inject({
      method: 'DELETE',
      url: `/api/v1/items/${item.id}`,
      headers: { Authorization: `Bearer ${user.token}` },
    });
    expect(second.statusCode).toBe(404);
  });

  test("another user's item → 404", async () => {
    const owner = await registerUser(app);
    userIds.push(owner.userId);
    const item = await createItem(app, owner.token, { title: 'Owned' });

    const other = await registerUser(app);
    userIds.push(other.userId);
    const res = await app.inject({
      method: 'DELETE',
      url: `/api/v1/items/${item.id}`,
      headers: { Authorization: `Bearer ${other.token}` },
    });
    expect(res.statusCode).toBe(404);
  });
});
