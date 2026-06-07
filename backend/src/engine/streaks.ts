import prisma from "../models/prisma.js";

/**
 * STREAK-02: Внутренний хелпер — обновляет серию за конкретный день.
 * Вызывается из PATCH /items/:id когда статус меняется на 'done'.
 * Правила только rule-based, без AI.
 *
 * Логика:
 * 1. Получаем все items с priority=main за этот день.
 * 2. Если нет ни одного → выходим (нет главных задач — серия не меняется).
 * 3. Если не все выполнены → выходим.
 * 4. Загружаем или создаём Streak.
 * 5. Сравниваем lastCompletedDate с today/yesterday:
 *    - Если уже today → idempotent, выходим.
 *    - Если yesterday → current += 1.
 *    - Если старше/null + freezeCount > 0 → freezeCount -= 1, current без изменений.
 *    - Иначе → current = 1.
 * 6. longest = max(longest, current). lastCompletedDate = today. Сохраняем.
 */
export async function checkAndUpdateStreak(
  userId: string,
  date: Date
): Promise<void> {
  // Вычисляем начало и конец дня по UTC
  const startOfDay = new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate(), 0, 0, 0, 0)
  );
  const endOfDay = new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate(), 23, 59, 59, 999)
  );

  // Получаем все главные задачи за этот день
  const mainItems = await prisma.item.findMany({
    where: {
      userId,
      priority: "main",
      scheduledAt: {
        gte: startOfDay,
        lte: endOfDay,
      },
    },
    select: { id: true, status: true },
  });

  // Нет главных задач — серия не обновляется
  if (mainItems.length === 0) return;

  // Если не все главные задачи выполнены — выходим
  const allDone = mainItems.every((item) => item.status === "done");
  if (!allDone) return;

  // Нормализуем дату (только день, без времени) для сравнения
  const todayStr = startOfDay.toISOString().slice(0, 10);
  const yesterdayDate = new Date(startOfDay);
  yesterdayDate.setUTCDate(yesterdayDate.getUTCDate() - 1);
  const yesterdayStr = yesterdayDate.toISOString().slice(0, 10);

  // Загружаем или создаём Streak
  let streak = await prisma.streak.findUnique({ where: { userId } });
  if (!streak) {
    streak = await prisma.streak.create({
      data: { userId, current: 0, longest: 0, freezeCount: 0 },
    });
  }

  // Если lastCompletedDate уже равна today → idempotent, не считаем повторно
  const lastStr = streak.lastCompletedDate
    ? streak.lastCompletedDate.toISOString().slice(0, 10)
    : null;

  if (lastStr === todayStr) return;

  let newCurrent = streak.current;
  let newFreezeCount = streak.freezeCount;

  if (lastStr === yesterdayStr) {
    // Вчера завершили — продолжаем серию
    newCurrent += 1;
  } else if (streak.freezeCount > 0) {
    // Пропустили день, но есть заморозка — используем её, серия сохраняется
    newFreezeCount -= 1;
    // current не меняется
  } else {
    // Давно не было или null и нет заморозки — серия сбрасывается до 1
    newCurrent = 1;
  }

  const newLongest = Math.max(streak.longest, newCurrent);

  // Сохраняем обновлённый streak
  await prisma.streak.update({
    where: { userId },
    data: {
      current: newCurrent,
      longest: newLongest,
      freezeCount: newFreezeCount,
      lastCompletedDate: startOfDay,
    },
  });
}
