// Unit-тесты для ShoppingDao (SPEC C5, Phase 1).
// In-memory Drift — без Flutter-зависимостей, чистый Dart.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/daos/shopping_dao.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ShoppingDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = ShoppingDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  // Вспомогательная функция: получить текущий список синхронно через first.
  Future<List<ShoppingItemsTableData>> getAll() => dao.watchAll().first;

  group('insertItem / watchAll order', () {
    test('unchecked items appear before checked items', () async {
      // Вставляем: A unchecked, B unchecked, C — потом помечаем checked
      await dao.insertItem(name: 'Milk');
      await dao.insertItem(name: 'Bread');
      await dao.insertItem(name: 'Butter');

      // Помечаем Milk как купленный
      final all = await getAll();
      final milkId = all.firstWhere((i) => i.name == 'Milk').id;
      await dao.setChecked(milkId, true);

      final ordered = await getAll();
      // Первые два — unchecked, последний — checked (Milk)
      expect(ordered[0].checked, isFalse);
      expect(ordered[1].checked, isFalse);
      expect(ordered[2].checked, isTrue);
      expect(ordered[2].name, 'Milk');
    });

    test('items without check appear in createdAt asc order', () async {
      await dao.insertItem(name: 'Apple');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await dao.insertItem(name: 'Banana');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await dao.insertItem(name: 'Cherry');

      final items = await getAll();
      expect(items.map((i) => i.name).toList(), ['Apple', 'Banana', 'Cherry']);
    });
  });

  group('setChecked', () {
    test('toggles checked flag and updates updatedAt', () async {
      await dao.insertItem(name: 'Eggs');
      final before = (await getAll()).first;
      expect(before.checked, isFalse);

      // Небольшая задержка, чтобы updatedAt точно стал другим
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await dao.setChecked(before.id, true);

      final after = (await getAll()).first;
      expect(after.checked, isTrue);
      // updatedAt должен быть >= createdAt (и обновлён)
      expect(
        after.updatedAt.isAtSameMomentAs(before.updatedAt) ||
            after.updatedAt.isAfter(before.updatedAt),
        isTrue,
      );
    });
  });

  group('deleteItem', () {
    test('removes only the target item', () async {
      await dao.insertItem(name: 'Tomato');
      await dao.insertItem(name: 'Potato');

      final items = await getAll();
      final tomatoId = items.firstWhere((i) => i.name == 'Tomato').id;
      await dao.deleteItem(tomatoId);

      final remaining = await getAll();
      expect(remaining, hasLength(1));
      expect(remaining.first.name, 'Potato');
    });
  });

  group('clearChecked', () {
    test('deletes only checked items, leaves unchecked intact', () async {
      await dao.insertItem(name: 'Sugar');
      await dao.insertItem(name: 'Salt');
      await dao.insertItem(name: 'Pepper');

      final items = await getAll();
      // Помечаем Sugar и Salt как купленные
      await dao.setChecked(items.firstWhere((i) => i.name == 'Sugar').id, true);
      await dao.setChecked(items.firstWhere((i) => i.name == 'Salt').id, true);

      final deleted = await dao.clearChecked();
      expect(deleted, 2);

      final remaining = await getAll();
      expect(remaining, hasLength(1));
      expect(remaining.first.name, 'Pepper');
      expect(remaining.first.checked, isFalse);
    });

    test('returns 0 when nothing is checked', () async {
      await dao.insertItem(name: 'Flour');
      final deleted = await dao.clearChecked();
      expect(deleted, 0);
      expect(await getAll(), hasLength(1));
    });
  });
}
