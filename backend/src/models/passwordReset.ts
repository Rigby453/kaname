/**
 * Хелперы кода восстановления пароля (ADR-047).
 *
 * Коды живут в таблице PasswordResetCode, а не в Map в памяти процесса:
 * память не переживает рестарт/засыпание/масштабирование инстанса, из-за чего
 * код терялся между запросом и вводом (тот же класс проблемы, что AiUsage — ADR-034).
 *
 * Безопасность: храним ТОЛЬКО SHA-256-хэш кода. Код 6-значный, поэтому bcrypt здесь
 * избыточен (его дороговизна нужна против перебора длинных паролей); SHA-256 даёт
 * детерминированный хэш, по которому можно искать запись в БД, и при утечке БД
 * сам код не раскрывается. Перебор отсекается коротким TTL и одноразовостью.
 */
import { createHash, randomInt } from "node:crypto";

// Срок жизни кода — 15 минут.
export const RESET_CODE_TTL_MS = 15 * 60 * 1000;

/**
 * Генерирует 6-значный код восстановления.
 * Использует криптостойкий randomInt (не Math.random).
 */
export function generateResetCode(): string {
  return randomInt(100000, 1000000).toString();
}

/**
 * SHA-256-хэш кода в hex. Детерминирован — одинаковый код даёт одинаковый хэш,
 * поэтому верификация = пересчитать хэш введённого кода и сравнить с хранимым.
 */
export function hashResetCode(code: string): string {
  return createHash("sha256").update(code).digest("hex");
}

// Минимальная форма записи, нужная для проверки валидности (совместима с Prisma).
export interface ResetCodeRecord {
  codeHash: string;
  expiresAt: Date;
  usedAt: Date | null;
}

/**
 * Валиден ли код: не использован, не истёк и хэш совпадает.
 * Чистая функция без IO — можно проверять в unit-тестах.
 */
export function isResetCodeValid(
  record: ResetCodeRecord,
  candidateCode: string,
  now: Date = new Date()
): boolean {
  if (record.usedAt !== null) return false;
  if (record.expiresAt <= now) return false;
  return record.codeHash === hashResetCode(candidateCode);
}
