// Юнит-тесты для mood_engine.dart.
// Чистые функции — нет Flutter, нет Riverpod, нет БД.
// Тестируем крайние случаи computeHeat и все ветки computeEffectiveMood.

import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/mood/mood_engine.dart';

void main() {
  // ---------------------------------------------------------------------------
  // computeHeat
  // ---------------------------------------------------------------------------

  group('computeHeat', () {
    test('нет сигналов → 0.0 (идеальный день)', () {
      final heat = computeHeat(
        overdueCount: 0,
        mainDone: 0,
        mainTotal: 3,
        hasItemsToday: true,
        streakAtRisk: false,
      );
      expect(heat, 0.0);
    });

    test('пустой план → 0.20 (средний нагрев)', () {
      final heat = computeHeat(
        overdueCount: 0,
        mainDone: 0,
        mainTotal: 0,
        hasItemsToday: false,
        streakAtRisk: false,
      );
      expect(heat, closeTo(0.20, 0.001));
    });

    test('стрик под угрозой → 0.25', () {
      final heat = computeHeat(
        overdueCount: 0,
        mainDone: 0,
        mainTotal: 1,
        hasItemsToday: true,
        streakAtRisk: true,
      );
      expect(heat, closeTo(0.25, 0.001));
    });

    test('одна просрочка → 0.15', () {
      final heat = computeHeat(
        overdueCount: 1,
        mainDone: 0,
        mainTotal: 1,
        hasItemsToday: true,
        streakAtRisk: false,
      );
      expect(heat, closeTo(0.15, 0.001));
    });

    test('5 просрочек → clamp 0.60 (не > 1.0)', () {
      final heat = computeHeat(
        overdueCount: 5,
        mainDone: 0,
        mainTotal: 0,
        hasItemsToday: true,
        streakAtRisk: false,
      );
      expect(heat, closeTo(0.60, 0.001));
    });

    test('выполненные main снижают нагрев', () {
      final heatBefore = computeHeat(
        overdueCount: 2,
        mainDone: 0,
        mainTotal: 3,
        hasItemsToday: true,
        streakAtRisk: false,
      );
      final heatAfter = computeHeat(
        overdueCount: 2,
        mainDone: 3,
        mainTotal: 3,
        hasItemsToday: true,
        streakAtRisk: false,
      );
      expect(heatAfter, lessThan(heatBefore));
    });

    test('максимальный нагрев ≤ 1.0', () {
      final heat = computeHeat(
        overdueCount: 100,
        mainDone: 0,
        mainTotal: 0,
        hasItemsToday: false,
        streakAtRisk: true,
      );
      expect(heat, lessThanOrEqualTo(1.0));
    });

    test('heat не может быть < 0.0 (выполненные не уводят в минус)', () {
      final heat = computeHeat(
        overdueCount: 0,
        mainDone: 10,
        mainTotal: 10,
        hasItemsToday: true,
        streakAtRisk: false,
      );
      expect(heat, greaterThanOrEqualTo(0.0));
    });
  });

  // ---------------------------------------------------------------------------
  // computeEffectiveMood
  // ---------------------------------------------------------------------------

  group('computeEffectiveMood', () {
    test('gentle + off + heat=0 → calm (harshness=0)', () {
      final mood = computeEffectiveMood(
        harshTone: false,
        intensityMultiplier: 0.0,
        heat: 0.0,
      );
      expect(mood.harshness, closeTo(0.0, 0.001));
      expect(mood.level, MoodLevel.calm);
    });

    test('gentle + off + heat=1.0 → НЕТ изменений (multiplier=0)', () {
      // При intensity=off (multiplier=0) нагрев не влияет
      final mood = computeEffectiveMood(
        harshTone: false,
        intensityMultiplier: 0.0,
        heat: 1.0,
      );
      expect(mood.harshness, closeTo(0.0, 0.001));
      expect(mood.level, MoodLevel.calm);
    });

    test('harsh + off → harshness=0.5 → stern (базовая планка тона)', () {
      final mood = computeEffectiveMood(
        harshTone: true,
        intensityMultiplier: 0.0,
        heat: 0.0,
      );
      expect(mood.harshness, closeTo(0.5, 0.001));
      expect(mood.level, MoodLevel.stern);
    });

    test('harsh + full + heat=0 → stern (0.5)', () {
      final mood = computeEffectiveMood(
        harshTone: true,
        intensityMultiplier: 1.0,
        heat: 0.0,
      );
      expect(mood.harshness, closeTo(0.5, 0.001));
      expect(mood.level, MoodLevel.stern);
    });

    test('harsh + full + heat=0.5 → angry (0.5 + 0.5 = 1.0)', () {
      final mood = computeEffectiveMood(
        harshTone: true,
        intensityMultiplier: 1.0,
        heat: 0.5,
      );
      expect(mood.harshness, closeTo(1.0, 0.001));
      expect(mood.level, MoodLevel.angry);
    });

    test('gentle + full + heat=0.5 → neutral (0.0 + 0.5 = 0.5 → stern)', () {
      final mood = computeEffectiveMood(
        harshTone: false,
        intensityMultiplier: 1.0,
        heat: 0.5,
      );
      expect(mood.harshness, closeTo(0.5, 0.001));
      expect(mood.level, MoodLevel.stern);
    });

    test('harshness clamp: не может превысить 1.0', () {
      final mood = computeEffectiveMood(
        harshTone: true,
        intensityMultiplier: 1.0,
        heat: 1.0,
      );
      expect(mood.harshness, closeTo(1.0, 0.001));
      expect(mood.level, MoodLevel.angry);
    });

    test('MoodLevel.calm: harshness < 0.20', () {
      final mood = computeEffectiveMood(
        harshTone: false,
        intensityMultiplier: 1.0,
        heat: 0.1, // 0.0 + 0.1 = 0.10 → calm
      );
      expect(mood.level, MoodLevel.calm);
    });

    test('MoodLevel.neutral: 0.20 ≤ harshness < 0.45', () {
      final mood = computeEffectiveMood(
        harshTone: false,
        intensityMultiplier: 1.0,
        heat: 0.30, // 0.30 → neutral
      );
      expect(mood.level, MoodLevel.neutral);
    });

    test('MoodLevel.stern: 0.45 ≤ harshness < 0.75', () {
      final mood = computeEffectiveMood(
        harshTone: false,
        intensityMultiplier: 1.0,
        heat: 0.60, // 0.60 → stern
      );
      expect(mood.level, MoodLevel.stern);
    });

    test('MoodLevel.angry: harshness ≥ 0.75', () {
      final mood = computeEffectiveMood(
        harshTone: false,
        intensityMultiplier: 1.0,
        heat: 0.80, // 0.80 → angry
      );
      expect(mood.level, MoodLevel.angry);
    });

    test('gentle + slight (0.5) + heat=0.4 → stern (0+0.2=0.2 → neutral; wait: 0.4*0.5=0.20 → neutral)', () {
      final mood = computeEffectiveMood(
        harshTone: false,
        intensityMultiplier: 0.5, // slight
        heat: 0.4,  // 0.4 * 0.5 = 0.20 → neutral (граница)
      );
      // 0.20 точно: < 0.45 → neutral
      expect(mood.level, MoodLevel.neutral);
    });
  });
}
