// DAO для долгосрочных целей (SPEC C4).
// Офлайн-первый: все данные только в Drift, синхронизация не предусмотрена (ADR-027).

import 'package:drift/drift.dart';

import '../database.dart';
import '../../utils/id.dart';

part 'goals_dao.g.dart';

@DriftAccessor(tables: [GoalsTable, GoalStepsTable])
class GoalsDao extends DatabaseAccessor<AppDatabase> with _$GoalsDaoMixin {
  GoalsDao(super.db);

  // ---------------------------------------------------------------------------
  // Цели
  // ---------------------------------------------------------------------------

  /// Реактивный список всех целей, сортировка: самые свежие первыми.
  Stream<List<GoalsTableData>> watchGoals() {
    return (select(goalsTable)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  /// Создать новую цель; возвращает id созданной записи.
  Future<String> createGoal(String title, String horizon) async {
    final id = uuidV4();
    final now = DateTime.now();
    await into(goalsTable).insert(
      GoalsTableCompanion(
        id: Value(id),
        title: Value(title),
        horizon: Value(horizon),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    return id;
  }

  /// Переименовать цель; сдвигает updatedAt.
  Future<void> renameGoal(String id, String title) async {
    await (update(goalsTable)..where((t) => t.id.equals(id))).write(
      GoalsTableCompanion(
        title: Value(title),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Удалить цель и все её шаги (каскад в транзакции).
  Future<void> deleteGoal(String id) async {
    await transaction(() async {
      await (delete(goalStepsTable)..where((t) => t.goalId.equals(id))).go();
      await (delete(goalsTable)..where((t) => t.id.equals(id))).go();
    });
  }

  // ---------------------------------------------------------------------------
  // Шаги
  // ---------------------------------------------------------------------------

  /// Реактивный список шагов цели, сортировка: по sortOrder.
  Stream<List<GoalStepsTableData>> watchSteps(String goalId) {
    return (select(goalStepsTable)
          ..where((t) => t.goalId.equals(goalId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  /// Добавить шаг к цели; sortOrder = текущее количество шагов.
  Future<void> addStep(String goalId, String title) async {
    // Считаем существующие шаги, чтобы назначить sortOrder
    final existing = await (select(goalStepsTable)
          ..where((t) => t.goalId.equals(goalId)))
        .get();
    final sortOrder = existing.length;

    await into(goalStepsTable).insert(
      GoalStepsTableCompanion(
        id: Value(uuidV4()),
        goalId: Value(goalId),
        title: Value(title),
        sortOrder: Value(sortOrder),
      ),
    );

    // Сдвигаем updatedAt родительской цели
    await (update(goalsTable)..where((t) => t.id.equals(goalId))).write(
      GoalsTableCompanion(updatedAt: Value(DateTime.now())),
    );
  }

  /// Отметить шаг выполненным / невыполненным; сдвигает updatedAt цели.
  Future<void> setStepDone(String id, bool done) async {
    // Читаем goalId до обновления
    final row = await (select(goalStepsTable)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;

    await (update(goalStepsTable)..where((t) => t.id.equals(id))).write(
      GoalStepsTableCompanion(done: Value(done)),
    );

    // Сдвигаем updatedAt родительской цели
    await (update(goalsTable)..where((t) => t.id.equals(row.goalId))).write(
      GoalsTableCompanion(updatedAt: Value(DateTime.now())),
    );
  }

  /// Удалить шаг по id.
  Future<void> removeStep(String id) async {
    await (delete(goalStepsTable)..where((t) => t.id.equals(id))).go();
  }
}
