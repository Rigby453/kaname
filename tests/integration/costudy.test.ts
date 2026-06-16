/**
 * COSTUDY-01..06: Co-study routes (Ф3)
 * Prisma мокируется, т.к. миграция 20260616000000_costudy ещё не применена к БД.
 */

// ── Мок Prisma ──────────────────────────────────────────────────────────────
// Мокируем до любых импортов, которые тянут PrismaClient.
// moduleNameMapper в jest.config.js стрипает .js → ts-jest разрешает .ts.

const mockPrisma = {
  user: {
    findUnique: jest.fn(),
    findMany: jest.fn(),
  },
  friend: {
    findUnique: jest.fn(),
    findMany: jest.fn(),
    create: jest.fn(),
    deleteMany: jest.fn(),
  },
  coStudySession: {
    create: jest.fn(),
    findFirst: jest.fn(),
    findMany: jest.fn(),
    update: jest.fn(),
    updateMany: jest.fn(),
    groupBy: jest.fn(),
  },
  // Таблицы, используемые другими маршрутами — возвращаем пустые заглушки
  // чтобы buildServer() не падал при регистрации плагинов.
  item: { findMany: jest.fn(), create: jest.fn(), findFirst: jest.fn(), update: jest.fn(), deleteMany: jest.fn(), delete: jest.fn() },
  streak: { findUnique: jest.fn(), upsert: jest.fn() },
  waterLog: { findMany: jest.fn(), create: jest.fn(), deleteMany: jest.fn() },
  foodLog: { findMany: jest.fn(), create: jest.fn(), deleteMany: jest.fn() },
  dayLog: { findMany: jest.fn(), upsert: jest.fn(), deleteMany: jest.fn() },
  tombstone: { findMany: jest.fn(), create: jest.fn(), deleteMany: jest.fn(), upsert: jest.fn() },
  $transaction: jest.fn(async (fn: (tx: typeof mockPrisma) => Promise<unknown>) => fn(mockPrisma)),
};

jest.mock('../../backend/src/models/prisma', () => ({
  __esModule: true,
  default: mockPrisma,
}));

// ── Imports ──────────────────────────────────────────────────────────────────
import { buildServer } from '../../backend/src/app';
import type { FastifyInstance } from 'fastify';

// ── Helpers ──────────────────────────────────────────────────────────────────

const USER_A_ID = 'user-a-id-1111';
const USER_A_EMAIL = 'a@example.com';

const USER_B_ID = 'user-b-id-2222';
const USER_B_EMAIL = 'b@example.com';

let app: FastifyInstance;

/** Генерирует валидный JWT через Fastify-инстанс */
function makeToken(userId: string, email: string): string {
  return app.jwt.sign({ userId, email });
}

beforeAll(async () => {
  app = await buildServer();
  await app.ready();
});

afterAll(async () => {
  await app.close();
});

beforeEach(() => {
  // Сбрасываем все моки перед каждым тестом
  jest.clearAllMocks();
});

// ── POST /api/v1/friends ─────────────────────────────────────────────────────

