// Провайдер ручного переопределения макронутриентов (БЖУ/ккал).
//
// Пользователь может задать цели двумя способами:
//   1. Ручной режим (auto_balance = false) — задаёт белок/жир/углеводы вручную;
//      ккал = производное (protein*4 + carbs*4 + fat*9).
//   2. Авто-баланс (auto_balance = true) — задаётся цель ккал; при изменении
//      одного макроса остальные НЕЗАФИКСИРОВАННЫЕ пересчитываются так, чтобы
//      сумма калорий оставалась равной kcal_target.
//
// Если override не включён (macro_override_enabled = false) — nutritionTargetsProvider
// возвращает расчётные нормы по антропометрии (computeNutritionTargets).

import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/theme_provider.dart'; // sharedPreferencesProvider

// ---------------------------------------------------------------------------
// SharedPreferences ключи (snake_case)
// ---------------------------------------------------------------------------
const kMacroOverrideEnabledKey = 'macro_override_enabled'; // bool
const kMacroAutoBalanceKey = 'macro_auto_balance'; // bool
const kMacroKcalTargetKey = 'macro_kcal_target'; // int
const kMacroProteinGKey = 'macro_protein_g'; // int
const kMacroFatGKey = 'macro_fat_g'; // int
const kMacroCarbsGKey = 'macro_carbs_g'; // int
const kMacroLockProteinKey = 'macro_lock_protein'; // bool
const kMacroLockFatKey = 'macro_lock_fat'; // bool
const kMacroLockCarbsKey = 'macro_lock_carbs'; // bool

// ---------------------------------------------------------------------------
// Состояние переопределения макронутриентов
// ---------------------------------------------------------------------------

/// Полное состояние переопределения макронутриентов.
class MacroOverrideState {
  const MacroOverrideState({
    required this.enabled,
    required this.autoBalance,
    required this.kcalTarget,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
    required this.lockProtein,
    required this.lockFat,
    required this.lockCarbs,
  });

  /// Включён ли режим ручного переопределения (true → использовать эти значения).
  final bool enabled;

  /// true → авто-баланс: при изменении одного макроса остальные пересчитываются
  /// так, чтобы сумма = kcalTarget.
  /// false → ручной режим: ккал = производное от суммы макросов.
  final bool autoBalance;

  /// Цель по калориям (используется в режиме авто-баланса).
  final int kcalTarget;

  // Граммы макронутриентов
  final int proteinG;
  final int fatG;
  final int carbsG;

  // Флаги блокировки (в режиме авто-баланса заблокированный макрос не двигается)
  final bool lockProtein;
  final bool lockFat;
  final bool lockCarbs;

  /// Ккал как производное от макросов (protein*4 + carbs*4 + fat*9).
  int get derivedKcal => proteinG * 4 + carbsG * 4 + fatG * 9;

  /// Эффективные ккал: в авто-режиме = kcalTarget, в ручном = derivedKcal.
  int get effectiveKcal => autoBalance ? kcalTarget : derivedKcal;

  /// Множество заблокированных макросов для использования в rebalanceMacros.
  Set<String> get lockedSet {
    final s = <String>{};
    if (lockProtein) s.add('protein');
    if (lockFat) s.add('fat');
    if (lockCarbs) s.add('carbs');
    return s;
  }

  MacroOverrideState copyWith({
    bool? enabled,
    bool? autoBalance,
    int? kcalTarget,
    int? proteinG,
    int? fatG,
    int? carbsG,
    bool? lockProtein,
    bool? lockFat,
    bool? lockCarbs,
  }) {
    return MacroOverrideState(
      enabled: enabled ?? this.enabled,
      autoBalance: autoBalance ?? this.autoBalance,
      kcalTarget: kcalTarget ?? this.kcalTarget,
      proteinG: proteinG ?? this.proteinG,
      fatG: fatG ?? this.fatG,
      carbsG: carbsG ?? this.carbsG,
      lockProtein: lockProtein ?? this.lockProtein,
      lockFat: lockFat ?? this.lockFat,
      lockCarbs: lockCarbs ?? this.lockCarbs,
    );
  }

