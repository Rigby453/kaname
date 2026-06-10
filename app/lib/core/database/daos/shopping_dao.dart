// DAO для таблицы shopping_items — список покупок (SPEC C5, Phase 1).
// Локальный, офлайн-первый; синхронизация с сервером — Фаза 3.

import 'package:drift/drift.dart';

import '../database.dart';
import '../../utils/id.dart';

part 'shopping_dao.g.dart';

@DriftAccessor(tables: [ShoppingItemsTable])
class ShoppingDao extends DatabaseAccessor<AppDatabase>
    with _$ShoppingDaoMixin {
  ShoppingDao(super.db);

  /// Реактивный список всех покупок.
  /// Порядок: непомеченные сверху (checked ASC), внутри каждой группы — по createdAt ASC.
  Stream<List<ShoppingItemsTableData>> watchAll() {
    return (select(shoppingItemsTable)
          ..orderBy([
            (t) => OrderingTerm.asc(t.checked),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .watch();
  }

  /// Добавить позицию в список.
  Future<void> insertItem({required String name, String? quantity}) {
    final now = DateTime.now();
    return into(shoppingItemsTable).insert(
      ShoppingItemsTableCompanion(
        id: Value(uuidV4()),
        name: Value(name),
        quantity: Value(quantity),
        checked: const Value(false),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  /// Отметить/снять отметку «куплено»; обновляет updatedAt.
  Future<void> setChecked(String id, bool checked) {
    return (update(shoppingItemsTable)..where((t) => t.id.equals(id))).write(
      ShoppingItemsTableCompanion(
        checked: Value(checked),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Удалить конкретную позицию.
  Future<void> deleteItem(String id) {
    return (delete(shoppingItemsTable)..where((t) => t.id.equals(id))).go();
  }

  /// Удалить все отмеченные позиции. Возвращает кол-во удалённых строк.
  Future<int> clearChecked() {
    return (delete(shoppingItemsTable)
          ..where((t) => t.checked.equals(true)))
        .go();
  }
}
