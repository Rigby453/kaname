// Юнит-тесты локального поля location у задачи (schemaVersion 17).
// location — свободный текст «места»/локации (как в Google Calendar). Локальная
// колонка, НЕ синхронизируется. Проверяем сохранение/чтение и обновление.
// In-memory Drift, чистый Dart.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/daos/items_dao.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ItemsDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = ItemsDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<String> insertItem({String id = 'item-1', String? location}) async {
    final now = DateTime.now();
    await dao.insertItem(ItemsTableCompanion(
      id: Value(id),
      userId: const Value('local'),
      title: const Value('Lecture'),
      type: const Value('event'),
      priority: const Value('medium'),
      status: const Value('pending'),
      scheduledAt: Value(now),
      durationMinutes: const Value(30),
      isProtected: const Value(false),
      location: Value(location),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));
    return id;
  }

  test('сохраняет и читает location у задачи', () async {
    await insertItem(location: 'Аудитория 305');

    final item = await dao.getItemById('item-1');
    expect(item, isNotNull);
    expect(item!.location, 'Аудитория 305');
  });

  test('location по умолчанию null (поле необязательное)', () async {
    await insertItem();

    final item = await dao.getItemById('item-1');
    expect(item!.location, isNull);
  });

  test('updateItem обновляет location', () async {
    await insertItem(location: 'Зал');

    await dao.updateItem(
      'item-1',
      const ItemsTableCompanion(location: Value('Кабинет 12')),
    );

    final item = await dao.getItemById('item-1');
    expect(item!.location, 'Кабинет 12');
  });

  test('updateItem может очистить location (в null)', () async {
    await insertItem(location: 'Зал');

    await dao.updateItem(
      'item-1',
      const ItemsTableCompanion(location: Value(null)),
    );

    final item = await dao.getItemById('item-1');
    expect(item!.location, isNull);
  });
}