  /// Дефолтное состояние: переопределение выключено, авто-баланс включён,
  /// 2000 ккал / 100г белка / 65г жира / 250г углеводов (без блокировок).
  static const defaults = MacroOverrideState(
    enabled: false,
    autoBalance: true,
    kcalTarget: 2000,
    proteinG: 100,
    fatG: 65,
    carbsG: 250,
    lockProtein: false,
    lockFat: false,
    lockCarbs: false,
  );
}

// ---------------------------------------------------------------------------
// Чистая функция авто-баланса макросов (unit-тестируется отдельно)
// ---------------------------------------------------------------------------

/// Пересчитывает макросы при изменении одного значения в режиме авто-баланса.
///
/// Алгоритм:
/// 1. Устанавливает [changed] макрос в [newValueG].
/// 2. Вычисляет ккал, уже «занятые» изменённым макросом и всеми заблокированными.
/// 3. Оставшиеся ккал (remainingKcal = max(0, kcalTarget - usedKcal)) распределяет
///    пропорционально текущим граммам незаблокированных, неизменённых макросов.
///    Если все они равны нулю — делит поровну.
/// 4. Конвертирует ккал → граммы (÷4 для белка/углеводов, ÷9 для жира).
/// 5. Округляет и зажимает результат ≥ 0.
///
/// Граничные случаи:
/// - Все остальные макросы заблокированы → они не двигаются.
/// - kcalTarget слишком мал → незаблокированные остатки → 0.
/// - Единственный незаблокированный незменённый макрос получает всё оставшееся.
({int proteinG, int fatG, int carbsG}) rebalanceMacros({
  required String changed, // 'protein' | 'fat' | 'carbs'
  required int newValueG,
  required int kcalTarget,
  required Set<String> locked, // макросы, которые не должны двигаться
  required ({int proteinG, int fatG, int carbsG}) current,
}) {
  // Коэффициент ккал для каждого макроса
  int kcalFactor(String macro) => macro == 'fat' ? 9 : 4;

  // Итоговые граммы после изменения
  var protein = current.proteinG;
  var fat = current.fatG;
  var carbs = current.carbsG;

  // Шаг 1: ставим изменённый макрос
  switch (changed) {
    case 'protein':
      protein = math.max(0, newValueG);
    case 'fat':
      fat = math.max(0, newValueG);
    case 'carbs':
      carbs = math.max(0, newValueG);
  }

  // Шаг 2: вычисляем ккал, уже занятые изменённым + заблокированными
  int usedKcal = 0;
  // Изменённый макрос всегда учитывается
  usedKcal += switch (changed) {
    'protein' => protein * kcalFactor('protein'),
    'fat' => fat * kcalFactor('fat'),
    _ => carbs * kcalFactor('carbs'), // 'carbs'
  };
  // Заблокированные (не изменённые) — добавляем их ккал
  for (final m in locked) {
    if (m == changed) continue; // уже учтён выше
    usedKcal += switch (m) {
      'protein' => current.proteinG * kcalFactor('protein'),
      'fat' => current.fatG * kcalFactor('fat'),
      _ => current.carbsG * kcalFactor('carbs'), // 'carbs'
    };
    // Возвращаем в финальные переменные заблокированное значение
    // (могли быть затронуты логикой выше — нет, но явно фиксируем)
    switch (m) {
      case 'protein':
        protein = current.proteinG;
      case 'fat':
        fat = current.fatG;
      case 'carbs':
        carbs = current.carbsG;
    }
  }

  // Шаг 3: оставшиеся ккал
  final remainingKcal = math.max(0, kcalTarget - usedKcal);

  // Шаг 4: незаблокированные, неизменённые макросы
  final free = <String>[];
  for (final m in ['protein', 'fat', 'carbs']) {
    if (m != changed && !locked.contains(m)) {
      free.add(m);
    }
  }

  if (free.isEmpty || remainingKcal == 0) {
    // Ничего распределять нечего — незаблокированные свободные → 0
    for (final m in free) {
      switch (m) {
        case 'protein':
          protein = 0;
        case 'fat':
          fat = 0;
        case 'carbs':
          carbs = 0;
      }
    }
    return (proteinG: protein, fatG: fat, carbsG: carbs);
  }

  // Пропорции по текущим граммам (в ккал-единицах)
  final currentKcals = {for (final m in free) m: _currentKcalOf(m, current)};
  final totalCurrentKcal = currentKcals.values.fold(0, (a, b) => a + b);

  if (totalCurrentKcal == 0) {
    // Все свободные = 0 → делим поровну по ккал, конвертируем в граммы
    final kcalEach = remainingKcal ~/ free.length;
    final remainder = remainingKcal - kcalEach * free.length;
    for (int i = 0; i < free.length; i++) {
      final m = free[i];
      final kcal = kcalEach + (i == 0 ? remainder : 0);
      final grams = math.max(0, kcal ~/ kcalFactor(m));
      switch (m) {
        case 'protein':
          protein = grams;
        case 'fat':
          fat = grams;
        case 'carbs':
          carbs = grams;
      }
    }
  } else {
    // Пропорциональное распределение
    var distributed = 0;
    for (int i = 0; i < free.length; i++) {
      final m = free[i];
      final isLast = i == free.length - 1;
      final int kcalForMacro;
      if (isLast) {
        // Последнему — всё оставшееся (устраняет накопленную ошибку округления)
        kcalForMacro = remainingKcal - distributed;
      } else {
        kcalForMacro =
            (remainingKcal * currentKcals[m]! / totalCurrentKcal).round();
      }
      distributed += kcalForMacro;
      final grams = math.max(0, kcalForMacro ~/ kcalFactor(m));
      switch (m) {
        case 'protein':
          protein = grams;
        case 'fat':
          fat = grams;
        case 'carbs':
          carbs = grams;
      }
    }
  }

  return (proteinG: protein, fatG: fat, carbsG: carbs);
}

