// Юнит-тесты для computeNutritionTargets, NutritionTargets.fallback,
// rebalanceMacros и nutritionTargetsProvider (с переопределением).

import 'package:app/core/settings/macro_override_provider.dart';
import 'package:app/core/settings/nutrition_targets.dart';
import 'package:app/core/theme/theme_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // ==========================================================================
  // Секция 1: computeNutritionTargets — существующие тесты
  // ==========================================================================

  // --- Тест 1: мужчина 70 кг / 175 см / 25 лет / medium-активность ---
  // BMR = 10*70 + 6.25*175 - 5*25 + 5 = 700 + 1093.75 - 125 + 5 = 1673.75
  // TDEE = 1673.75 * 1.55 ≈ 2594.3 → round → 2594, clamp(1200,4000) → 2594
  // protein = round(1.6 * 70) = 112 г
  // fat = round(2594 * 0.25 / 9) = round(72.06) = 72 г
  // carbs = round((2594 - 112*4 - 72*9) / 4) = round((2594 - 448 - 648) / 4)
  //       = round(1498 / 4) = round(374.5) = 375 (или близко)
  // fiber = round(14 * 2594 / 1000) = round(36.3) = 36 г
  // sugarMax = round(2594 * 0.10 / 4) = round(64.85) = 65 г
  group('male 70kg/175cm/25/medium', () {
    late NutritionTargets t;

    setUpAll(() {
      t = computeNutritionTargets(
        weightKg: 70,
        heightCm: 175,
        age: 25,
        sex: 'male',
        activity: 'medium',
      );
    });

    test('kcal в ожидаемом диапазоне', () {
      expect(t.kcal, inInclusiveRange(2500, 2700));
    });

    test('protein ≈ 1.6 × 70 = 112 г', () {
      expect(t.proteinG, 112);
    });

    test('fat > 0 и в разумном диапазоне', () {
      expect(t.fatG, greaterThan(50));
      expect(t.fatG, lessThan(100));
    });

    test('carbs > 0', () {
      expect(t.carbsG, greaterThan(0));
    });

    test('fiber ≈ 14 г/1000 ккал', () {
      final expected = (14.0 * t.kcal / 1000).round();
      expect(t.fiberG, expected);
    });

    test('sugarMax ≈ 10% ккал / 4', () {
      final expected = (t.kcal * 0.10 / 4).round();
      expect(t.sugarMaxG, expected);
    });
  });

  // --- Тест 2: женщина 60 кг / 165 см / 30 лет / high-активность ---
  // BMR = 10*60 + 6.25*165 - 5*30 - 161 = 600 + 1031.25 - 150 - 161 = 1320.25
  // TDEE = 1320.25 * 1.725 ≈ 2277.4 → 2277
  group('female 60kg/165cm/30/high', () {
    late NutritionTargets t;

    setUpAll(() {
      t = computeNutritionTargets(
        weightKg: 60,
        heightCm: 165,
        age: 30,
        sex: 'female',
        activity: 'high',
      );
    });

    test('kcal в ожидаемом диапазоне', () {
      expect(t.kcal, inInclusiveRange(2100, 2400));
    });

    test('protein = round(1.6 * 60) = 96 г', () {
      expect(t.proteinG, 96);
    });

    test('carbs > 0', () {
      expect(t.carbsG, greaterThan(0));
    });
  });

  // --- Тест 3: пол 'other' --- среднее смещение -78 ---
  test('sex=other использует смещение -78', () {
    final other = computeNutritionTargets(
      weightKg: 70,
      heightCm: 175,
      age: 25,
      sex: 'other',
      activity: 'medium',
    );
    final male = computeNutritionTargets(
      weightKg: 70,
      heightCm: 175,
      age: 25,
      sex: 'male',
      activity: 'medium',
    );
    final female = computeNutritionTargets(
      weightKg: 70,
      heightCm: 175,
      age: 25,
      sex: 'female',
      activity: 'medium',
    );
    // other ккал должны быть между female и male
    expect(other.kcal, lessThan(male.kcal));
    expect(other.kcal, greaterThan(female.kcal));
  });

  // --- Тест 4: clamp снизу (очень низкий BMR → min 1200) ---
  test('clamp kcal снизу: минимум 1200', () {
    final t = computeNutritionTargets(
      weightKg: 40,
      heightCm: 145,
      age: 80,
      sex: 'female',
      activity: 'low',
    );
    expect(t.kcal, greaterThanOrEqualTo(1200));
  });

  // --- Тест 5: clamp сверху (очень высокий BMR → max 4000) ---
  test('clamp kcal сверху: максимум 4000', () {
    final t = computeNutritionTargets(
      weightKg: 150,
      heightCm: 210,
      age: 20,
      sex: 'male',
      activity: 'high',
    );
    expect(t.kcal, lessThanOrEqualTo(4000));
  });

  // --- Тест 6: fallback имеет разумные значения ---
  test('NutritionTargets.fallback содержит ожидаемые дефолты', () {
    const f = NutritionTargets.fallback;
    expect(f.kcal, kDefaultNutritionKcal);
    expect(f.proteinG, kDefaultNutritionProteinG);
    expect(f.fatG, kDefaultNutritionFatG);
    expect(f.carbsG, kDefaultNutritionCarbsG);
    expect(f.fiberG, kDefaultNutritionFiberG);
    expect(f.sugarMaxG, kDefaultNutritionSugarMaxG);
  });

  // --- Тест 7: активность low / medium / high дают разные ккал ---
  test('activity влияет на kcal (low < medium < high)', () {
    NutritionTargets build(String act) => computeNutritionTargets(
          weightKg: 70,
          heightCm: 175,
          age: 25,
          sex: 'male',
          activity: act,
        );
    final low = build('low');
    final medium = build('medium');
    final high = build('high');
    expect(low.kcal, lessThan(medium.kcal));
    expect(medium.kcal, lessThan(high.kcal));
  });

  // --- Тест 8: неизвестная активность трактуется как medium ---
  test('неизвестная activity трактуется как medium', () {
    final unknown = computeNutritionTargets(
      weightKg: 70,
      heightCm: 175,
      age: 25,
      sex: 'male',
      activity: 'extreme',
    );
    final medium = computeNutritionTargets(
      weightKg: 70,
      heightCm: 175,
      age: 25,
      sex: 'male',
      activity: 'medium',
    );
    expect(unknown.kcal, medium.kcal);
  });

  // --- Тест 9: goal=maintain (дефолт) не меняет ккал ---
  test('goal=maintain совпадает с отсутствием параметра (множитель 1.0)', () {
    final base = computeNutritionTargets(
      weightKg: 70,
      heightCm: 175,
      age: 25,
      sex: 'male',
      activity: 'medium',
    );
    final maintain = computeNutritionTargets(
      weightKg: 70,
      heightCm: 175,
      age: 25,
      sex: 'male',
      activity: 'medium',
      goal: 'maintain',
    );
    expect(maintain.kcal, base.kcal);
  });

  // --- Тест 10: goal=lose уменьшает ккал на ~15% (множитель 0.85) ---
  group('goal multipliers', () {
    late NutritionTargets maintain;
    late NutritionTargets lose;
    late NutritionTargets gain;

    setUpAll(() {
      // male 80kg / 180cm / 22y / medium — TDEE ≈ 2800, далеко от clamp-границ
      maintain = computeNutritionTargets(
        weightKg: 80,
        heightCm: 180,
        age: 22,
        sex: 'male',
        activity: 'medium',
        goal: 'maintain',
      );
      lose = computeNutritionTargets(
        weightKg: 80,
        heightCm: 180,
        age: 22,
        sex: 'male',
        activity: 'medium',
        goal: 'lose',
      );
      gain = computeNutritionTargets(
        weightKg: 80,
        heightCm: 180,
        age: 22,
        sex: 'male',
        activity: 'medium',
        goal: 'gain',
      );
    });

    test('lose < maintain (ккал снижены на 15%)', () {
      expect(lose.kcal, lessThan(maintain.kcal));
      // Ожидаемое значение: round(maintain * 0.85); допуск ±5 из-за округлений
      final expected = (maintain.kcal * 0.85).round();
      expect(lose.kcal, closeTo(expected, 5));
    });

    test('gain > maintain (ккал увеличены на 15%)', () {
      expect(gain.kcal, greaterThan(maintain.kcal));
      final expected = (maintain.kcal * 1.15).round();
      expect(gain.kcal, closeTo(expected, 5));
    });

    test('lose < maintain < gain (порядок)', () {
      expect(lose.kcal, lessThan(maintain.kcal));
      expect(maintain.kcal, lessThan(gain.kcal));
    });

    test('макросы пересчитываются от скорректированных kcal', () {
      // fat = round(kcal * 0.25 / 9)
      expect(lose.fatG, (lose.kcal * 0.25 / 9).round());
      expect(gain.fatG, (gain.kcal * 0.25 / 9).round());
    });

    test('неизвестная goal трактуется как maintain', () {
      final unknown = computeNutritionTargets(
        weightKg: 80,
        heightCm: 180,
        age: 22,
        sex: 'male',
        activity: 'medium',
        goal: 'bulk',
      );
      expect(unknown.kcal, maintain.kcal);
    });
  });

  // ==========================================================================
  // Секция 2: rebalanceMacros — чистая логика авто-баланса
  // ==========================================================================

  group('rebalanceMacros', () {
    // Базовый хелпер: текущие значения для большинства тестов
    const base = (proteinG: 100, fatG: 60, carbsG: 200);
    // 100*4 + 60*9 + 200*4 = 400+540+800 = 1740 ккал при base

    // -------------------------------------------------------------------------
    // 2.1. Ручной режим (сумма ккал = производное) — просто проверяем что
    //      rebalanceMacros корректно устанавливает changed-макрос. В ручном
    //      режиме вызывать rebalanceMacros не нужно (provider обходит её),
    //      но алгоритм должен работать корректно и при locked = everything.
    // -------------------------------------------------------------------------

    test('ручной режим (все locked): изменённый макрос устанавливается, остальные не двигаются', () {
      final r = rebalanceMacros(
        changed: 'protein',
        newValueG: 150,
        kcalTarget: 2000,
        locked: const {'fat', 'carbs'},
        current: base,
      );
      // protein = 150 (изменён)
      // fat = 60 (заблокирован)
      // carbs = 200 (заблокирован)
      expect(r.proteinG, 150);
      expect(r.fatG, 60);
      expect(r.carbsG, 200);
    });

    // -------------------------------------------------------------------------
    // 2.2. Авто-баланс: изменяем protein, fat и carbs подстраиваются
    // -------------------------------------------------------------------------

    test('авто-баланс: изменение protein пересчитывает carbs и fat', () {
      // kcalTarget = 2000; protein → 150 (150*4=600 ккал)
      // оставшиеся = 2000 - 600 = 1400 ккал на fat+carbs
      // пропорция fat:carbs в ккал = 60*9 : 200*4 = 540 : 800
      final r = rebalanceMacros(
        changed: 'protein',
        newValueG: 150,
        kcalTarget: 2000,
        locked: const {},
        current: base,
      );
      expect(r.proteinG, 150);
      // Kcal ≈ 2000; допуск ~16 из-за ceil/floor при конвертации ккал→граммы
      // (max 8 ккал на макрос, 2 макроса = 16)
      final derivedKcal = r.proteinG * 4 + r.fatG * 9 + r.carbsG * 4;
      expect(derivedKcal, closeTo(2000, 20));
    });

    test('авто-баланс: изменение fat пересчитывает protein и carbs', () {
      final r = rebalanceMacros(
        changed: 'fat',
        newValueG: 80,
        kcalTarget: 2000,
        locked: const {},
        current: base,
      );
      expect(r.fatG, 80);
      final derivedKcal = r.proteinG * 4 + r.fatG * 9 + r.carbsG * 4;
      expect(derivedKcal, closeTo(2000, 20));
    });

    test('авто-баланс: изменение carbs пересчитывает protein и fat', () {
      final r = rebalanceMacros(
        changed: 'carbs',
        newValueG: 250,
        kcalTarget: 2000,
        locked: const {},
        current: base,
      );
      expect(r.carbsG, 250);
      final derivedKcal = r.proteinG * 4 + r.fatG * 9 + r.carbsG * 4;
      expect(derivedKcal, closeTo(2000, 20));
    });

    // -------------------------------------------------------------------------
    // 2.3. Блокировки: заблокированные макросы не двигаются
    // -------------------------------------------------------------------------

    test('lockProtein: fat заблокирован → только carbs подстраивается', () {
      // protein → 150; fat заблокировано (60г = 540 ккал)
      // 2000 - 600 (protein) - 540 (fat) = 860 ккал → carbs = 860/4 = 215
      final r = rebalanceMacros(
        changed: 'protein',
        newValueG: 150,
        kcalTarget: 2000,
        locked: const {'fat'},
        current: base,
      );
      expect(r.proteinG, 150);
      expect(r.fatG, 60); // заблокирован
      expect(r.carbsG, greaterThan(0));
      // Единственный свободный макрос (carbs) получает весь remainingKcal:
      // carbs = 860 ~/ 4 = 215; derivedKcal = 600 + 540 + 860 = 2000 точно
      final derivedKcal = r.proteinG * 4 + r.fatG * 9 + r.carbsG * 4;
      expect(derivedKcal, closeTo(2000, 5));
    });

    test('lockCarbs: carbs заблокированы → только fat подстраивается', () {
      final r = rebalanceMacros(
        changed: 'protein',
        newValueG: 80,
        kcalTarget: 2000,
        locked: const {'carbs'},
        current: base,
      );
      expect(r.proteinG, 80);
      expect(r.carbsG, 200); // заблокированы
      // fat подстраивается; допуск 9 (max kcalFactor для fat)
      final derivedKcal = r.proteinG * 4 + r.fatG * 9 + r.carbsG * 4;
      expect(derivedKcal, closeTo(2000, 20));
    });

    // -------------------------------------------------------------------------
    // 2.4. Граничный случай: kcalTarget слишком мал → свободные → 0
    // -------------------------------------------------------------------------

    test('kcalTarget меньше ккал изменённого макроса → свободные = 0', () {
      // protein → 200 (200*4 = 800 ккал), kcalTarget = 500
      // 500 - 800 = -300 → remainingKcal = 0 → fat=0, carbs=0
      final r = rebalanceMacros(
        changed: 'protein',
        newValueG: 200,
        kcalTarget: 500,
        locked: const {},
        current: base,
      );
      expect(r.proteinG, 200);
      expect(r.fatG, 0);
      expect(r.carbsG, 0);
    });

    // -------------------------------------------------------------------------
    // 2.5. Граничный случай: все свободные = 0 → равный сплит
    // -------------------------------------------------------------------------

    test('все свободные = 0 → равный сплит remainingKcal', () {
      // current: protein=0, fat=0, carbs=0; protein → 50 (200 ккал)
      // remaining = 2000 - 200 = 1800 → fat, carbs делят поровну: 900 ккал каждый
      // fat = 900/9 = 100; carbs = 900/4 = 225
      final r = rebalanceMacros(
        changed: 'protein',
        newValueG: 50,
        kcalTarget: 2000,
        locked: const {},
        current: (proteinG: 0, fatG: 0, carbsG: 0),
      );
      expect(r.proteinG, 50);
      expect(r.fatG, greaterThan(0));
      expect(r.carbsG, greaterThan(0));
      // Kcal примерно 2000 (±2 из-за целочисленного деления)
      final derivedKcal = r.proteinG * 4 + r.fatG * 9 + r.carbsG * 4;
      expect(derivedKcal, closeTo(2000, 10));
    });

    // -------------------------------------------------------------------------
    // 2.6. Граничный случай: все locked + changed → только changed двигается
    // -------------------------------------------------------------------------

    test('все non-changed заблокированы → только changed устанавливается', () {
      final r = rebalanceMacros(
        changed: 'carbs',
        newValueG: 300,
        kcalTarget: 2000,
        locked: const {'protein', 'fat'},
        current: base,
      );
      expect(r.carbsG, 300);
      expect(r.proteinG, 100); // заблокирован
      expect(r.fatG, 60);     // заблокирован
    });

    // -------------------------------------------------------------------------
    // 2.7. Граничный случай: единственный незаблокированный получает весь остаток
    // -------------------------------------------------------------------------

    test('один свободный макрос получает весь remainingKcal', () {
      // protein → 100; fat заблокирован (60г = 540 ккал);
      // остаток = 2000 - 400 - 540 = 1060 ккал → carbs = 1060/4 = 265
      final r = rebalanceMacros(
        changed: 'protein',
        newValueG: 100,
        kcalTarget: 2000,
        locked: const {'fat'},
        current: base,
      );
      expect(r.proteinG, 100);
      expect(r.fatG, 60);
      expect(r.carbsG, (2000 - 100 * 4 - 60 * 9) ~/ 4);
    });

    // -------------------------------------------------------------------------
    // 2.8. Зажим отрицательного ввода: newValueG < 0 → 0
    // -------------------------------------------------------------------------

    test('newValueG < 0 зажимается в 0', () {
      final r = rebalanceMacros(
        changed: 'protein',
        newValueG: -50,
        kcalTarget: 2000,
        locked: const {},
        current: base,
      );
      expect(r.proteinG, 0);
    });

    // -------------------------------------------------------------------------
    // 2.9. Нет изменений: protein → текущее значение; суммы не меняются
    // -------------------------------------------------------------------------

    test('изменение на то же значение — стабильность', () {
      final r = rebalanceMacros(
        changed: 'protein',
        newValueG: base.proteinG,
        kcalTarget: 2000,
        locked: const {},
        current: base,
      );
      // Kcal остаётся ~2000; допуск 20 из-за целочисленного округления
      final derivedKcal = r.proteinG * 4 + r.fatG * 9 + r.carbsG * 4;
      expect(derivedKcal, closeTo(2000, 20));
    });
  });

  // ==========================================================================
  // Секция 3: MacroOverrideState — вспомогательные свойства
  // ==========================================================================

  group('MacroOverrideState', () {
    test('derivedKcal считается правильно', () {
      const s = MacroOverrideState(
        enabled: true,
        autoBalance: false,
        kcalTarget: 2000,
        proteinG: 100, // 400 ккал
        fatG: 60,      // 540 ккал
        carbsG: 200,   // 800 ккал
        lockProtein: false,
        lockFat: false,
        lockCarbs: false,
      );
      expect(s.derivedKcal, 1740);
    });

    test('effectiveKcal = kcalTarget в авто-режиме', () {
      const s = MacroOverrideState(
        enabled: true,
        autoBalance: true,
        kcalTarget: 1800,
        proteinG: 100,
        fatG: 60,
        carbsG: 200,
        lockProtein: false,
        lockFat: false,
        lockCarbs: false,
      );
      expect(s.effectiveKcal, 1800);
    });

    test('effectiveKcal = derivedKcal в ручном режиме', () {
      const s = MacroOverrideState(
        enabled: true,
        autoBalance: false,
        kcalTarget: 9999, // игнорируется
        proteinG: 100,
        fatG: 60,
        carbsG: 200,
        lockProtein: false,
        lockFat: false,
        lockCarbs: false,
      );
      expect(s.effectiveKcal, s.derivedKcal);
    });

    test('lockedSet содержит ровно заблокированные ключи', () {
      const s = MacroOverrideState(
        enabled: true,
        autoBalance: true,
        kcalTarget: 2000,
        proteinG: 100,
        fatG: 60,
        carbsG: 200,
        lockProtein: true,
        lockFat: false,
        lockCarbs: true,
      );
      expect(s.lockedSet, equals({'protein', 'carbs'}));
    });
  });

  // ==========================================================================
  // Секция 4: nutritionTargetsProvider — override vs computed
  // ==========================================================================

  group('nutritionTargetsProvider', () {
    // Когда override выключен и антропометрия отсутствует → fallback
    test('без антропометрии и без override → fallback', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      final targets = container.read(nutritionTargetsProvider);
      expect(targets.kcal, kDefaultNutritionKcal);
      expect(targets.proteinG, kDefaultNutritionProteinG);
    });

    // Когда антропометрия заполнена и override выключен → computeNutritionTargets
    test('с антропометрией и override=false → computeNutritionTargets', () async {
      SharedPreferences.setMockInitialValues({
        'user_weight_kg': 70.0,
        'user_height_cm': 175,
        'user_age': 25,
        'user_sex': 'male',
        'user_activity': 'medium',
        kMacroOverrideEnabledKey: false,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      final targets = container.read(nutritionTargetsProvider);
      // Вычисленные нормы должны быть близки к расчётным (не дефолт 2000)
      expect(targets.kcal, inInclusiveRange(2500, 2700));
      expect(targets.proteinG, 112); // 1.6 * 70
    });

    // Когда override включён → значения из переопределения (ручной режим)
    test('override=true, autoBalance=false → manual values, kcal = derivedKcal', () async {
      SharedPreferences.setMockInitialValues({
        kMacroOverrideEnabledKey: true,
        kMacroAutoBalanceKey: false,
        kMacroKcalTargetKey: 9999, // в ручном режиме игнорируется
        kMacroProteinGKey: 150,
        kMacroFatGKey: 60,
        kMacroCarbsGKey: 200,
        kMacroLockProteinKey: false,
        kMacroLockFatKey: false,
        kMacroLockCarbsKey: false,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      final targets = container.read(nutritionTargetsProvider);
      expect(targets.proteinG, 150);
      expect(targets.fatG, 60);
      expect(targets.carbsG, 200);
      // ккал = derivedKcal = 150*4 + 60*9 + 200*4 = 600+540+800 = 1940
      expect(targets.kcal, 1940);
    });

    // Когда override включён в авто-режиме → kcal = kcalTarget
    test('override=true, autoBalance=true → kcal = kcalTarget', () async {
      SharedPreferences.setMockInitialValues({
        kMacroOverrideEnabledKey: true,
        kMacroAutoBalanceKey: true,
        kMacroKcalTargetKey: 1800,
        kMacroProteinGKey: 120,
        kMacroFatGKey: 55,
        kMacroCarbsGKey: 190,
        kMacroLockProteinKey: false,
        kMacroLockFatKey: false,
        kMacroLockCarbsKey: false,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      final targets = container.read(nutritionTargetsProvider);
      expect(targets.proteinG, 120);
      expect(targets.fatG, 55);
      expect(targets.carbsG, 190);
      expect(targets.kcal, 1800); // = kcalTarget, не derivedKcal
    });

    // Клетчатка и сахар производятся от effectiveKcal при override
    test('override: fiber и sugarMax производятся от effectiveKcal', () async {
      SharedPreferences.setMockInitialValues({
        kMacroOverrideEnabledKey: true,
        kMacroAutoBalanceKey: true,
        kMacroKcalTargetKey: 2000,
        kMacroProteinGKey: 100,
        kMacroFatGKey: 65,
        kMacroCarbsGKey: 250,
        kMacroLockProteinKey: false,
        kMacroLockFatKey: false,
        kMacroLockCarbsKey: false,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      final targets = container.read(nutritionTargetsProvider);
      // fiber = max(25, round(14 * 2000 / 1000)) = max(25, 28) = 28
      expect(targets.fiberG, 28);
      // sugarMax = round(2000 * 0.10 / 4) = 50
      expect(targets.sugarMaxG, 50);
    });
  });
}
