/**
 * QA-CORS: CORS allowlist в production-режиме (ADR-045)
 *
 * Покрывает:
 *  - без origin → всегда разрешено
 *  - localhost origin → всегда разрешено
 *  - dev-режим (NODE_ENV !== production) → всегда разрешено
 *  - production + origin в ALLOWED_ORIGINS → разрешено
 *  - production + origin НЕ в ALLOWED_ORIGINS → отклонено (нет заголовка)
 *  - production + пустой ALLOWED_ORIGINS → отклонено
 */
import { buildServer } from '../../backend/src/app';
import type { FastifyInstance } from 'fastify';

// Сохраняем оригинальные значения env перед тестами
const ORIGINAL_NODE_ENV = process.env['NODE_ENV'];
const ORIGINAL_ALLOWED_ORIGINS = process.env['ALLOWED_ORIGINS'];

afterAll(() => {
  // Восстанавливаем env
  process.env['NODE_ENV'] = ORIGINAL_NODE_ENV;
  if (ORIGINAL_ALLOWED_ORIGINS === undefined) {
    delete process.env['ALLOWED_ORIGINS'];
  } else {
    process.env['ALLOWED_ORIGINS'] = ORIGINAL_ALLOWED_ORIGINS;
  }
});

// Хелпер: создаём сервер с нужными env-переменными
async function makeServer(nodeEnv: string, allowedOrigins?: string): Promise<FastifyInstance> {
  process.env['NODE_ENV'] = nodeEnv;
  if (allowedOrigins === undefined) {
    delete process.env['ALLOWED_ORIGINS'];
  } else {
    process.env['ALLOWED_ORIGINS'] = allowedOrigins;
  }
  const app = await buildServer();
  await app.ready();
  return app;
}

// Хелпер: делаем preflight OPTIONS запрос с заданным Origin
async function preflight(app: FastifyInstance, origin: string | undefined) {
  return app.inject({
    method: 'OPTIONS',
    url: '/health',
    headers: origin
      ? {
          Origin: origin,
          'Access-Control-Request-Method': 'GET',
        }
      : {
          'Access-Control-Request-Method': 'GET',
        },
  });
}

// ─── Тесты: не-production-режим ──────────────────────────────────────────────

describe('CORS — non-production (NODE_ENV=test)', () => {
  let app: FastifyInstance;

  beforeAll(async () => {
    app = await makeServer('test', undefined);
  });

  afterAll(async () => {
    await app.close();
  });

  test('любой внешний origin разрешён в dev/test', async () => {
    const res = await preflight(app, 'https://some-random-domain.com');
    // Fastify CORS ставит Access-Control-Allow-Origin при разрешении
    expect(res.headers['access-control-allow-origin']).toBe('https://some-random-domain.com');
  });

  test('localhost разрешён', async () => {
    const res = await preflight(app, 'http://localhost:3000');
    expect(res.headers['access-control-allow-origin']).toBe('http://localhost:3000');
  });
});

// ─── Тесты: production-режим + непустой allowlist ────────────────────────────

describe('CORS — production + ALLOWED_ORIGINS задан', () => {
  let app: FastifyInstance;
  const ALLOWED = 'https://rigby453.github.io,https://example.com';

  beforeAll(async () => {
    app = await makeServer('production', ALLOWED);
  });

  afterAll(async () => {
    await app.close();
  });

  test('origin в allowlist → разрешён', async () => {
    const res = await preflight(app, 'https://rigby453.github.io');
    expect(res.headers['access-control-allow-origin']).toBe('https://rigby453.github.io');
  });

  test('второй origin в allowlist → разрешён', async () => {
    const res = await preflight(app, 'https://example.com');
    expect(res.headers['access-control-allow-origin']).toBe('https://example.com');
  });

  test('origin НЕ в allowlist → нет заголовка Allow-Origin', async () => {
    const res = await preflight(app, 'https://evil-site.com');
    expect(res.headers['access-control-allow-origin']).toBeUndefined();
  });

  test('localhost → разрешён даже в production', async () => {
    const res = await preflight(app, 'http://localhost:8080');
    expect(res.headers['access-control-allow-origin']).toBe('http://localhost:8080');
  });

  test('без origin → ответ без CORS-заголовка (не заблокирован)', async () => {
    const res = await preflight(app, undefined);
    // Запрос без origin не режется — просто нет CORS-заголовка
    expect(res.statusCode).not.toBe(403);
  });
});

// ─── Тесты: production-режим + пустой allowlist ──────────────────────────────

describe('CORS — production + ALLOWED_ORIGINS пустой', () => {
  let app: FastifyInstance;

  beforeAll(async () => {
    app = await makeServer('production', '');
  });

  afterAll(async () => {
    await app.close();
  });

  test('любой внешний origin → нет заголовка Allow-Origin', async () => {
    const res = await preflight(app, 'https://rigby453.github.io');
    expect(res.headers['access-control-allow-origin']).toBeUndefined();
  });

  test('localhost → по-прежнему разрешён', async () => {
    const res = await preflight(app, 'http://localhost:5000');
    expect(res.headers['access-control-allow-origin']).toBe('http://localhost:5000');
  });
});
