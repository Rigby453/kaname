// Юнит-тесты логики начисления заморозок стрика.
// Тестируем чистую функцию computeAccrual (без Flutter/Drift/SharedPreferences).
// Затем — интеграционный тест FreezeAccrualService со stub-реализациями.

import 'package:app/services/streak/freeze_accrual_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // computeAccrual — чистая функция
  // ---------------------------------------------------------------------------

  group('computeAccrual — инициализация', () {
    test('первый вызов без lastAccrual: не начисляет, устанавливает now', () {
      final now = DateTime.utc(2026, 1, 1, 12);
      final result = computeAccrual(
        now: now,
        lastAccrual: null,
        cadenceDays: 30,
        currentFreezes: 0,
        claimedThresholds: {},
      );

      expect(result.addedFreezes, 0);
      expect(result.newLastAccrual, now);
      expect(result.newlyClaimedThresholds, isEmpty);
      expect(result.addedPremiumDays, 0);
    });
  });

  group('computeAccrual — Free cadence (30 дней)', () {
    test('прошло 29 дней — не начисляет', () {
      final last = DateTime.utc(2026, 1, 1);
      final now = last.add(const Duration(days: 29, hours: 23));
      final result = computeAccrual(
        now: now,
        lastAccrual: last,
        cadenceDays: 30,
        currentFreezes: 0,
        claimedThresholds: {},
      );

      expect(result.addedFreezes, 0);
      expect(result.newLastAccrual, last); // не сдвигается
    });

    test('прошло ровно 30 дней — начисляет 1', () {
      final last = DateTime.utc(2026, 1, 1);
      final now = last.add(const Duration(days: 30));
      final result = computeAccrual(
        now: now,
        lastAccrual: last,
        cadenceDays: 30,
        currentFreezes: 2,
        claimedThresholds: {},
      );

      expect(result.addedFreezes, 1);
      expect(result.newLastAccrual, last.add(const Duration(days: 30)));
    });

    test('прошло 61 день — начисляет 2 (два периода)', () {
      final last = DateTime.utc(2026, 1, 1);
      final now = last.add(const Duration(days: 61));
      final result = computeAccrual(
        now: now,
        lastAccrual: last,
        cadenceDays: 30,
        currentFreezes: 0,
        claimedThresholds: {},
      );

      expect(result.addedFreezes, 2);
      expect(result.newLastAccrual, last.add(const Duration(days: 60)));
    });

    test('прошло 90 дней — начисляет 3', () {
      final last = DateTime.utc(2025, 6, 1);
      final now = last.add(const Duration(days: 90));
      final result = computeAccrual(
        now: now,
        lastAccrual: last,
        cadenceDays: 30,
        currentFreezes: 0,
        claimedThresholds: {},
      );

      expect(result.addedFreezes, 3);
    });
  });

  group('computeAccrual — Premium cadence (14 дней)', () {
    test('прошло 13 дней — не начисляет', () {
      final last = DateTime.utc(2026, 3, 1);
      final now = last.add(const Duration(days: 13));
      final result = computeAccrual(
        now: now,
        lastAccrual: last,
        cadenceDays: 14,
        currentFreezes: 5,
        claimedThresholds: {},
      );

      expect(result.addedFreezes, 0);
    });

    test('прошло 14 дней — начисляет 1', () {
      final last = DateTime.utc(2026, 3, 1);
      final now = last.add(const Duration(days: 14));
      final result = computeAccrual(
        now: now,
        lastAccrual: last,
        cadenceDays: 14,
        currentFreezes: 5,
        claimedThresholds: {},
      );

      expect(result.addedFreezes, 1);
      expect(result.newLastAccrual, last.add(const Duration(days: 14)));
    });

    test('прошло 28 дней — начисляет 2 (два периода)', () {
      final last = DateTime.utc(2026, 3, 1);
      final now = last.add(const Duration(days: 28));
      final result = computeAccrual(
        now: now,
        lastAccrual: last,
        cadenceDays: 14,
        currentFreezes: 5,
        claimedThresholds: {},
      );

      expect(result.addedFreezes, 2);
    });

    test('Premium начисляет быстрее чем Free: за 60 дней Premium=4, Free=2', () {
      final last = DateTime.utc(2026, 1, 1);
      final now = last.add(const Duration(days: 60));

      final premium = computeAccrual(
        now: now,
        lastAccrual: last,
        cadenceDays: 14,
        currentFreezes: 0,
        claimedThresholds: {},
      );
      final free = computeAccrual(
        now: now,
        lastAccrual: last,
        cadenceDays: 30,
        currentFreezes: 0,
        claimedThresholds: {},
      );

      expect(premium.addedFreezes, 4); // 60/14 = 4 целых
      expect(free.addedFreezes, 2);    // 60/30 = 2
    });
  });

  // ---------------------------------------------------------------------------
  // Пороги наград
  // ---------------------------------------------------------------------------

  group('computeAccrual — пороги наград', () {
    test('порог 10: впервые достигается — claimed и premiumDays=7', () {
      final last = DateTime.utc(2026, 1, 1);
      final now = last.add(const Duration(days: 300));
      // currentFreezes=9, добавим 1 → станет 10
      final result = computeAccrual(
        now: now,
        lastAccrual: last,
        cadenceDays: 30,
        currentFreezes: 9,
        claimedThresholds: {},
      );

      expect(result.newlyClaimedThresholds, contains(10));
      expect(result.addedPremiumDays, 7);
    });

    test('порог 10 уже claimed — повторно не выдаётся', () {
      final last = DateTime.utc(2026, 1, 1);
      final now = last.add(const Duration(days: 300));
      final result = computeAccrual(
        now: now,
        lastAccrual: last,
        cadenceDays: 30,
        currentFreezes: 9,
        claimedThresholds: {10}, // уже получен
      );

      expect(result.newlyClaimedThresholds, isNot(contains(10)));
      expect(result.addedPremiumDays, 0);
    });

    test('порог 25: claimed={10}, достигаем 25 → только 25 в newlyClaimed', () {
      final last = DateTime.utc(2026, 1, 1);
      // currentFreezes=24, добавим 1 за 30 дней → 25
      final now = last.add(const Duration(days: 30));
      final result = computeAccrual(
        now: now,
        lastAccrual: last,
        cadenceDays: 30,
        currentFreezes: 24,
        claimedThresholds: {10},
      );

      expect(result.newlyClaimedThresholds, [25]);
      expect(result.addedPremiumDays, 30);
    });

    test('порог 50: premiumDays=90', () {
      final last = DateTime.utc(2026, 1, 1);
      final now = last.add(const Duration(days: 30));
      final result = computeAccrual(
        now: now,
        lastAccrual: last,
        cadenceDays: 30,
        currentFreezes: 49,
        claimedThresholds: {10, 25},
      );

      expect(result.newlyClaimedThresholds, [50]);
      expect(result.addedPremiumDays, 90);
    });

    test('достичь 10 и 25 одновременно (много заморозок разом): оба claimed', () {
      final last = DateTime.utc(2026, 1, 1);
      // 30 периодов по 30 дней = 900 дней → 30 заморозок начислено
      // currentFreezes=0 → итого 30 >= 25 и >= 10
      final now = last.add(const Duration(days: 900));
      final result = computeAccrual(
        now: now,
        lastAccrual: last,
        cadenceDays: 30,
        currentFreezes: 0,
        claimedThresholds: {},
      );

      expect(result.addedFreezes, 30);
      expect(result.newlyClaimedThresholds, containsAll([10, 25]));
      expect(result.addedPremiumDays, 7 + 30); // 10→7дн + 25→30дн
    });

    test('все три порога одновременно: premiumDays=7+30+90=127', () {
      final last = DateTime.utc(2026, 1, 1);
      // 1500 дней / 30 = 50 заморозок
      final now = last.add(const Duration(days: 1500));
      final result = computeAccrual(
        now: now,
        lastAccrual: last,
        cadenceDays: 30,
        currentFreezes: 0,
        claimedThresholds: {},
      );

      expect(result.newlyClaimedThresholds, containsAll([10, 25, 50]));
      expect(result.addedPremiumDays, 7 + 30 + 90);
    });

    test('если все три уже claimed — ни один не выдаётся снова', () {
      final last = DateTime.utc(2026, 1, 1);
      final now = last.add(const Duration(days: 1500));
      final result = computeAccrual(
        now: now,
        lastAccrual: last,
        cadenceDays: 30,
        currentFreezes: 0,
        claimedThresholds: {10, 25, 50},
      );

      expect(result.newlyClaimedThresholds, isEmpty);
      expect(result.addedPremiumDays, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // kFreezeRewardThresholds — константы
  // ---------------------------------------------------------------------------

  group('kFreezeRewardThresholds', () {
    test('содержит три порога в возрастающем порядке', () {
      expect(kFreezeRewardThresholds.map((t) => t.freezeCount).toList(),
          [10, 25, 50]);
      expect(kFreezeRewardThresholds.map((t) => t.premiumDays).toList(),
          [7, 30, 90]);
    });
  });
}
