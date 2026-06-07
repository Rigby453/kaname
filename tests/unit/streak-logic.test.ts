/**
 * QA-03: Streak logic (unit).
 * Тестирует checkAndUpdateStreak напрямую: сеем main-задачи и предсостояние
 * Streak через prisma, вызываем хелпер, проверяем результат.
 */
import { checkAndUpdateStreak } from '../../backend/src/engine/streaks';
import prisma from '../../backend/src/models/prisma';
import { cleanupUser } from '../helpers';

const today = new Date('2026-06-10T12:00:00.000Z');
const yesterdayUtc = new Date(Date.UTC(2026, 5, 9));
const threeDaysAgoUtc = new Date(Date.UTC(2026, 5, 7));

async function createUserDirect(): Promise<string> {
  const user = await prisma.user.create({
    data: {
      email: `streak_${Date.now()}_${Math.random().toString(36).slice(2)}@example.com`,
      passwordHash: 'x',
      name: 'Streak Test',
    },
  });
  return user.id;
}

async function createMainItem(
  userId: string,
  status: 'pending' | 'done'
): Promise<void> {
  await prisma.item.create({
    data: {
      userId,
      title: 'main task',
      type: 'task',
      priority: 'main',
      status,
      scheduledAt: new Date(Date.UTC(2026, 5, 10, 9, 0, 0)),
      isProtected: true,
    },
  });
}

describe('checkAndUpdateStreak', () => {
  const users: string[] = [];

  afterAll(async () => {
    for (const id of users) {
      await cleanupUser(id);
    }
    await prisma.$disconnect();
  });

  test('all main items done → current increments to 1, lastCompletedDate = today', async () => {
    const userId = await createUserDirect();
    users.push(userId);
    await createMainItem(userId, 'done');

    await checkAndUpdateStreak(userId, today);

    const streak = await prisma.streak.findUnique({ where: { userId } });
    expect(streak?.current).toBe(1);
    expect(streak?.lastCompletedDate?.toISOString().slice(0, 10)).toBe('2026-06-10');
  });

  test('partial main items done → streak NOT updated', async () => {
    const userId = await createUserDirect();
    users.push(userId);
    await createMainItem(userId, 'done');
    await createMainItem(userId, 'pending');

    await checkAndUpdateStreak(userId, today);

    const streak = await prisma.streak.findUnique({ where: { userId } });
    // Хелпер выходит до создания/обновления streak, если не все main выполнены
    expect(streak).toBeNull();
  });

  test('no main items today → streak NOT updated', async () => {
    const userId = await createUserDirect();
    users.push(userId);

    await checkAndUpdateStreak(userId, today);

    const streak = await prisma.streak.findUnique({ where: { userId } });
    expect(streak).toBeNull();
  });

  test('consecutive day (last = yesterday) → current += 1 and longest tracks', async () => {
    const userId = await createUserDirect();
    users.push(userId);
    await prisma.streak.create({
      data: {
        userId,
        current: 2,
        longest: 2,
        freezeCount: 0,
        lastCompletedDate: yesterdayUtc,
      },
    });
    await createMainItem(userId, 'done');

    await checkAndUpdateStreak(userId, today);

    const streak = await prisma.streak.findUnique({ where: { userId } });
    expect(streak?.current).toBe(3);
    expect(streak?.longest).toBe(3);
  });

  test('missed day with freeze available → streak holds, freeze decremented', async () => {
    const userId = await createUserDirect();
    users.push(userId);
    await prisma.streak.create({
      data: {
        userId,
        current: 5,
        longest: 5,
        freezeCount: 1,
        lastCompletedDate: threeDaysAgoUtc,
      },
    });
    await createMainItem(userId, 'done');

    await checkAndUpdateStreak(userId, today);

    const streak = await prisma.streak.findUnique({ where: { userId } });
    expect(streak?.current).toBe(5); // серия сохранена
    expect(streak?.freezeCount).toBe(0);
    expect(streak?.lastCompletedDate?.toISOString().slice(0, 10)).toBe('2026-06-10');
  });

  test('missed day without freeze → current resets to 1', async () => {
    const userId = await createUserDirect();
    users.push(userId);
    await prisma.streak.create({
      data: {
        userId,
        current: 5,
        longest: 5,
        freezeCount: 0,
        lastCompletedDate: threeDaysAgoUtc,
      },
    });
    await createMainItem(userId, 'done');

    await checkAndUpdateStreak(userId, today);

    const streak = await prisma.streak.findUnique({ where: { userId } });
    expect(streak?.current).toBe(1);
    expect(streak?.longest).toBe(5); // рекорд не уменьшается
  });
});
