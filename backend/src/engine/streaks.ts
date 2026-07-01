import prisma from "../models/prisma.js";

/**
 * STREAK-02: Внутренний хелпер — обновляет серию за конкретный день.
 * Вызывается из PATCH /items/:id и из /sync, когда статус задачи меняется на 'done'.
 * Правила только rule-based, без AI.
 *
 * Решение владельца #2 (2026-07-01): день засчитывается, если выполнено ВСЁ
 * запланированное на день, а не только priority=main. Предикат «день завершён»:
 * 1. Берём ВСЕ items (любой priority) за этот день.
 * 2. Нет ни одного item за день → день НЕЙТРАЛЬНЫЙ: не растит и не сбрасывает
 *    серию, выходим без изменений (в отличие от «несделанного дня» — просто
 *    отсутствие плана не должно карать пользователя).
 * 3. status='skipped' «не мешает»: skipped-задачи исключаются из требования
 *    «все done». НО если после исключения skipped ничего не остаётся (то есть
 *    ВСЕ задачи дня были skipped, ни одна не done) — день тоже считается
 *    нейтральным, а не засчитанным: иначе можно было бы «накрутить» серию,
 *    просто пропуская все задачи, ничего не сделав. Это намеренная трактовка
 *    формулировки «skipped не мешает» — не путать с «skipped даёт зачёт».
 * 4. Иначе день завершён, если оставшиеся (не-skipped) задачи ВСЕ done.
 *    Если хоть одна не-skipped задача не done (включая pending) — день НЕ
 *    завершён, выходим без изменений (пересчёт сработает позже, на следующем
 *    завершённом дне — freeze/грейс ниже не меняются).
 *
 * Далее (без изменений):
 * 5. Загружаем или создаём Streak.
 * 6. Сравниваем lastCompletedDate с today/yesterday:
 *    - Если уже today → idempotent, выходим.
 *    - Если yesterday → current += 1.
 *    - Если старше/null + freezeCount > 0 → freezeCount -= 1, current без изменений.
 *    - Иначе → current = 1.
 * 7. longest = max(longest, current). lastCompletedDate = today. Сохраняем.
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

  // Получаем ВСЕ задачи/события за этот день (любой priority) — решение #2:
  // «день завершён» = выполнено всё запланированное, а не только главное.
  const dayItems = await prisma.item.findMany({
    where: {
      userId,
      scheduledAt: {
        gte: startOfDay,
        lte: endOfDay,
      },
    },
    select: { id: true, status: true },
  });

  // Нет запланированного на этот день — нейтральный день, серия не меняется.
  if (dayItems.length === 0) return;

  // skipped «не мешает»: исключаем из требования, но если ПОСЛЕ исключения
  // ничего не осталось (все задачи были skipped) — тоже нейтральный день, а
  // не засчитанный (см. комментарий выше, п.3).
  const countedItems = dayItems.filter((item) => item.status !== "skipped");
  if (countedItems.length === 0) return;

  // Если хоть одна из оставшихся не выполнена — день не завершён, выходим.
  const allDone = countedItems.every((item) => item.status === "done");
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
