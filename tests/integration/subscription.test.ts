/**
 * Subscription dev-upgrade (non-production only): flips subscription_tier so
 * premium features (AI) can be tested before real payments exist.
 */
import { buildServer } from '../../backend/src/app';
import type { FastifyInstance } from 'fastify';
import { registerUser, cleanupUser } from '../helpers';

let app: FastifyInstance;
const userIds: string[] = [];

beforeAll(async () => {
  app = await buildServer();
  await app.ready();
});

afterAll(async () => {
  for (const id of userIds) await cleanupUser(id);
  await app.close();
});

async function devUpgrade(token: string, body: Record<string, unknown>) {
  return app.inject({
    method: 'POST',
    url: '/api/v1/subscription/dev-upgrade',
    headers: { Authorization: `Bearer ${token}` },
    payload: body,
  });
}

test('dev-upgrade → user becomes premium (and /me reflects it)', async () => {
  const user = await registerUser(app);
  userIds.push(user.userId);

  const res = await devUpgrade(user.token, { tier: 'premium' });
  expect(res.statusCode).toBe(200);
  expect(res.json<{ subscription_tier: string }>().subscription_tier).toBe('premium');

  const me = await app.inject({
    method: 'GET',
    url: '/api/v1/auth/me',
    headers: { Authorization: `Bearer ${user.token}` },
  });
  expect(me.json<{ subscription_tier: string }>().subscription_tier).toBe('premium');
});

test('dev-upgrade defaults to premium when tier omitted', async () => {
  const user = await registerUser(app);
  userIds.push(user.userId);

  const res = await devUpgrade(user.token, {});
  expect(res.statusCode).toBe(200);
  expect(res.json<{ subscription_tier: string }>().subscription_tier).toBe('premium');
});

test('dev-upgrade can downgrade back to free', async () => {
  const user = await registerUser(app);
  userIds.push(user.userId);

  await devUpgrade(user.token, { tier: 'premium' });
  const res = await devUpgrade(user.token, { tier: 'free' });
  expect(res.statusCode).toBe(200);
  expect(res.json<{ subscription_tier: string }>().subscription_tier).toBe('free');
});

test('dev-upgrade without auth → 401', async () => {
  const res = await app.inject({
    method: 'POST',
    url: '/api/v1/subscription/dev-upgrade',
    payload: { tier: 'premium' },
  });
  expect(res.statusCode).toBe(401);
});
