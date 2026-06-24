import 'package:drift/drift.dart';
import '../database.dart';
import '../../utils/id.dart';

part 'habits_dao.g.dart';

@DriftAccessor(tables: [HabitsTable, HabitLogsTable])
class HabitsDao extends DatabaseAccessor<AppDatabase> with _$HabitsDaoMixin {
  HabitsDao(super.db);

  /// Все активные привычки (не заархивированные).
  Stream<List<HabitsTableData>> watchActive() {
    return (select(habitsTable)
          ..where((t) => t.archived.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  /// Все заархивированные привычки (для экрана архива).
  Stream<List<HabitsTableData>> watchArchived() {
    return (select(habitsTable)
          ..where((t) => t.archived.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  /// Логи за конкретный день (нормализованная дата 00:00 UTC).
  Stream<List<HabitLogsTableData>> watchLogsForDate(DateTime date) {
    final start = DateTime.utc(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (select(habitLogsTable)
          ..where(
            (t) =>
                t.date.isBiggerOrEqualValue(start) &
                t.date.isSmallerThanValue(end),
          ))
        .watch();
  }

  /// Количество выполнений привычки за день.
  Future<int> countForDate(String habitId, DateTime date) async {
    final start = DateTime.utc(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final rows = await (select(habitLogsTable)
          ..where(
            (t) =>
                t.habitId.equals(habitId) &
                t.date.isBiggerOrEqualValue(start) &
                t.date.isSmallerThanValue(end),
          ))
        .get();
    return rows.fold<int>(0, (sum, r) => sum + r.count);
  }

  /// Реактивное количество выполнений привычки за день.
  /// В отличие от [countForDate], эмитит новое значение при каждом logHabit —
  /// карточка обновляется сразу, без ухода/возврата на экран.
  Stream<int> watchCountForDate(String habitId, DateTime date) {
    final start = DateTime.utc(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final countExpr = habitLogsTable.count.sum();
    final query = selectOnly(habitLogsTable)
      ..addColumns([countExpr])
      ..where(
        habitLogsTable.habitId.equals(habitId) &
            habitLogsTable.date.isBiggerOrEqualValue(start) &
            habitLogsTable.date.isSmallerThanValue(end),
      );
    return query.watchSingle().map((row) => row.read(countExpr) ?? 0);
  }

  /// Все логи привычки, сгруппированные по дню (ключ YYYY-MM-DD в UTC) → сумма count.
  /// Один проход по логам; используется для расчёта стрика, истории и сводки.
  Future<Map<String, int>> dayCountsForHabit(String habitId) async {
    final rows = await (select(habitLogsTable)
          ..where((t) => t.habitId.equals(habitId)))
        .get();
    final counts = <String, int>{};
    for (final r in rows) {
      final key = dayKey(r.date.toUtc());
      counts[key] = (counts[key] ?? 0) + r.count;
    }
    return counts;
  }

  /// Реактивная сводка статистики привычки (стрик, лучший стрик, всего и т.п.).
  /// Эмитит новое значение при каждом logHabit — карточка обновляется сразу.
  Stream<HabitStats> watchStats(HabitsTableData habit, {DateTime? now}) {
    final today = now ?? DateTime.now();
    return (select(habitLogsTable)..where((t) => t.habitId.equals(habit.id)))
        .watch()
        .map((rows) {
      final counts = <String, int>{};
      for (final r in rows) {
        final key = dayKey(r.date.toUtc());
        counts[key] = (counts[key] ?? 0) + r.count;
      }
      return computeHabitStats(
        dayCounts: counts,
        type: habit.type,
        targetPerDay: habit.targetPerDay,
        now: today,
      );
    });
  }

  /// Разовый расчёт статистики (для архива / экранов без стрима).
  Future<HabitStats> statsForHabit(HabitsTableData habit, {DateTime? now}) async {
    final counts = await dayCountsForHabit(habit.id);
    return computeHabitStats(
      dayCounts: counts,
      type: habit.type,
      targetPerDay: habit.targetPerDay,
      now: now ?? DateTime.now(),
    );
  }

  /// Добавить выполнение (+1 или +count).
  Future<void> logHabit(String habitId, {int count = 1}) {
    final date = DateTime.utc(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    return into(habitLogsTable).insert(
      HabitLogsTableCompanion(
        id: Value(uuidV4()),
        habitId: Value(habitId),
        date: Value(date),
        count: Value(count),
      ),
    );
  }

  /// Создать новую привычку.
  Future<void> createHabit({
    required String name,
    required String type,
    String emoji = '✅',
    int targetPerDay = 1,
  }) {
    return into(habitsTable).insert(
      HabitsTableCompanion(
        id: Value(uuidV4()),
        name: Value(name),
        type: Value(type),
        emoji: Value(emoji),
        targetPerDay: Value(targetPerDay),
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  /// Архивировать привычку (скрыть без удаления).
  Future<void> archive(String id) {
    return (update(habitsTable)..where((t) => t.id.equals(id)))
        .write(const HabitsTableCompanion(archived: Value(true)));
  }

  /// Разархивировать привычку — вернуть в активный список.
  Future<void> unarchive(String id) {
    return (update(habitsTable)..where((t) => t.id.equals(id)))
        .write(const HabitsTableCompanion(archived: Value(false)));
  }

  /// Полностью удалить привычку по id.
  /// Логи выполнения (HabitLogsTable) при этом НЕ удаляются — они привязаны
  /// по habitId, но foreign key не каскадирует на delete в Drift (нет ON DELETE CASCADE).
  /// При восстановлении через [restoreHabit] привычка вернётся с тем же id,
  /// и существующие логи снова будут доступны.
  Future<void> deleteHabit(String id) {
    return (delete(habitsTable)..where((t) => t.id.equals(id))).go();
  }

  /// Восстановить привычку из снапшота (после Undo).
  /// insertOnConflictUpdate перезапишет запись если она вдруг уже существует.
  /// Логи выполнения сохраняются в HabitLogsTable — прогресс не теряется.
  Future<void> restoreHabit(HabitsTableData snapshot) {
    return into(habitsTable).insertOnConflictUpdate(snapshot);
  }
}

// ---------------------------------------------------------------------------
// Чистые функции расчёта статистики привычки. Вынесены наружу класса, чтобы
// их можно было юнит-тестировать без БД (передаём готовую карту дни→count).
// ---------------------------------------------------------------------------

/// Ключ дня вида YYYY-MM-DD из UTC-полуночи (для группировки и сравнения дней).
/// Дата нормализуется к UTC-дню — так же, как logHabit пишет date.
String dayKey(DateTime date) {
  final d = DateTime.utc(date.year, date.month, date.day);
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

/// Сводка статистики одной привычки.
class HabitStats {
  const HabitStats({
    required this.currentStreak,
    required this.bestStreak,
    required this.totalCompletions,
    required this.daysClean,
  });

  /// Текущая серия.
  /// good: дней подряд (от сегодня/вчера назад), где count за день >= target.
  /// bad: дней подряд БЕЗ логов (дней без срыва), от сегодня назад.
  final int currentStreak;

  /// Лучшая серия за всю историю (того же типа, что и currentStreak).
  final int bestStreak;

  /// good: всего дней, где цель достигнута.
  /// bad: всего нарушений (сумма всех count).
  final int totalCompletions;

  /// Только для bad: дней без срыва (== currentStreak). Для good == currentStreak.
  final int daysClean;
}

/// Считает статистику из карты дни(YYYY-MM-DD)→суммарный count.
///
/// good-привычка:
///   - день «выполнен», если count за день >= targetPerDay;
///   - currentStreak — кол-во выполненных дней подряд, считая от сегодня назад;
///     если сегодня ещё не отмечено, стрик «держится» от вчера (как в StreakService:
///     законченный вчера стрик активен до конца сегодня);
///   - bestStreak — самая длинная серия выполненных дней за всю историю.
/// bad-привычка:
///   - currentStreak/daysClean — дней подряд БЕЗ логов, считая от сегодня назад;
///   - bestStreak — самая длинная серия чистых дней между нарушениями
///     (от первого лога до сегодня);
///   - totalCompletions — суммарное число нарушений.
HabitStats computeHabitStats({
  required Map<String, int> dayCounts,
  required String type,
  required int targetPerDay,
  required DateTime now,
}) {
  final target = targetPerDay < 1 ? 1 : targetPerDay;
  final todayUtc = DateTime.utc(now.year, now.month, now.day);

  if (type == 'bad') {
    final totalViolations =
        dayCounts.values.fold<int>(0, (sum, c) => sum + c);

    // Дней без срыва: от сегодня назад, пока нет логов за день.
    var clean = 0;
    var cursor = todayUtc;
    while (!dayCounts.containsKey(dayKey(cursor))) {
      clean += 1;
      cursor = cursor.subtract(const Duration(days: 1));
      // Защита от бесконечного цикла, если нет ни одного лога вообще.
      if (clean > 3650) break;
    }
    // Если логов нет совсем — нет «истории» чистоты, стрик 0 (нечего считать).
    if (dayCounts.isEmpty) clean = 0;

    // Лучшая серия чистых дней — самый длинный разрыв между днями-нарушениями
    // (плюс хвост до сегодня). Идём от первого нарушения до сегодня.
    var best = clean;
    if (dayCounts.isNotEmpty) {
      final keys = dayCounts.keys.toList()..sort();
      final firstViolation = DateTime.parse('${keys.first}T00:00:00Z');
      var run = 0;
      var d = firstViolation;
      while (!d.isAfter(todayUtc)) {
        if (dayCounts.containsKey(dayKey(d))) {
          run = 0;
        } else {
          run += 1;
          if (run > best) best = run;
        }
        d = d.add(const Duration(days: 1));
      }
    }

    return HabitStats(
      currentStreak: clean,
      bestStreak: best,
      totalCompletions: totalViolations,
      daysClean: clean,
    );
  }

  // good-привычка.
  bool isDone(DateTime day) => (dayCounts[dayKey(day)] ?? 0) >= target;

  final totalDone = dayCounts.values.where((c) => c >= target).length;

  // Текущий стрик: старт = сегодня (если выполнено) иначе вчера.
  var current = 0;
  var cursor = isDone(todayUtc)
      ? todayUtc
      : todayUtc.subtract(const Duration(days: 1));
  while (isDone(cursor)) {
    current += 1;
    cursor = cursor.subtract(const Duration(days: 1));
    if (current > 3650) break;
  }

  // Лучший стрик: проходим все выполненные дни и считаем максимальную серию
  // подряд идущих дат.
  var best = current;
  final doneDays = dayCounts.entries
      .where((e) => e.value >= target)
      .map((e) => e.key)
      .toList()
    ..sort();
  if (doneDays.isNotEmpty) {
    var run = 1;
    best = best < 1 ? 1 : best;
    for (var i = 1; i < doneDays.length; i++) {
      final prev = DateTime.parse('${doneDays[i - 1]}T00:00:00Z');
      final curr = DateTime.parse('${doneDays[i]}T00:00:00Z');
      if (curr.difference(prev).inDays == 1) {
        run += 1;
      } else {
        run = 1;
      }
      if (run > best) best = run;
    }
  }

  return HabitStats(
    currentStreak: current,
    bestStreak: best,
    totalCompletions: totalDone,
    daysClean: current,
  );
}
