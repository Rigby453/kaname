// Именованные параметры конструктора не могут начинаться с "_", поэтому поля
// присваиваются через список инициализации.
// ignore_for_file: prefer_initializing_formals

// Сервис начисления заморозок стрика (offline-first, Drift + SharedPreferences).
//
// ПРАВИЛА:
//   Free:    +1 заморозка каждые 30 дней.
//   Premium: +1 заморозка каждые 14 дней.
//   При покупке Premium: разовый бонус +2 заморозки (вызвать grantPurchaseBonus()).
//
//   Хранение:
//     • last_freeze_accrual_at (ISO-строка) в SharedPreferences.
//     • freezeCount хранится в Drift StreakTable (обновляем через StreakDao).
//
//   При старте/открытии профиля:
//     Если lastAccrual не инициализирован → инициализируем now (без выдачи).
//     Пока (now - lastAccrual) >= cadence → +1, lastAccrual += cadence.
//
//   НАГРАДЫ ЗА НАКОПЛЕНИЕ (каждый порог один раз за жизнь, в prefs):
//     10 заморозок → +7 дней Premium.
//     25 заморозок → +30 дней Premium.
//     50 заморозок → +90 дней Premium.
//
//   "Выдать Premium" = продлить local_premium_until в SharedPreferences.
//   isPremiumProvider учитывает это поле наравне с серверным тиром.
//
// Синхронизация заморозок (ADR-044): SyncService отправляет freeze_count +
// last_freeze_accrual_at на сервер через /sync (блок streak), а при ответе
// адоптирует серверные значения (LWW). Начисление остаётся клиентским —
// сервер только хранит/мерджит для мульти-девайс.

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/daos/streak_dao.dart';
import '../../core/database/database.dart' show StreakTableCompanion;
import '../../core/database/database_providers.dart';
import '../../core/theme/theme_provider.dart' show sharedPreferencesProvider;

// ---------------------------------------------------------------------------
// SharedPreferences ключи
// ---------------------------------------------------------------------------

/// ISO-дата последнего начисления заморозки.
const kLastFreezeAccrualKey = 'last_freeze_accrual_at';

/// Набор уже применённых порогов наград (хранится как список int через JSON).
/// Пример значений: [10, 25].
const kFreezeRewardClaimedKey = 'freeze_reward_claimed_thresholds';

/// Локальный override Premium (ISO-дата «до когда»).
/// isPremiumProvider проверяет это значение наравне с серверным tier.
const kLocalPremiumUntilKey = 'local_premium_until';

/// Флаг идемпотентности стартового гранта заморозок.
/// true = грант уже выдан; повторно не выдаётся никогда (даже при смене тира).
const kStarterFreezeGrantedKey = 'starter_freeze_granted';

// ---------------------------------------------------------------------------
// Пороги наград
// ---------------------------------------------------------------------------

/// Определение одного порога: необходимое число заморозок → добавляемые дни Premium.
class FreezeRewardThreshold {
  const FreezeRewardThreshold({
    required this.freezeCount,
    required this.premiumDays,
  });

  final int freezeCount;
  final int premiumDays;
}

/// Все пороги наград по возрастанию.
const List<FreezeRewardThreshold> kFreezeRewardThresholds = [
  FreezeRewardThreshold(freezeCount: 10, premiumDays: 7),
  FreezeRewardThreshold(freezeCount: 25, premiumDays: 30),
  FreezeRewardThreshold(freezeCount: 50, premiumDays: 90),
];

// ---------------------------------------------------------------------------
// Чистая логика начисления (тестируемая без Flutter/Riverpod)
// ---------------------------------------------------------------------------

/// Результат одного прогона начисления.
class AccrualResult {
  const AccrualResult({
    required this.addedFreezes,
    required this.newLastAccrual,
    required this.newlyClaimedThresholds,
    required this.addedPremiumDays,
  });

  /// Сколько заморозок добавлено в этом вызове.
  final int addedFreezes;

  /// Обновлённое время последнего начисления.
  final DateTime newLastAccrual;

  /// Пороги наград, впервые достигнутые в этом вызове (не пересекаются с уже claimed).
  final List<int> newlyClaimedThresholds;

  /// Суммарно добавляемых дней Premium за новые пороги.
  final int addedPremiumDays;
}

