// DAO для food_logs (модуль «Еда»). Хранит съеденное за день с уже
// посчитанными КБЖУ на порцию. Числа берутся из Open Food Facts (на 100 г) и
// масштабируются под граммы при добавлении.

import 'package:drift/drift.dart';

import '../database.dart';
import '../../utils/id.dart';

part 'food_logs_dao.g.dart';

@DriftAccessor(tables: [FoodLogsTable])
class FoodLogsDao extends DatabaseAccessor<AppDatabase>
    with _$FoodLogsDaoMixin {
  FoodLogsDao(super.db);

  /// Реактивно: все записи о еде за день, по времени добавления.
  Stream<List<FoodLogsTableData>> watchForDay(DateTime date) {
    final dayStart = DateTime.utc(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return (select(foodLogsTable)
          ..where(
            (t) =>
                t.date.isBiggerOrEqualValue(dayStart) &
                t.date.isSmallerThanValue(dayEnd),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  /// Добавить запись о съеденном. Абсолютные значения КБЖУ уже посчитаны.
  Future<void> addLog({
    required DateTime date,
    required String meal,
    required String name,
    required double grams,
    double? calories,
    double? protein,
    double? fat,
    double? carbs,
    double? sugar,
    double? fiber,
  }) async {
    final dayStart = DateTime.utc(date.year, date.month, date.day);
    await into(foodLogsTable).insert(
      FoodLogsTableCompanion(
        id: Value(uuidV4()),
        date: Value(dayStart),
        meal: Value(meal),
        name: Value(name),
        grams: Value(grams),
        calories: Value(calories),
        protein: Value(protein),
        fat: Value(fat),
        carbs: Value(carbs),
        sugar: Value(sugar),
        fiber: Value(fiber),
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  /// Удалить запись о еде по id.
  Future<void> deleteLog(String id) async {
    await (delete(foodLogsTable)..where((t) => t.id.equals(id))).go();
  }

  /// Записи за последние [days] дней, свежие первыми.
  /// Используется как источник «недавних продуктов» для AI-сборки меню.
  Future<List<FoodLogsTableData>> recentLogs(int days) {
    final now = DateTime.now();
    final cutoff = DateTime.utc(now.year, now.month, now.day)
        .subtract(Duration(days: days));
    return (select(foodLogsTable)
          ..where((t) => t.date.isBiggerOrEqualValue(cutoff))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// Восстановить запись из снапшота (Undo после удаления).
  /// Если запись с тем же id уже есть — заменяем (insertOnConflictUpdate).
  /// Не меняет схему БД.
  Future<void> restoreLog(FoodLogsTableData snapshot) {
    return into(foodLogsTable).insertOnConflictUpdate(snapshot);
  }

  /// Одноразовое чтение записей за конкретный день (без потока).
  /// Используется для «Повторить прошлую неделю»: берём логи за 7 дней назад.
  Future<List<FoodLogsTableData>> logsForDay(DateTime date) {
    final dayStart = DateTime.utc(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return (select(foodLogsTable)
          ..where(
            (t) =>
                t.date.isBiggerOrEqualValue(dayStart) &
                t.date.isSmallerThanValue(dayEnd),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  /// Массовое добавление логов (для «Повторить прошлую неделю»).
  /// Возвращает список id вставленных записей — для Undo.
  Future<List<String>> addLogsAll(
    List<FoodLogsTableCompanion> companions,
  ) async {
    final ids = <String>[];
    await batch((b) {
      for (final c in companions) {
        b.insert(foodLogsTable, c);
        // id уже задан в companion
        final id = c.id.value;
        ids.add(id);
      }
    });
    return ids;
  }

  /// Удалить записи по списку id (для Undo «Повторить прошлую неделю»).
  Future<void> deleteLogsById(List<String> ids) async {
    if (ids.isEmpty) return;
    await (delete(foodLogsTable)
          ..where((t) => t.id.isIn(ids)))
        .go();
  }

  /// Последние N уникальных (по имени) продуктов из истории.
  /// Используется для секции «Недавнее» в листе поиска.
  /// Дедупликация по [name]: берём последнюю запись для каждого имени,
  /// сортируем по createdAt убывающе, возвращаем не более [limit].
  Future<List<FoodLogsTableData>> recentDistinctLogs({int limit = 10}) async {
    // Drift не имеет DISTINCT ON, поэтому делаем через raw query с подзапросом.
    // Безопасно: читаем только, не меняем схему.
    final rows = await customSelect(
      '''
      SELECT f.*
      FROM food_logs f
      INNER JOIN (
        SELECT name, MAX(created_at) AS max_created
        FROM food_logs
        GROUP BY name
      ) latest ON f.name = latest.name AND f.created_at = latest.max_created
      ORDER BY f.created_at DESC
      LIMIT ?
      ''',
      variables: [Variable.withInt(limit)],
      readsFrom: {foodLogsTable},
    ).get();

    // Конвертируем QueryRow → FoodLogsTableData через Drift-маппинг
    return rows.map((row) => foodLogsTable.map(row.data)).toList();
  }
}
