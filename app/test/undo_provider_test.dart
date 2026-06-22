// Unit-тесты для одноуровневой отмены (LastUndoableActionNotifier).
// In-memory Drift — без Flutter-зависимостей, как в water_dao_test.dart.
//
// Проверяем обе ветки реверса:
//   • recordAdd → undo удаляет созданную задачу (через offline-first deleteItem);
//   • recordDelete → undo пересоздаёт задачу из снимка (новый id, те же поля);
//   • single-level: новая запись затирает предыдущую; после undo состояние = null.

import 'package:app/core/database/daos/items_dao.dart';
import 'package:app/core/database/database.dart';
import 'package:app/features/today/undo_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ItemsDao dao;
  late LastUndoableActionNotifier notifier;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = ItemsDao(db);
    notifier = LastUndoableActionNotifier();
  });

  tearDown(() async {
    await db.close();
  });

  // Вспомогательная вставка задачи; возвращает id.
  Future<String> insertTask({
    String id = 'id-1',
    String title = 'Task',
    String priority = 'medium',
  }) async {
    final now = DateTime.now();
    return dao.insertItem(
      ItemsTableCompanion(
        id: Value(id),
        userId: const Value('local'),
        title: Value(title),
        type: const Value('task'),
        priority: Value(priority),
        status: const Value('pending'),
        scheduledAt: Value(now),
        durationMinutes: const Value(30),
        isProtected: const Value(false),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  Future<List<ItemsTableData>> allItems() => dao.itemsInRange(
        DateTime.utc(2000),
        DateTime.utc(2100),
      );

  test('recordAdd → undo удаляет созданную задачу', () async {
    final id = await insertTask(id: 'add-1');
    expect((await allItems()).length, 1);

    notifier.recordAdd(id);
    expect(notifier.state, isNotNull);
    expect(notifier.state!.type, UndoableActionType.added);

    final done = await notifier.undo(dao);
    expect(done, isTrue);
    // Задача удалена.
    expect((await allItems()).isEmpty, isTrue);
    // Состояние очищено после отмены.
    expect(notifier.state, isNull);
  });

  test('undo «added» кладёт tombstone в sync_queue (offline-first путь)',
      () async {
    final id = await insertTask(id: 'add-2');
    notifier.recordAdd(id);
    await notifier.undo(dao);

    final tombstones = await db.select(db.syncQueueTable).get();
    expect(
      tombstones.any((t) => t.recordId == id && t.operation == 'delete'),
      isTrue,
    );
  });

  test('recordDelete → undo пересоздаёт задачу из снимка (новый id, те же поля)',
      () async {
    // Готовим снимок удалённой задачи.
    final id = await insertTask(id: 'del-1', title: 'Important', priority: 'main');
    final snapshot = (await allItems()).single;
    await dao.deleteItem(id);
    expect((await allItems()).isEmpty, isTrue);

    notifier.recordDelete(snapshot);
    expect(notifier.state!.type, UndoableActionType.deleted);

    final done = await notifier.undo(dao);
    expect(done, isTrue);

    final items = await allItems();
    expect(items.length, 1);
    final restored = items.single;
    // Поля восстановлены.
    expect(restored.title, 'Important');
    expect(restored.priority, 'main');
    expect(restored.type, 'task');
    // id новый (старый затумбстоунен) — но строка пересоздана.
    expect(restored.id, isNot(id));
    // Состояние очищено.
    expect(notifier.state, isNull);
  });

  test('single-level: новая запись затирает предыдущую', () async {
    notifier.recordAdd('first');
    notifier.recordAdd('second');
    expect(notifier.state!.itemId, 'second');

    final snapshotItem = ItemsTableData(
      id: 'x',
      userId: 'local',
      title: 'Snap',
      type: 'task',
      priority: 'low',
      status: 'pending',
      scheduledAt: DateTime.now(),
      durationMinutes: 30,
      isProtected: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    notifier.recordDelete(snapshotItem);
    expect(notifier.state!.type, UndoableActionType.deleted);
  });

  test('undo без записи возвращает false', () async {
    expect(notifier.state, isNull);
    final done = await notifier.undo(dao);
    expect(done, isFalse);
  });
}
