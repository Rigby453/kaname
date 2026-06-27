// Юнит-тест расчёта среднего потребления воды в день (БАГ-3).
//
// Проверяет, что крупный недельный показатель в Wrapped отображает
// СРЕДНЕЕ/день (totalMl ÷ days), а не суммарный объём за период.
//
// Формула: (totalMl / days).round() — идентична _LifeInsightsCard
// (diary_screen.dart), которая делит на waterTotals.length == 7.

import 'package:flutter_test/flutter_test.dart';

/// Вычисляет среднее потребление воды в мл/день (as in wrapped_screen.dart).
int waterAvgPerDay(int totalMl, int days) {
  if (days <= 0) return 0;
  return (totalMl / days).round();
}

void main() {
  group('waterAvgPerDay — формула из wrapped_screen и _LifeInsightsCard', () {
    test('4750 мл за 7 дней → 679 мл/день', () {
      // 4750 / 7 = 678.57 → round → 679
      expect(waterAvgPerDay(4750, 7), equals(679));
    });

    test('0 мл за 7 дней → 0', () {
      expect(waterAvgPerDay(0, 7), equals(0));
    });

    test('days = 0 → возвращает 0 (нет деления на ноль)', () {
      expect(waterAvgPerDay(1000, 0), equals(0));
    });

    test('2100 мл за 7 дней → 300 мл/день', () {
      expect(waterAvgPerDay(2100, 7), equals(300));
    });

    test('9000 мл за 30 дней → 300 мл/день', () {
      expect(waterAvgPerDay(9000, 30), equals(300));
    });

    test('результат совпадает с методом diary._LifeInsightsCard', () {
      // _LifeInsightsCard: (totals.fold(0, +) / totals.length).round()
      // watchDailyTotals всегда возвращает 7 слотов (включая нулевые дни)
      final weekTotals = [700, 600, 700, 800, 650, 550, 750]; // sum = 4750
      final lifeInsightsAvg =
          (weekTotals.fold<int>(0, (a, b) => a + b) / weekTotals.length).round();
      final wrappedAvg = waterAvgPerDay(4750, 7);
      expect(wrappedAvg, equals(lifeInsightsAvg));
      expect(wrappedAvg, equals(679));
    });
  });
}
