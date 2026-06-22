// DAO для подзадач (чеклист) обычной задачи. Добавлено в schemaVersion 14.
// Офлайн-первый: данные в Drift; подзадачи едут вместе с задачей в sync-пейлоаде
// (snake_case `subtasks`, last-write-wins на уровне задачи).
//
// На якоре серии (recurrenceRule != null) подзадачи — ШАБЛОН: при материализации
// дня они копируются в новую concrete-строку (см. ItemsDao.materializeOccurrence).

import 'package:drift/drift.dart';

import '../database.dart';
import '../../utils/id.dart';

part 'subtasks_dao.g.dart';

@DriftAccessor(tables: [SubtasksTable])
class SubtasksDao extends DatabaseAccessor<AppDatabase> with _$SubtasksDaoMixin {
  SubtasksDao(super.db);

  /// Реактивный список подзадач задачи [itemId], отсортированный по sortOrder.
  Stream<List<SubtasksTableData>> watchSubtasks(String itemId) {
    return (select(subtasksTable)
          ..where((t) => t.itemId.equals(itemId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  /// Список подзадач задачи [itemId] (Future-вариант), отсортирован по sortOrder.
  Future<List<SubtasksTableData>> getSubtasks(String itemId) {
    return (select(subtasksTable)
          ..where((t) => t.itemId.equals(itemId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  /// Добавить подзадачу к задаче [itemId]; sortOrder = текущее количество.
  /// Возвращает id созданной подзадачи.
  Future<String> addSubtask(String itemId, String title) async {
    final existing = await (select(subtasksTable)
          ..where((t) => t.itemId.equals(itemId)))
        .get();
    final id = uuidV4();
    await into(subtasksTable).insert(
      SubtasksTableCompanion(
        id: Value(id),
        itemId: Value(itemId),
        title: Value(title),
        sortOrder: Value(existing.length),
      ),
    );
    return id;
  }

  /// Вставить подзадачу из готового companion (используется при сохранении
  /// формы и при копировании шаблона серии). Конфликт по id — обновление.
  Future<void> upsertSubtask(SubtasksTableCompanion companion) {
    return into(subtasksTable).insertOnConflictUpdate(companion);
  }

  /// Отметить подзадачу выполненной / невыполненной.
  Future<void> setDone(String id, bool done) async {
    await (update(subtasksTable)..where((t) => t.id.equals(id)))
        .write(SubtasksTableCompanion(done: Value(done)));
  }

  /// Переименовать подзадачу.
  Future<void> rename(String id, String title) async {
    await (update(subtasksTable)..where((t) => t.id.equals(id)))
        .write(SubtasksTableCompanion(title: Value(title)));
  }

  /// Удалить подзадачу по id.
  Future<void> removeSubtask(String id) async {
    await (delete(subtasksTable)..where((t) => t.id.equals(id))).go();
  }

  /// Переупорядочить подзадачи: записывает sortOrder по позиции в списке [ids].
  Future<void> reorder(List<String> ids) async {
    await transaction(() async {
      for (var i = 0; i < ids.length; i++) {
        await (update(subtasksTable)..where((t) => t.id.equals(ids[i])))
            .write(SubtasksTableCompanion(sortOrder: Value(i)));
      }
    });
  }

  /// Заменить весь набор подзадач задачи [itemId] переданным списком.
  /// Используется формой при сохранении и синхронизацией (last-write-wins на
  /// уровне задачи: пришедший с сервера набор заменяет локальный).
  Future<void> replaceForItem(
    String itemId,
    List<SubtasksTableCompanion> subtasks,
  ) async {
    await transaction(() async {
      await (delete(subtasksTable)..where((t) => t.itemId.equals(itemId))).go();
      for (final s in subtasks) {
        await into(subtasksTable).insert(s);
      }
    });
  }
}
