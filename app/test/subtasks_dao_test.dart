// Юнит-тесты SubtasksDao (CRUD, переупорядочивание, замена набора) и каскадного
// удаления подзадач при удалении задачи (ItemsDao.deleteItem).
// In-memory Drift, чистый Dart.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/daos/items_dao.dart';
import 'package:app/core/database/daos/subtasks_dao.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late SubtasksDao dao;
  late ItemsDao itemsDao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = SubtasksDao(db);
    itemsDao = ItemsDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<String> insertItem({String id = 'item-1'}) async {
    final now = DateTime.now();
    await itemsDao.insertItem(ItemsTableCompanion(
      id: Value(id),
      userId: const Value('local'),
      title: const Value('Task'),
      type: const Value('task'),
      priority: const Value('medium'),
      status: const Value('pending'),
      scheduledAt: Value(now),
      durationMinutes: const Value(30),
      isProtected: const Value(false),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));
    return id;
  }

  test('addSubtask назначает sortOrder по порядку и watchSubtasks их возвращает',
      () async {
    final itemId = await insertItem();
    await dao.addSubtask(itemId, 'Buy milk');
    await dao.addSubtask(itemId, 'Buy eggs');
    await dao.addSubtask(itemId, 'Buy bread');

    final list = await dao.watchSubtasks(itemId).first;
    expect(list, hasLength(3));
    expect(list[0].title, 'Buy milk');
    expect(list[0].sortOrder, 0);
    expect(list[1].sortOrder, 1);
    expect(list[2].sortOrder, 2);
    expect(list.every((s) => !s.done), isTrue);
  });

  test('setDone / rename / removeSubtask', () async {
    final itemId = await insertItem();
    final id = await dao.addSubtask(itemId, 'Original');

    await dao.setDone(id, true);
    var list = await dao.getSubtasks(itemId);
    expect(list.single.done, isTrue);

    await dao.rename(id, 'Renamed');
    list = await dao.getSubtasks(itemId);
    expect(list.single.title, 'Renamed');

    await dao.removeSubtask(id);
    expect(await dao.getSubtasks(itemId), isEmpty);
  });

  test('reorder переписывает sortOrder по новому порядку id', () async {
    final itemId = await insertItem();
    final a = await dao.addSubtask(itemId, 'A');
    final b = await dao.addSubtask(itemId, 'B');
    final c = await dao.addSubtask(itemId, 'C');

    // Новый порядок: C, A, B
    await dao.reorder([c, a, b]);
    final list = await dao.getSubtasks(itemId);
    expect(list.map((s) => s.title).toList(), ['C', 'A', 'B']);
  });

  test('replaceForItem заменяет весь набор подзадач (LWW на уровне задачи)',
      () async {
    final itemId = await insertItem();
    await dao.addSubtask(itemId, 'Old 1');
    await dao.addSubtask(itemId, 'Old 2');

    await dao.replaceForItem(itemId, [
      SubtasksTableCompanion(
        id: const Value('new-1'),
        itemId: Value(itemId),
        title: const Value('New 1'),
        done: const Value(true),
        sortOrder: const Value(0),
      ),
    ]);

    final list = await dao.getSubtasks(itemId);
    expect(list, hasLength(1));
    expect(list.single.id, 'new-1');
    expect(list.single.title, 'New 1');
    expect(list.single.done, isTrue);
  });

  test('deleteItem каскадно удаляет подзадачи, не трогает другие задачи',
      () async {
    final id1 = await insertItem(id: 'item-1');
    final id2 = await insertItem(id: 'item-2');
    await dao.addSubtask(id1, 'S1');
    await dao.addSubtask(id1, 'S2');
    await dao.addSubtask(id2, 'S3');

    await itemsDao.deleteItem(id1);

    // Подзадачи первой задачи удалены
    expect(await dao.getSubtasks(id1), isEmpty);
    // Подзадачи второй задачи целы
    expect(await dao.getSubtasks(id2), hasLength(1));
  });

  test(
      'Undo удаления восстанавливает подзадачи (баг 4): снимок до удаления + '
      'replaceForItem после re-insert строки', () async {
    final itemId = await insertItem(id: 'item-undo');
    await dao.addSubtask(itemId, 'Step 1');
    final s2 = await dao.addSubtask(itemId, 'Step 2');
    await dao.setDone(s2, true);

    // Снимок ДО удаления (как делает _doDelete/_confirmDelete).
    final snapshot = await dao.getSubtasks(itemId);
    expect(snapshot, hasLength(2));

    // Каскадное удаление задачи стирает подзадачи.
    await itemsDao.deleteItem(itemId);
    expect(await dao.getSubtasks(itemId), isEmpty);

    // Undo: восстанавливаем строку (re-insert) и подзадачи под тем же itemId.
    await insertItem(id: itemId);
    await dao.replaceForItem(
      itemId,
      snapshot.map((s) => s.toCompanion(false)).toList(),
    );

    final restored = await dao.getSubtasks(itemId);
    expect(restored.map((s) => s.title).toList(), ['Step 1', 'Step 2']);
    expect(restored.firstWhere((s) => s.title == 'Step 2').done, isTrue,
        reason: 'статус done подзадачи сохраняется при восстановлении');
  });
}