describe('POST /api/v1/friends', () => {
  const url = '/api/v1/friends';

  test('201 — успешное добавление', async () => {
    mockPrisma.user.findUnique.mockResolvedValueOnce({
      id: USER_B_ID,
      email: USER_B_EMAIL,
    });
    mockPrisma.friend.findUnique.mockResolvedValueOnce(null);
    mockPrisma.friend.create.mockResolvedValueOnce({
      id: 'fr-1',
      userId: USER_A_ID,
      friendId: USER_B_ID,
    });

    const res = await app.inject({
      method: 'POST',
      url,
      headers: { Authorization: `Bearer ${makeToken(USER_A_ID, USER_A_EMAIL)}` },
      payload: { email: USER_B_EMAIL },
    });

    expect(res.statusCode).toBe(201);
    const body = res.json<{ id: string; email: string }>();
    expect(body.id).toBe(USER_B_ID);
    expect(body.email).toBe(USER_B_EMAIL);
  });

  test('404 — пользователь не найден', async () => {
    mockPrisma.user.findUnique.mockResolvedValueOnce(null);

    const res = await app.inject({
      method: 'POST',
      url,
      headers: { Authorization: `Bearer ${makeToken(USER_A_ID, USER_A_EMAIL)}` },
      payload: { email: 'nobody@example.com' },
    });

    expect(res.statusCode).toBe(404);
    expect(res.json<{ error: string }>().error).toMatch(/not found/i);
  });

  test('409 — уже подписан', async () => {
    mockPrisma.user.findUnique.mockResolvedValueOnce({
      id: USER_B_ID,
      email: USER_B_EMAIL,
    });
    mockPrisma.friend.findUnique.mockResolvedValueOnce({
      id: 'fr-existing',
      userId: USER_A_ID,
      friendId: USER_B_ID,
    });

    const res = await app.inject({
      method: 'POST',
      url,
      headers: { Authorization: `Bearer ${makeToken(USER_A_ID, USER_A_EMAIL)}` },
      payload: { email: USER_B_EMAIL },
    });

    expect(res.statusCode).toBe(409);
    expect(res.json<{ error: string }>().error).toMatch(/already/i);
  });

  test('400 — добавление себя', async () => {
    // Возвращаем самого пользователя
    mockPrisma.user.findUnique.mockResolvedValueOnce({
      id: USER_A_ID,
      email: USER_A_EMAIL,
    });

    const res = await app.inject({
      method: 'POST',
      url,
      headers: { Authorization: `Bearer ${makeToken(USER_A_ID, USER_A_EMAIL)}` },
      payload: { email: USER_A_EMAIL },
    });

    expect(res.statusCode).toBe(400);
    expect(res.json<{ error: string }>().error).toMatch(/yourself/i);
  });

  test('401 — без токена', async () => {
    const res = await app.inject({
      method: 'POST',
      url,
      payload: { email: USER_B_EMAIL },
    });
    expect(res.statusCode).toBe(401);
  });
});

// ── GET /api/v1/friends ──────────────────────────────────────────────────────

describe('GET /api/v1/friends', () => {
  const url = '/api/v1/friends';

  test('200 — возвращает массив с полями in_session / session_minutes', async () => {
    const sessionStartedAt = new Date(Date.now() - 5 * 60 * 1000); // 5 минут назад

    mockPrisma.friend.findMany.mockResolvedValueOnce([
      {
        friend: {
          id: USER_B_ID,
          email: USER_B_EMAIL,
          coStudySessions: [{ startedAt: sessionStartedAt }],
        },
      },
    ]);

    const res = await app.inject({
      method: 'GET',
      url,
      headers: { Authorization: `Bearer ${makeToken(USER_A_ID, USER_A_EMAIL)}` },
    });

    expect(res.statusCode).toBe(200);
    const body = res.json<Array<{
      id: string;
      email: string;
      in_session: boolean;
      session_minutes: number | null;
    }>>();
    expect(Array.isArray(body)).toBe(true);
    expect(body).toHaveLength(1);
    expect(body[0]!.id).toBe(USER_B_ID);
    expect(body[0]!.email).toBe(USER_B_EMAIL);
    expect(body[0]!.in_session).toBe(true);
    expect(typeof body[0]!.session_minutes).toBe('number');
    // Должно быть ~5 минут (разрешаем ±1 из-за таймингов теста)
    expect(body[0]!.session_minutes).toBeGreaterThanOrEqual(4);
  });

  test('200 — друг без активной сессии: in_session=false, session_minutes=null', async () => {
    mockPrisma.friend.findMany.mockResolvedValueOnce([
      {
        friend: {
          id: USER_B_ID,
          email: USER_B_EMAIL,
          coStudySessions: [],
        },
      },
    ]);

    const res = await app.inject({
      method: 'GET',
      url,
      headers: { Authorization: `Bearer ${makeToken(USER_A_ID, USER_A_EMAIL)}` },
    });

    expect(res.statusCode).toBe(200);
    const body = res.json<Array<{ in_session: boolean; session_minutes: number | null }>>();
    expect(body[0]!.in_session).toBe(false);
    expect(body[0]!.session_minutes).toBeNull();
  });

  test('401 — без токена', async () => {
    const res = await app.inject({ method: 'GET', url });
    expect(res.statusCode).toBe(401);
  });
});

