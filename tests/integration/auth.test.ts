/**
 * QA-01: Auth flow — регистрация, вход, /me
 */
import { buildServer } from '../../backend/src/app';
import type { FastifyInstance } from 'fastify';
import { randomEmail, cleanupUser } from '../helpers';

let app: FastifyInstance;
// Список userId для очистки после всех тестов
const userIdsToCleanup: string[] = [];

beforeAll(async () => {
  app = await buildServer();
  await app.ready();
});

afterAll(async () => {
  // Очищаем всех созданных пользователей
  for (const userId of userIdsToCleanup) {
    await cleanupUser(userId);
  }
  await app.close();
});

describe('POST /api/v1/auth/register', () => {
  test('register → 201, returns { access_token, user: { id, email, name } }', async () => {
    const email = randomEmail();
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/register',
      payload: { email, password: 'TestPass1!', name: 'Alice' },
    });

    expect(res.statusCode).toBe(201);
    const body = res.json<{ access_token: string; user: { id: string; email: string; name: string } }>();
    expect(typeof body.access_token).toBe('string');
    expect(body.access_token.length).toBeGreaterThan(0);
    expect(body.user.id).toBeDefined();
    expect(body.user.email).toBe(email);
    expect(body.user.name).toBe('Alice');
    // passwordHash никогда не должен утекать
    expect((body.user as Record<string, unknown>)['passwordHash']).toBeUndefined();
    expect((body.user as Record<string, unknown>)['password_hash']).toBeUndefined();

    userIdsToCleanup.push(body.user.id);
  });

  test('duplicate email → 409 { error: "Email already exists" }', async () => {
    const email = randomEmail();

    // Первая регистрация
    const first = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/register',
      payload: { email, password: 'TestPass1!', name: 'Alice' },
    });
    expect(first.statusCode).toBe(201);
    const firstBody = first.json<{ user: { id: string } }>();
    userIdsToCleanup.push(firstBody.user.id);

    // Дубликат
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/register',
      payload: { email, password: 'AnotherPass1!', name: 'Bob' },
    });
    expect(res.statusCode).toBe(409);
    const body = res.json<{ error: string }>();
    expect(body.error).toBe('Email already exists');
  });

  test('missing email → 400 (zod validation)', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/register',
      payload: { password: 'TestPass1!', name: 'Charlie' },
    });
    expect(res.statusCode).toBe(400);
    const body = res.json<{ error: string }>();
    expect(typeof body.error).toBe('string');
  });
});

describe('POST /api/v1/auth/login', () => {
  // Регистрируем одного пользователя для всей группы login-тестов
  let loginEmail: string;
  const loginPassword = 'LoginPass1!';

  beforeAll(async () => {
    loginEmail = randomEmail();
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/register',
      payload: { email: loginEmail, password: loginPassword, name: 'Login User' },
    });
    const body = res.json<{ user: { id: string } }>();
    userIdsToCleanup.push(body.user.id);
  });

  test('login correct → 200, returns JWT', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/login',
      payload: { email: loginEmail, password: loginPassword },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json<{ access_token: string; user: { email: string } }>();
    expect(typeof body.access_token).toBe('string');
    expect(body.access_token.length).toBeGreaterThan(0);
    expect(body.user.email).toBe(loginEmail);
  });

  test('login wrong password → 401', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/login',
      payload: { email: loginEmail, password: 'WrongPassword!' },
    });
    expect(res.statusCode).toBe(401);
  });

  test('login unknown email → 401', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/login',
      payload: { email: 'nonexistent@example.com', password: 'AnyPass123!' },
    });
    expect(res.statusCode).toBe(401);
  });
});

describe('GET /api/v1/auth/me', () => {
  let token: string;
  let userId: string;
  let userEmail: string;

  beforeAll(async () => {
    userEmail = randomEmail();
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/register',
      payload: { email: userEmail, password: 'MePass1234!', name: 'Me User' },
    });
    const body = res.json<{ access_token: string; user: { id: string } }>();
    token = body.access_token;
    userId = body.user.id;
    userIdsToCleanup.push(userId);
  });

  test('valid JWT → 200, user object (no passwordHash field)', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/auth/me',
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json<Record<string, unknown>>();
    expect(body['id']).toBe(userId);
    expect(body['email']).toBe(userEmail);
    expect(body['name']).toBe('Me User');
    // passwordHash не должен присутствовать
    expect(body['passwordHash']).toBeUndefined();
    expect(body['password_hash']).toBeUndefined();
  });

  test('no token → 401', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/auth/me',
    });
    expect(res.statusCode).toBe(401);
  });

  test('garbage token → 401', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/auth/me',
      headers: { Authorization: 'Bearer thisisnotavalidjwt' },
    });
    expect(res.statusCode).toBe(401);
  });
});
