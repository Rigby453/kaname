/**
 * Phase 1: AI photo schedule-import — premium gating + response shape.
 * backend/src/ai/ полностью замокан — реальных вызовов Claude нет (правило QA).
 */
import { buildServer } from '../../backend/src/app';
import type { FastifyInstance } from 'fastify';
import prisma from '../../backend/src/models/prisma';
import { registerUser, cleanupUser } from '../helpers';

// Мокаем AI-модуль: importScheduleFromPhoto возвращает детерминированный результат.
jest.mock('../../backend/src/ai/scheduleImport', () => ({
  importScheduleFromPhoto: jest.fn().mockResolvedValue({
    items: [
      { title: 'Math lecture', scheduledAt: '2026-06-10T09:00:00.000Z' },
      { title: 'Gym', scheduledAt: '2026-06-10T14:30:00.000Z' },
    ],
  }),
}));

let app: FastifyInstance;
const userIds: string[] = [];

const body = {
  image_base64: 'ZmFrZS1pbWFnZQ==',
  media_type: 'image/png',
  target_date: '2026-06-10',
};

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

test('free user → 403 (premium feature)', async () => {
  const user = await registerUser(app);
  userIds.push(user.userId);
  const res = await app.inject({
    method: 'POST',
    url: '/api/v1/ai/schedule-import',
    headers: { Authorization: `Bearer ${user.token}` },
    payload: body,
  });
  expect(res.statusCode).toBe(403);
});

test('premium user → 200 with snake_case items from the (mocked) AI module', async () => {
  const user = await registerUser(app);
  userIds.push(user.userId);
  // Повышаем до premium напрямую в БД (платежей в MVP нет)
  await prisma.user.update({
    where: { id: user.userId },
    data: { subscriptionTier: 'premium' },
  });

  const res = await app.inject({
    method: 'POST',
    url: '/api/v1/ai/schedule-import',
    headers: { Authorization: `Bearer ${user.token}` },
    payload: body,
  });
  expect(res.statusCode).toBe(200);
  const parsed = res.json<{ items: Array<{ title: string; scheduled_at: string }> }>();
  expect(parsed.items).toHaveLength(2);
  expect(parsed.items[0]?.title).toBe('Math lecture');
  expect(parsed.items[0]?.scheduled_at).toBe('2026-06-10T09:00:00.000Z');
});

test('no auth → 401', async () => {
  const res = await app.inject({
    method: 'POST',
    url: '/api/v1/ai/schedule-import',
    payload: body,
  });
  expect(res.statusCode).toBe(401);
});

test('premium user, missing image → 400', async () => {
  const user = await registerUser(app);
  userIds.push(user.userId);
  await prisma.user.update({
    where: { id: user.userId },
    data: { subscriptionTier: 'premium' },
  });
  const res = await app.inject({
    method: 'POST',
    url: '/api/v1/ai/schedule-import',
    headers: { Authorization: `Bearer ${user.token}` },
    payload: { media_type: 'image/png', target_date: '2026-06-10' },
  });
  expect(res.statusCode).toBe(400);
});