// ── DELETE /api/v1/friends/:friendId ────────────────────────────────────────

describe('DELETE /api/v1/friends/:friendId', () => {
  test('204 — успешное удаление', async () => {
    mockPrisma.friend.deleteMany.mockResolvedValueOnce({ count: 1 });

    const res = await app.inject({
      method: 'DELETE',
      url: `/api/v1/friends/${USER_B_ID}`,
      headers: { Authorization: `Bearer ${makeToken(USER_A_ID, USER_A_EMAIL)}` },
    });

    expect(res.statusCode).toBe(204);
    expect(mockPrisma.friend.deleteMany).toHaveBeenCalledWith({
      where: { userId: USER_A_ID, friendId: USER_B_ID },
    });
  });

  test('401 — без токена', async () => {
    const res = await app.inject({
      method: 'DELETE',
      url: `/api/v1/friends/${USER_B_ID}`,
    });
    expect(res.statusCode).toBe(401);
  });
});

// ── POST /api/v1/study-sessions ─────────────────────────────────────────────

describe('POST /api/v1/study-sessions', () => {
  const url = '/api/v1/study-sessions';

  test('201 — возвращает id и started_at', async () => {
    const startedAt = new Date();
    mockPrisma.coStudySession.updateMany.mockResolvedValueOnce({ count: 0 });
    mockPrisma.coStudySession.create.mockResolvedValueOnce({
      id: 'sess-001',
      userId: USER_A_ID,
      startedAt,
      endedAt: null,
      minutesLogged: null,
    });

    const res = await app.inject({
      method: 'POST',
      url,
      headers: { Authorization: `Bearer ${makeToken(USER_A_ID, USER_A_EMAIL)}` },
    });

    expect(res.statusCode).toBe(201);
    const body = res.json<{ id: string; started_at: string }>();
    expect(body.id).toBe('sess-001');
    expect(typeof body.started_at).toBe('string');
    // Должно быть валидным ISO-форматом
    expect(() => new Date(body.started_at)).not.toThrow();
  });

  test('401 — без токена', async () => {
    const res = await app.inject({ method: 'POST', url });
    expect(res.statusCode).toBe(401);
  });
});

// ── PATCH /api/v1/study-sessions/:id ────────────────────────────────────────

describe('PATCH /api/v1/study-sessions/:id', () => {
  test('200 — завершение сессии возвращает ended_at и minutes_logged', async () => {
    const startedAt = new Date(Date.now() - 30 * 60 * 1000); // 30 минут назад
    const endedAt = new Date();

    mockPrisma.coStudySession.findFirst.mockResolvedValueOnce({
      id: 'sess-001',
      userId: USER_A_ID,
      startedAt,
      endedAt: null,
      minutesLogged: null,
    });
    mockPrisma.coStudySession.update.mockResolvedValueOnce({
      id: 'sess-001',
      userId: USER_A_ID,
      startedAt,
      endedAt,
      minutesLogged: 30,
    });

    const res = await app.inject({
      method: 'PATCH',
      url: '/api/v1/study-sessions/sess-001',
      headers: { Authorization: `Bearer ${makeToken(USER_A_ID, USER_A_EMAIL)}` },
      payload: {},
    });

    expect(res.statusCode).toBe(200);
    const body = res.json<{
      id: string;
      started_at: string;
      ended_at: string;
      minutes_logged: number;
    }>();
    expect(body.id).toBe('sess-001');
    expect(typeof body.ended_at).toBe('string');
    expect(typeof body.minutes_logged).toBe('number');
  });

  test('404 — сессия не найдена', async () => {
    mockPrisma.coStudySession.findFirst.mockResolvedValueOnce(null);

    const res = await app.inject({
      method: 'PATCH',
      url: '/api/v1/study-sessions/nonexistent',
      headers: { Authorization: `Bearer ${makeToken(USER_A_ID, USER_A_EMAIL)}` },
      payload: {},
    });

    expect(res.statusCode).toBe(404);
    expect(res.json<{ error: string }>().error).toMatch(/not found/i);
  });

  test('400 — сессия уже завершена', async () => {
    mockPrisma.coStudySession.findFirst.mockResolvedValueOnce({
      id: 'sess-done',
      userId: USER_A_ID,
      startedAt: new Date(Date.now() - 60 * 60 * 1000),
      endedAt: new Date(Date.now() - 30 * 60 * 1000),
      minutesLogged: 30,
    });

    const res = await app.inject({
      method: 'PATCH',
      url: '/api/v1/study-sessions/sess-done',
      headers: { Authorization: `Bearer ${makeToken(USER_A_ID, USER_A_EMAIL)}` },
      payload: {},
    });

    expect(res.statusCode).toBe(400);
  });

  test('401 — без токена', async () => {
    const res = await app.inject({
      method: 'PATCH',
      url: '/api/v1/study-sessions/sess-001',
      payload: {},
    });
    expect(res.statusCode).toBe(401);
  });
});

