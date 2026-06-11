/**
 * SHARE-01..05: Web share links (Ф3, ADR-030).
 * JWT-подписанные ссылки, без новой таблицы.
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

describe('POST /api/v1/share', () => {
  test('(а) без авторизации → 401', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/share',
      payload: {
        from: '2026-06-10T00:00:00.000Z',
        to: '2026-06-17T00:00:00.000Z',
      },
    });
    expect(res.statusCode).toBe(401);
  });

  test('(б) с авторизацией → 200, token строка, url содержит /share/', async () => {
    const user = await registerUser(app);
    userIds.push(user.userId);

    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/share',
      headers: { Authorization: `Bearer ${user.token}` },
      payload: {
        from: '2026-06-10T00:00:00.000Z',
        to: '2026-06-17T00:00:00.000Z',
      },
    });
    expect(res.statusCode).toBe(200);
    const body = res.json<{ token: string; url: string }>();
    expect(typeof body.token).toBe('string');
    expect(body.token.length).toBeGreaterThan(10);
    expect(body.url).toContain('/share/');
    expect(body.url).toContain(body.token);
  });

  test('to <= from → 400', async () => {
    const user = await registerUser(app);
    userIds.push(user.userId);

    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/share',
      headers: { Authorization: `Bearer ${user.token}` },
      payload: {
        from: '2026-06-17T00:00:00.000Z',
        to: '2026-06-10T00:00:00.000Z',
      },
    });
    expect(res.statusCode).toBe(400);
  });

  test('диапазон > 31 дня → 400', async () => {
    const user = await registerUser(app);
    userIds.push(user.userId);

    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/share',
      headers: { Authorization: `Bearer ${user.token}` },
      payload: {
        from: '2026-06-01T00:00:00.000Z',
        to: '2026-08-01T00:00:00.000Z',
      },
    });
    expect(res.statusCode).toBe(400);
  });
});

describe('GET /api/v1/share/:token', () => {
  test('(в) JSON-ответ: owner_name совпадает, items содержит задачу, у item нет поля id', async () => {
    const user = await registerUser(app);
    userIds.push(user.userId);

    // Создаём задачу внутри диапазона
    const from = '2026-06-10T00:00:00.000Z';
    const to = '2026-06-17T00:00:00.000Z';
    await createItem(app, user.token, {
      title: 'Shared task',
      scheduled_at: '2026-06-12T09:00:00.000Z',
    });

    // Создаём задачу ВНЕ диапазона — не должна попасть
    await createItem(app, user.token, {
      title: 'Outside range',
      scheduled_at: '2026-06-20T09:00:00.000Z',
    });

    // Получаем share-токен
    const shareRes = await app.inject({
      method: 'POST',
      url: '/api/v1/share',
      headers: { Authorization: `Bearer ${user.token}` },
      payload: { from, to },
    });
    expect(shareRes.statusCode).toBe(200);
    const { token } = shareRes.json<{ token: string; url: string }>();

    // GET /api/v1/share/:token с Accept: application/json
    const getRes = await app.inject({
      method: 'GET',
      url: `/api/v1/share/${token}`,
      headers: { Accept: 'application/json' },
    });
    expect(getRes.statusCode).toBe(200);

    const body = getRes.json<{
      owner_name: string;
      from: string;
      to: string;
      items: Array<Record<string, unknown>>;
    }>();

    // owner_name совпадает с именем зарегистрированного пользователя
    expect(body.owner_name).toBe('Test User');

    // items содержит задачу в диапазоне
    expect(body.items.length).toBeGreaterThanOrEqual(1);
    const titles = body.items.map((i) => i['title']);
    expect(titles).toContain('Shared task');

    // задача за пределами диапазона не должна попасть
    expect(titles).not.toContain('Outside range');

    // у item нет поля id и нет приватных полей
    const item = body.items.find((i) => i['title'] === 'Shared task')!;
    expect(item['id']).toBeUndefined();
    expect(item['user_id']).toBeUndefined();

    // обязательные публичные поля присутствуют
    expect(item['title']).toBe('Shared task');
    expect(typeof item['type']).toBe('string');
    expect(typeof item['scheduled_at']).toBe('string');
    expect(typeof item['duration_minutes']).toBe('number');
    expect(typeof item['status']).toBe('string');
  });

  test('(г) мусорный токен → 404', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/share/this.is.garbage',
      headers: { Accept: 'application/json' },
    });
    expect(res.statusCode).toBe(404);
    expect(res.json<{ error: string }>().error).toMatch(/expired|invalid/i);
  });
});

describe('GET /share/:token (публичная HTML-страница)', () => {
  test('(д) Accept: text/html → 200, content-type text/html, тело содержит имя пользователя', async () => {
    const user = await registerUser(app);
    userIds.push(user.userId);

    const from = '2026-06-10T00:00:00.000Z';
    const to = '2026-06-17T00:00:00.000Z';

    // Создаём задачу чтобы страница не была совсем пустой
    await createItem(app, user.token, {
      title: 'HTML visible task',
      scheduled_at: '2026-06-13T14:00:00.000Z',
    });

    const shareRes = await app.inject({
      method: 'POST',
      url: '/api/v1/share',
      headers: { Authorization: `Bearer ${user.token}` },
      payload: { from, to },
    });
    expect(shareRes.statusCode).toBe(200);
    const { token } = shareRes.json<{ token: string; url: string }>();

    // Запрашиваем публичный маршрут с Accept: text/html
    const htmlRes = await app.inject({
      method: 'GET',
      url: `/share/${token}`,
      headers: { Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' },
    });
    expect(htmlRes.statusCode).toBe(200);
    expect(htmlRes.headers['content-type']).toMatch(/text\/html/);

    // HTML-тело содержит имя пользователя
    expect(htmlRes.body).toContain('Test User');

    // HTML-тело содержит footer с подписью
    expect(htmlRes.body).toContain("won't slip");
  });

  test('мусорный токен + Accept: text/html → 404', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/share/this.is.garbage',
      headers: { Accept: 'text/html' },
    });
    expect(res.statusCode).toBe(404);
    expect(res.headers['content-type']).toMatch(/text\/html/);
    expect(res.body).toContain('expired');
  });
});