/// Вычислить результат начисления без сайд-эффектов.
///
/// [now]            — текущий момент (UTC).
/// [lastAccrual]    — null если ещё не инициализировано.
/// [cadenceDays]    — 14 для Premium, 30 для Free.
/// [currentFreezes] — текущее число заморозок.
/// [claimedThresholds] — множество уже полученных порогов (по freezeCount).
AccrualResult computeAccrual({
  required DateTime now,
  required DateTime? lastAccrual,
  required int cadenceDays,
  required int currentFreezes,
  required Set<int> claimedThresholds,
}) {
  // Инициализация: если нет lastAccrual — ставим now, ничего не начисляем.
  if (lastAccrual == null) {
    return AccrualResult(
      addedFreezes: 0,
      newLastAccrual: now,
      newlyClaimedThresholds: [],
      addedPremiumDays: 0,
    );
  }

  final cadence = Duration(days: cadenceDays);
  var cursor = lastAccrual;
  var added = 0;

  // Начисляем по одной заморозке за каждый истёкший cadence-период.
  while (now.difference(cursor) >= cadence) {
    cursor = cursor.add(cadence);
    added++;
  }

  final newFreezes = currentFreezes + added;

  // Проверяем пороги наград: только те, что ещё не claimed и теперь достигнуты.
  final List<int> newlyClaimed = [];
  int premiumDays = 0;
  for (final t in kFreezeRewardThresholds) {
    if (!claimedThresholds.contains(t.freezeCount) &&
        newFreezes >= t.freezeCount) {
      newlyClaimed.add(t.freezeCount);
      premiumDays += t.premiumDays;
    }
  }

  return AccrualResult(
    addedFreezes: added,
    newLastAccrual: cursor,
    newlyClaimedThresholds: newlyClaimed,
    addedPremiumDays: premiumDays,
  );
}

// ---------------------------------------------------------------------------
// Чистая логика стартового гранта (тестируемая без Flutter/Riverpod)
// ---------------------------------------------------------------------------

/// Вычислить стартовый грант заморозок без сайд-эффектов.
///
/// Free → 1, Premium → 3.
/// Если грант уже был выдан ([alreadyGranted] == true) — возвращает 0.
/// Позднейшая смена тира не даёт доначисления: бонус один раз за жизнь.
int computeStarterGrant({
  required bool isPremium,
  required bool alreadyGranted,
}) {
  if (alreadyGranted) return 0;
  return isPremium ? 3 : 1;
}

// ---------------------------------------------------------------------------
// Сервис (сайд-эффекты: Drift + SharedPreferences)
// ---------------------------------------------------------------------------

class FreezeAccrualService {
  FreezeAccrualService({
    required StreakDao streakDao,
    required SharedPreferences prefs,
  })  : _streakDao = streakDao,
        _prefs = prefs;

  final StreakDao _streakDao;
  final SharedPreferences _prefs;

  // ---- Хелперы чтения prefs ----

  DateTime? get _lastAccrual {
    final raw = _prefs.getString(kLastFreezeAccrualKey);
    if (raw == null) return null;
    try {
      return DateTime.parse(raw).toUtc();
    } catch (_) {
      return null;
    }
  }

  Set<int> get _claimedThresholds {
    final raw = _prefs.getStringList(kFreezeRewardClaimedKey) ?? [];
    return raw.map(int.parse).toSet();
  }

  DateTime? get localPremiumUntil {
    final raw = _prefs.getString(kLocalPremiumUntilKey);
    if (raw == null) return null;
    try {
      return DateTime.parse(raw).toUtc();
    } catch (_) {
      return null;
    }
  }

  bool get isLocalPremiumActive {
    final until = localPremiumUntil;
    if (until == null) return false;
    return DateTime.now().toUtc().isBefore(until);
  }

  // ---- Начисление заморозок ----

  /// Выдать стартовый грант при первом запуске (идемпотентно).
  ///
  /// Free → +1, Premium → +3.
  /// Флаг [kStarterFreezeGrantedKey] в prefs предотвращает повторный грант
  /// даже при смене тира в будущем.
  Future<void> _applyStarterGrant({required bool isPremium}) async {
    final alreadyGranted = _prefs.getBool(kStarterFreezeGrantedKey) ?? false;
    final grant = computeStarterGrant(
      isPremium: isPremium,
      alreadyGranted: alreadyGranted,
    );
    if (grant == 0) return;

    // Помечаем ДО записи в Drift: даже если Drift-запись упадёт,
    // лучше не выдать повторно, чем начислить дважды.
    await _prefs.setBool(kStarterFreezeGrantedKey, true);

    final streak = await _streakDao.getOrCreate();
    final newCount = streak.freezeCount + grant;
    await _streakDao.updateStreak(
      StreakTableCompanion(freezeCount: Value(newCount)),
    );
    debugPrint(
      '[FreezeAccrual] стартовый грант: +$grant заморозок → $newCount '
      '(isPremium=$isPremium)',
    );
  }