/// Возвращает текущее значение макроса в ккал из [current].
int _currentKcalOf(String macro, ({int proteinG, int fatG, int carbsG}) current) {
  return switch (macro) {
    'protein' => current.proteinG * 4,
    'fat' => current.fatG * 9,
    _ => current.carbsG * 4, // 'carbs'
  };
}

// ---------------------------------------------------------------------------
// MacroOverrideNotifier
// ---------------------------------------------------------------------------

/// Нотифер состояния ручного переопределения макронутриентов.
///
/// Публичные методы:
///   - [setEnabled]        — включить/выключить переопределение
///   - [setAutoBalance]    — переключить режим (авто-баланс / ручной)
///   - [setKcalTarget]     — установить цель ккал (только в авто-режиме)
///   - [setMacro]          — изменить один макрос; в авто-режиме пересчитывает остальные
///   - [setLock]           — зафиксировать макрос в авто-режиме
///   - [reset]             — снять переопределение (возврат к расчётным нормам)
class MacroOverrideNotifier extends Notifier<MacroOverrideState> {
  @override
  MacroOverrideState build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return _loadFromPrefs(prefs);
  }

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  // --- Публичные методы ---

  /// Включить или выключить режим ручного переопределения.
  Future<void> setEnabled(bool enabled) async {
    await _prefs.setBool(kMacroOverrideEnabledKey, enabled);
    state = state.copyWith(enabled: enabled);
  }

  /// Переключить режим: true = авто-баланс, false = ручной.
  Future<void> setAutoBalance(bool autoBalance) async {
    await _prefs.setBool(kMacroAutoBalanceKey, autoBalance);
    state = state.copyWith(autoBalance: autoBalance);
  }

  /// Установить цель ккал (используется только в режиме авто-баланса).
  Future<void> setKcalTarget(int kcal) async {
    final clamped = math.max(0, kcal);
    await _prefs.setInt(kMacroKcalTargetKey, clamped);
    state = state.copyWith(kcalTarget: clamped);
  }

  /// Изменить один макрос ([macro] = 'protein' | 'fat' | 'carbs').
  ///
  /// В авто-режиме пересчитывает незаблокированные остальные.
  /// В ручном режиме — просто сохраняет значение.
  Future<void> setMacro(String macro, int grams) async {
    final newGrams = math.max(0, grams);
    if (state.autoBalance) {
      final result = rebalanceMacros(
        changed: macro,
        newValueG: newGrams,
        kcalTarget: state.kcalTarget,
        locked: state.lockedSet,
        current: (
          proteinG: state.proteinG,
          fatG: state.fatG,
          carbsG: state.carbsG,
        ),
      );
      await _saveAllMacros(result.proteinG, result.fatG, result.carbsG);
      state = state.copyWith(
        proteinG: result.proteinG,
        fatG: result.fatG,
        carbsG: result.carbsG,
      );
    } else {
      await _saveSingleMacro(macro, newGrams);
      state = switch (macro) {
        'protein' => state.copyWith(proteinG: newGrams),
        'fat' => state.copyWith(fatG: newGrams),
        _ => state.copyWith(carbsG: newGrams), // 'carbs'
      };
    }
  }

  /// Зафиксировать или разблокировать конкретный макрос.
  Future<void> setLock(String macro, bool locked) async {
    switch (macro) {
      case 'protein':
        await _prefs.setBool(kMacroLockProteinKey, locked);
        state = state.copyWith(lockProtein: locked);
      case 'fat':
        await _prefs.setBool(kMacroLockFatKey, locked);
        state = state.copyWith(lockFat: locked);
      case 'carbs':
        await _prefs.setBool(kMacroLockCarbsKey, locked);
        state = state.copyWith(lockCarbs: locked);
    }
  }

  /// Снять переопределение и вернуться к расчётным нормам.
  Future<void> reset() async {
    await _prefs.setBool(kMacroOverrideEnabledKey, false);
    await _prefs.remove(kMacroAutoBalanceKey);
    await _prefs.remove(kMacroKcalTargetKey);
    await _prefs.remove(kMacroProteinGKey);
    await _prefs.remove(kMacroFatGKey);
    await _prefs.remove(kMacroCarbsGKey);
    await _prefs.remove(kMacroLockProteinKey);
    await _prefs.remove(kMacroLockFatKey);
    await _prefs.remove(kMacroLockCarbsKey);
    state = MacroOverrideState.defaults;
  }

  // --- Вспомогательные ---

  Future<void> _saveSingleMacro(String macro, int grams) async {
    switch (macro) {
      case 'protein':
        await _prefs.setInt(kMacroProteinGKey, grams);
      case 'fat':
        await _prefs.setInt(kMacroFatGKey, grams);
      case 'carbs':
        await _prefs.setInt(kMacroCarbsGKey, grams);
    }
  }

  Future<void> _saveAllMacros(int protein, int fat, int carbs) async {
    await _prefs.setInt(kMacroProteinGKey, protein);
    await _prefs.setInt(kMacroFatGKey, fat);
    await _prefs.setInt(kMacroCarbsGKey, carbs);
  }
}

