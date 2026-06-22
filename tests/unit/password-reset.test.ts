/**
 * Unit: логика кода восстановления пароля (ADR-047) — без БД.
 *
 * Покрывает чистые функции из backend/src/models/passwordReset.ts:
 *  - генерация даёт 6-значный код
 *  - хэш детерминирован и не равен самому коду (храним хэш, не код)
 *  - валидность: верный код проходит, неверный/истёкший/использованный — нет
 */
import {
  RESET_CODE_TTL_MS,
  generateResetCode,
  hashResetCode,
  isResetCodeValid,
  type ResetCodeRecord,
} from '../../backend/src/models/passwordReset';

describe('generateResetCode', () => {
  test('возвращает ровно 6 цифр', () => {
    for (let i = 0; i < 50; i++) {
      const code = generateResetCode();
      expect(code).toMatch(/^\d{6}$/);
    }
  });
});

describe('hashResetCode', () => {
  test('детерминирован — одинаковый код → одинаковый хэш', () => {
    expect(hashResetCode('123456')).toBe(hashResetCode('123456'));
  });

  test('хэш не равен самому коду (храним хэш, не код)', () => {
    expect(hashResetCode('123456')).not.toBe('123456');
  });

  test('разные коды → разные хэши', () => {
    expect(hashResetCode('123456')).not.toBe(hashResetCode('654321'));
  });
});

describe('isResetCodeValid', () => {
  const now = new Date('2026-06-23T12:00:00Z');
  const future = new Date(now.getTime() + RESET_CODE_TTL_MS);
  const past = new Date(now.getTime() - 1000);

  function record(overrides: Partial<ResetCodeRecord> = {}): ResetCodeRecord {
    return {
      codeHash: hashResetCode('123456'),
      expiresAt: future,
      usedAt: null,
      ...overrides,
    };
  }

  test('верный код, не истёк, не использован → true', () => {
    expect(isResetCodeValid(record(), '123456', now)).toBe(true);
  });

  test('неверный код → false', () => {
    expect(isResetCodeValid(record(), '000000', now)).toBe(false);
  });

  test('истёкший код → false', () => {
    expect(isResetCodeValid(record({ expiresAt: past }), '123456', now)).toBe(false);
  });

  test('уже использованный код → false', () => {
    expect(isResetCodeValid(record({ usedAt: past }), '123456', now)).toBe(false);
  });
});