  /// Главный метод: начислить все «созревшие» заморозки, применить пороги наград.
  /// Возвращает результат для уведомления UI.
  Future<AccrualResult> accrueIfNeeded({required bool isPremium}) async {
    // Стартовый грант при первом вызове (идемпотентно, флаг в prefs).
    await _applyStarterGrant(isPremium: isPremium);

    final streak = await _streakDao.getOrCreate();
    final now = DateTime.now().toUtc();

    // Кадение: 14 дней для Premium, 30 для Free.
    final cadence = isPremium ? 14 : 30;

    final result = computeAccrual(
      now: now,
      lastAccrual: _lastAccrual,
      cadenceDays: cadence,
      currentFreezes: streak.freezeCount,
      claimedThresholds: _claimedThresholds,
    );

    // Сохранить новое время последнего начисления.
    await _prefs.setString(
      kLastFreezeAccrualKey,
      result.newLastAccrual.toIso8601String(),
    );

    // Добавить заморозки в Drift, если что-то начислено.
    if (result.addedFreezes > 0) {
      final newCount = streak.freezeCount + result.addedFreezes;
      await _streakDao.updateStreak(
        StreakTableCompanion(freezeCount: Value(newCount)),
      );
      debugPrint(
        '[FreezeAccrual] начислено +${result.addedFreezes} заморозок → $newCount',
      );
    }

    // Применить пороги наград.
    if (result.newlyClaimedThresholds.isNotEmpty) {
      await _applyRewardThresholds(
        thresholds: result.newlyClaimedThresholds,
        premiumDays: result.addedPremiumDays,
      );
    }

    return result;
  }

  /// Разовый бонус при покупке Premium: +2 заморозки.
  Future<void> grantPurchaseBonus() async {
    final streak = await _streakDao.getOrCreate();
    final newCount = streak.freezeCount + 2;
    await _streakDao.updateStreak(
      StreakTableCompanion(freezeCount: Value(newCount)),
    );
    debugPrint('[FreezeAccrual] бонус при покупке: +2 заморозки → $newCount');

    // Проверить, не разблокировались ли новые пороги.
    final now = DateTime.now().toUtc();
    final result = computeAccrual(
      now: now,
      lastAccrual: _lastAccrual ?? now,
      cadenceDays: 14, // уже premium
      currentFreezes: newCount,
      claimedThresholds: _claimedThresholds,
    );
    if (result.newlyClaimedThresholds.isNotEmpty) {
      await _applyRewardThresholds(
        thresholds: result.newlyClaimedThresholds,
        premiumDays: result.addedPremiumDays,
      );
    }
  }

  /// Продлить локальный Premium override, отметить пороги как claimed.
  Future<void> _applyRewardThresholds({
    required List<int> thresholds,
    required int premiumDays,
  }) async {
    // Объединить с уже claimed.
    final claimed = _claimedThresholds..addAll(thresholds);
    await _prefs.setStringList(
      kFreezeRewardClaimedKey,
      claimed.map((t) => t.toString()).toList(),
    );

    // Продлить local_premium_until.
    if (premiumDays > 0) {
      final now = DateTime.now().toUtc();
      final current = localPremiumUntil;
      final base = (current != null && current.isAfter(now)) ? current : now;
      final newUntil = base.add(Duration(days: premiumDays));
      await _prefs.setString(
        kLocalPremiumUntilKey,
        newUntil.toIso8601String(),
      );
      debugPrint(
        '[FreezeAccrual] награда: +$premiumDays дней Premium → до $newUntil',
      );
    }
  }

  // ---- Вспомогательные геттеры для UI ----

  /// Ближайший ещё не полученный порог (или null, если все получены).
  FreezeRewardThreshold? nextRewardThreshold(int currentFreezes) {
    final claimed = _claimedThresholds;
    for (final t in kFreezeRewardThresholds) {
      if (!claimed.contains(t.freezeCount)) return t;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Riverpod провайдеры
// ---------------------------------------------------------------------------

/// Провайдер сервиса начисления заморозок.
final freezeAccrualServiceProvider = Provider<FreezeAccrualService>((ref) {
  return FreezeAccrualService(
    streakDao: ref.read(streakDaoProvider),
    prefs: ref.read(sharedPreferencesProvider),
  );
});