/// Читает состояние переопределения из SharedPreferences.
MacroOverrideState _loadFromPrefs(SharedPreferences prefs) {
  return MacroOverrideState(
    enabled: prefs.getBool(kMacroOverrideEnabledKey) ?? false,
    autoBalance: prefs.getBool(kMacroAutoBalanceKey) ?? true,
    kcalTarget:
        prefs.getInt(kMacroKcalTargetKey) ?? MacroOverrideState.defaults.kcalTarget,
    proteinG:
        prefs.getInt(kMacroProteinGKey) ?? MacroOverrideState.defaults.proteinG,
    fatG: prefs.getInt(kMacroFatGKey) ?? MacroOverrideState.defaults.fatG,
    carbsG: prefs.getInt(kMacroCarbsGKey) ?? MacroOverrideState.defaults.carbsG,
    lockProtein: prefs.getBool(kMacroLockProteinKey) ?? false,
    lockFat: prefs.getBool(kMacroLockFatKey) ?? false,
    lockCarbs: prefs.getBool(kMacroLockCarbsKey) ?? false,
  );
}

/// Провайдер состояния переопределения макронутриентов.
///
/// Используется в nutritionTargetsProvider и в UI-экране редактирования макросов.
final macroOverrideProvider =
    NotifierProvider<MacroOverrideNotifier, MacroOverrideState>(
  MacroOverrideNotifier.new,
);
