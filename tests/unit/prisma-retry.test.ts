/**
 * BUG #11: устойчивость Prisma-клиента к транзиентным разрывам соединения Neon.
 * Тестируем чистые хелперы isTransientDbError / withRetry напрямую,
 * без обращения к реальной БД.
 */
import {
  Prisma,
  isTransientDbError,
  withRetry,
} from '../../backend/src/models/prisma';

function knownError(code: string): Prisma.PrismaClientKnownRequestError {
  return new Prisma.PrismaClientKnownRequestError('boom', {
    code,
    clientVersion: '5.22.0',
  });
}

describe('isTransientDbError', () => {
  test.each(['P1017', 'P1001', 'P1002'])(
    'transient connection code %s → true',
    (code) => {
      expect(isTransientDbError(knownError(code))).toBe(true);
    }
  );

  test('PrismaClientInitializationError → true', () => {
    const err = new Prisma.PrismaClientInitializationError('init', '5.22.0');
    expect(isTransientDbError(err)).toBe(true);
  });

  test('non-transient known error (P2002 unique) → false', () => {
    expect(isTransientDbError(knownError('P2002'))).toBe(false);
  });

  test('plain Error → false', () => {
    expect(isTransientDbError(new Error('nope'))).toBe(false);
  });
});

describe('withRetry', () => {
  // Без задержки, чтобы тесты были мгновенными.
  const noBackoff = [0, 0];

  test('throws P1017 once then succeeds → resolves', async () => {
    let calls = 0;
    const op = jest.fn(async () => {
      calls++;
      if (calls === 1) throw knownError('P1017');
      return 'ok';
    });

    await expect(withRetry(op, noBackoff)).resolves.toBe('ok');
    expect(op).toHaveBeenCalledTimes(2);
  });

  test('non-retryable error (P2002) → rejects immediately, no retry', async () => {
    const op = jest.fn(async () => {
      throw knownError('P2002');
    });

    await expect(withRetry(op, noBackoff)).rejects.toMatchObject({
      code: 'P2002',
    });
    expect(op).toHaveBeenCalledTimes(1);
  });

  test('transient error every time → exhausts attempts and rethrows last', async () => {
    const op = jest.fn(async () => {
      throw knownError('P1017');
    });

    await expect(withRetry(op, noBackoff)).rejects.toMatchObject({
      code: 'P1017',
    });
    // 1 первая попытка + 2 повтора = 3 вызова.
    expect(op).toHaveBeenCalledTimes(3);
  });

  test('success on first try → no retry', async () => {
    const op = jest.fn(async () => 'first');
    await expect(withRetry(op, noBackoff)).resolves.toBe('first');
    expect(op).toHaveBeenCalledTimes(1);
  });
});