// ── GET /api/v1/leaderboard ──────────────────────────────────────────────────

describe('GET /api/v1/leaderboard', () => {
  const url = '/api/v1/leaderboard';

  test('200 — возвращает ранжированный массив с is_me', async () => {
    // Друзья пользователя
    mockPrisma.friend.findMany.mockResolvedValueOnce([
      { friendId: USER_B_ID },
    ]);

    // groupBy: USER_A — 90 минут, USER_B — 120
    mockPrisma.coStudySession.groupBy.mockResolvedValueOnce([
      { userId: USER_B_ID, _sum: { minutesLogged: 120 } },
      { userId: USER_A_ID, _sum: { minutesLogged: 90 } },
    ]);

    // Пользователи
    mockPrisma.user.findMany.mockResolvedValueOnce([
      { id: USER_A_ID, email: USER_A_EMAIL },
      { id: USER_B_ID, email: USER_B_EMAIL },
    ]);

    const res = await app.inject({
      method: 'GET',
      url,
      headers: { Authorization: `Bearer ${makeToken(USER_A_ID, USER_A_EMAIL)}` },
    });

    expect(res.statusCode).toBe(200);
    const board = res.json<Array<{
      rank: number;
      user_id: string;
      email: string;
      is_me: boolean;
      minutes: number;
    }>>();

    expect(Array.isArray(board)).toBe(true);
    // Первое место — USER_B (больше минут)
    expect(board[0]!.user_id).toBe(USER_B_ID);
    expect(board[0]!.rank).toBe(1);
    expect(board[0]!.is_me).toBe(false);
    // Второе место — USER_A (текущий пользователь)
    const me = board.find((e) => e.is_me);
    expect(me).toBeDefined();
    expect(me!.user_id).toBe(USER_A_ID);
    expect(me!.minutes).toBe(90);
  });

  test('200 — я добавляюсь в конец, если у меня 0 минут за неделю', async () => {
    mockPrisma.friend.findMany.mockResolvedValueOnce([]);
    // Группировка пустая — у меня нет сессий
    mockPrisma.coStudySession.groupBy.mockResolvedValueOnce([]);
    mockPrisma.user.findMany.mockResolvedValueOnce([
      { id: USER_A_ID, email: USER_A_EMAIL },
    ]);

    const res = await app.inject({
      method: 'GET',
      url,
      headers: { Authorization: `Bearer ${makeToken(USER_A_ID, USER_A_EMAIL)}` },
    });

    expect(res.statusCode).toBe(200);
    const board = res.json<Array<{ is_me: boolean; minutes: number; rank: number }>>();
    expect(board).toHaveLength(1);
    expect(board[0]!.is_me).toBe(true);
    expect(board[0]!.minutes).toBe(0);
    expect(board[0]!.rank).toBe(1);
  });

  test('401 — без токена', async () => {
    const res = await app.inject({ method: 'GET', url });
    expect(res.statusCode).toBe(401);
  });
});
