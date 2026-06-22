// FL-TODAY-UNDO: одноуровневая отмена последнего обратимого действия на экране Today.
//
// Пользователь явно выбрал постоянную кнопку-стрелку (↩) слева от FAB «Add»
// вместо снэкбара. Хранится РОВНО одно последнее обратимое действие:
//   • added   — задача только что создана (помним её id, отмена = удаление);
//   • deleted — задача только что удалена (помним полный снимок, отмена = пересоздание).
//
// Любое новое add/delete ЗАМЕНЯЕТ предыдущую запись (single-level, без стека).
// После выполнения отмены запись очищается.
//
// Offline-first: отмена использует СУЩЕСТВУЮЩИЕ пути ItemsDao —
//   • insertItem  (пишет в Drift; синк подхватит новую строку);
//   • deleteItem  (удаляет из Drift + кладёт tombstone в sync_queue, ADR-021).
// Поэтому отдельной логики синхронизации здесь нет — переиспользуем DAO.

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/daos/items_dao.dart';
import '../../core/database/database.dart';
import '../../core/utils/id.dart';

/// Тип последнего обратимого действия.
enum UndoableActionType { added, deleted }

/// Одно обратимое действие.
///
/// Для [UndoableActionType.added] значим только [itemId] —
/// отмена удалит строку с этим id.
///
/// Для [UndoableActionType.deleted] значим [snapshot] —
/// полный снимок удалённой задачи, по которому она пересоздаётся.
class UndoableAction {
  const UndoableAction.added(this.itemId)
      : type = UndoableActionType.added,
        snapshot = null;

  const UndoableAction.deleted(this.snapshot)
      : type = UndoableActionType.deleted,
        itemId = null;

  final UndoableActionType type;

  /// id созданной задачи (только для added).
  final String? itemId;

  /// Полный снимок удалённой задачи (только для deleted).
  final ItemsTableData? snapshot;
}

/// StateNotifier, хранящий последнее обратимое действие (или null).
///
/// Логика реверса инкапсулирована в [undo], принимающем [ItemsDao] —
/// это позволяет тестировать отмену без UI, на чистом in-memory Drift.
class LastUndoableActionNotifier extends StateNotifier<UndoableAction?> {
  LastUndoableActionNotifier() : super(null);

  /// Записать «создана задача [itemId]». Заменяет предыдущее действие.
  void recordAdd(String itemId) {
    state = UndoableAction.added(itemId);
  }

  /// Записать «удалена задача [snapshot]». Заменяет предыдущее действие.
  void recordDelete(ItemsTableData snapshot) {
    state = UndoableAction.deleted(snapshot);
  }

  /// Очистить запись (например, если действие стало неактуальным).
  void clear() {
    state = null;
  }

  /// Выполнить отмену текущего действия через [dao] и очистить запись.
  ///
  /// Возвращает true, если было что отменять (и отмена выполнена).
  ///
  ///   • added   → удаляем созданную задачу существующим offline-first путём
  ///               (deleteItem: Drift + tombstone в sync_queue).
  ///   • deleted → пересоздаём задачу из снимка. Вставляем КОПИЮ с НОВЫМ id:
  ///               старый id уже затумбстоунен при удалении (ADR-021), повторная
  ///               вставка того же id вызвала бы конфликт удаления при синке —
  ///               та же причина, что у toast-undo в add_task_sheet.dart.
  Future<bool> undo(ItemsDao dao) async {
    final action = state;
    if (action == null) return false;

    switch (action.type) {
      case UndoableActionType.added:
        // Отмена создания: удаляем задачу существующим путём с tombstone.
        await dao.deleteItem(action.itemId!);
      case UndoableActionType.deleted:
        // Отмена удаления: пересоздаём из снимка с новым id.
        final s = action.snapshot!;
        final now = DateTime.now();
        await dao.insertItem(
          ItemsTableCompanion(
            id: Value(uuidV4()),
            userId: Value(s.userId),
            title: Value(s.title),
            type: Value(s.type),
            priority: Value(s.priority),
            status: Value(s.status),
            scheduledAt: Value(s.scheduledAt),
            durationMinutes: Value(s.durationMinutes),
            isProtected: Value(s.isProtected),
            recurrenceRule: Value(s.recurrenceRule),
            moduleLink: Value(s.moduleLink),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    }

    state = null;
    return true;
  }
}

/// Провайдер последнего обратимого действия на экране Today.
/// null = отменять нечего (кнопка undo скрыта).
final lastUndoableActionProvider =
    StateNotifierProvider<LastUndoableActionNotifier, UndoableAction?>(
  (ref) => LastUndoableActionNotifier(),
);
