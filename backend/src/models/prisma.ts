import { Prisma, PrismaClient } from "@prisma/client";

// Реэкспорт Prisma для удобства тестов (классы ошибок) — модуль резолвится
// из node_modules бэкенда, в отличие от прямого импорта "@prisma/client".
export { Prisma };

// Коды Prisma, означающие транзиентный (временный) разрыв соединения.
// Neon (serverless Postgres) закрывает простаивающие соединения, поэтому
// первый запрос после простоя может упасть с такой ошибкой. Их безопасно
// повторить — данные ещё не были изменены, соединение просто переустановится.
//   P1017 — Server has closed the connection
//   P1001 — Can't reach database server
//   P1002 — Database server reached but timed out
const TRANSIENT_DB_ERROR_CODES = new Set(["P1017", "P1001", "P1002"]);

// Бэкофф между попытками (мс). Длина массива = число повторов после первой попытки.
// 2 повтора → максимум 3 попытки суммарно. Задержки маленькие и ограниченные.
const RETRY_BACKOFF_MS = [100, 300];

/**
 * Является ли ошибка транзиентным разрывом соединения с БД,
 * который имеет смысл повторить.
 */
export function isTransientDbError(error: unknown): boolean {
  if (error instanceof Prisma.PrismaClientKnownRequestError) {
    return TRANSIENT_DB_ERROR_CODES.has(error.code);
  }
  // Ошибка инициализации клиента (например, БД временно недоступна при коннекте).
  if (error instanceof Prisma.PrismaClientInitializationError) {
    return true;
  }
  return false;
}

const sleep = (ms: number): Promise<void> =>
  new Promise((resolve) => setTimeout(resolve, ms));

/**
 * Выполняет операцию с повтором только при транзиентных разрывах соединения.
 * Любые другие ошибки (валидация, нарушение уникальности и т.п.) пробрасываются
 * сразу, без повтора.
 */
export async function withRetry<T>(
  fn: () => Promise<T>,
  backoffMs: readonly number[] = RETRY_BACKOFF_MS
): Promise<T> {
  let lastError: unknown;
  // Попытки = первая + по одной на каждый интервал бэкоффа.
  for (let attempt = 0; attempt <= backoffMs.length; attempt++) {
    try {
      return await fn();
    } catch (error: unknown) {
      lastError = error;
      const canRetry = attempt < backoffMs.length && isTransientDbError(error);
      if (!canRetry) {
        throw error;
      }
      await sleep(backoffMs[attempt]);
    }
  }
  // Сюда попадаем, только если исчерпали все попытки на транзиентных ошибках.
  throw lastError;
}

const base = new PrismaClient();

// Singleton Prisma клиент с устойчивостью к транзиентным разрывам соединения.
// Хук $allOperations оборачивает КАЖДУЮ операцию в withRetry — поэтому защита
// действует на всех маршрутах глобально, а не только в costudy (см. баг #11).
const prisma = base.$extends({
  query: {
    async $allOperations({ args, query }) {
      return withRetry(() => query(args));
    },
  },
});

export default prisma;
