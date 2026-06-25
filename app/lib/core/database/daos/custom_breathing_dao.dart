// DAO для таблицы custom_breathing — пользовательские дыхательные техники
// (schemaVersion 20). Локально-первый, без синхронизации. Фазы хранятся как
// JSON-строка (см. features/health/breathing_custom.dart), здесь DAO не знает
// о формате — просто читает/пишет колонку phasesJson.

import 'package:drift/drift.dart';

import '../database.dart';
import '../../utils/id.dart';

part 'custom_breathing_dao.g.dart';

@DriftAccessor(tables: [CustomBreathingTable])
class CustomBreathingDao extends DatabaseAccessor<AppDatabase>
    with _$CustomBreathingDaoMixin {
  CustomBreathingDao(super.db);

  /// Все пользовательские техники, старые первыми (стабильный порядок в пикере).
  Stream<List<CustomBreathingTableData>> watchAll() {
    return (select(customBreathingTable)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  /// Одна техника по id (для снапшота перед удалением → Undo).
  Future<CustomBreathingTableData?> getById(String id) {
    return (select(customBreathingTable)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Создать технику. Возвращает сгенерированный id.
  Future<String> create({
    required String name,
    required String phasesJson,
    int cycles = 4,
  }) async {
    final id = uuidV4();
    await into(customBreathingTable).insert(
      CustomBreathingTableCompanion(
        id: Value(id),
        name: Value(name),
        phasesJson: Value(phasesJson),
        cycles: Value(cycles),
        createdAt: Value(DateTime.now()),
      ),
    );
    return id;
  }

  /// Удалить технику по id.
  /// Имя метода НЕ `delete` — оно затенило бы унаследованный `delete(table)`
  /// из DatabaseAccessor (используемый ниже), что сломало бы компиляцию.
  Future<void> deleteTechnique(String id) {
    return (delete(customBreathingTable)..where((t) => t.id.equals(id))).go();
  }

  /// Восстановить технику из снапшота (после Undo) — тот же id.
  Future<void> restore(CustomBreathingTableData snapshot) {
    return into(customBreathingTable).insertOnConflictUpdate(snapshot);
  }
}
